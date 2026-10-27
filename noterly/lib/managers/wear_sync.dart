import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:noterly/l10n/app_localisations.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/managers/log.dart';
import 'package:noterly/managers/notification_manager.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/models/repetition_data.dart';
import 'package:noterly_wear/noterly_wear.dart';

/// A change made on the watch, sent as one Data Layer item per command (see the noterly-watch repository).
class WearCommand {
  static const done = 'done';
  static const snooze = 'snooze';
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const restore = 'restore';

  final String commandId;
  final String type;
  final String itemId;
  final int baseRev;
  final DateTime issuedAt;
  final Map<String, dynamic> payload;

  WearCommand({
    required this.commandId,
    required this.type,
    required this.itemId,
    required this.baseRev,
    required this.issuedAt,
    this.payload = const {},
  });

  factory WearCommand.fromJson(Map<String, dynamic> json) => WearCommand(
        commandId: json['commandId'],
        type: json['type'],
        itemId: json['itemId'],
        baseRev: json['baseRev'] ?? 0,
        issuedAt: DateTime.parse(json['issuedAt']),
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      );

  DateTime? _time(String key) => payload[key] != null ? DateTime.parse(payload[key]) : null;

  /// For done: the item's dateTime as the watch saw it.
  DateTime? get seenDateTime => _time('seenDateTime');

  /// For create and update: null means "immediately".
  DateTime? get dateTime => _time('dateTime');

  RepetitionData? get repetitionData => payload['repetitionData'] != null ? RepetitionData.fromJson(Map<String, dynamic>.from(payload['repetitionData'])) : null;
}

enum WearCommandOutcome {
  /// Apply it.
  apply,

  /// Already applied once.
  duplicate,

  /// No longer applies (the item is gone, already done, or was changed later on the phone).
  ignore,
}

/// Keeps the watch app in sync. The phone is the only source of truth: every save sends the whole list to the watch,
/// and the watch sends back commands that are applied here through [AppManager], like the notification buttons.
class WearSync {
  static const maxAppliedCommands = 200;
  static const upcomingCount = 5;

  // #region Snapshot

  /// Sends the current list to the watch. Called at the end of every save, in whichever isolate saved.
  static Future<void> sendSnapshot(AppData data) async {
    try {
      final labeller = await _repeatLabeller();
      final snapshot = buildSnapshot(data, now: DateTime.now(), repeatLabel: labeller);
      await NoterlyWear.sendSnapshot(jsonEncode(snapshot));
    } catch (e, s) {
      // No watch, no Play services, or a test: the phone app carries on as before
      Log.logger.d('Watch snapshot not sent: $e', stackTrace: s);
    }
  }

  static Map<String, dynamic> buildSnapshot(AppData data, {required DateTime now, String Function(RepetitionData)? repeatLabel}) => {
        'schema': 1,
        'rev': data.rev,
        'generatedAt': now.toIso8601String(),
        'settings': {
          'snoozeSeconds': data.snoozeDuration.inSeconds,
          'dismissibleEnabled': data.dismissibleNotificationsEnabled,
          'dismissibleByDefault': data.dismissibleByDefault,
        },
        'items': [
          for (final item in data.notificationItems)
            {
              ...item.toJson(),
              'upcoming': upcoming(item, now).map((e) => e.toIso8601String()).toList(),
              'repeatLabel': item.repetitionData != null && repeatLabel != null ? repeatLabel(item.repetitionData!) : null,
            },
        ],
        'appliedCommands': data.appliedWearCommands,
      };

  /// The next [count] send times of a repeating item, for the watch's list, tile and its own notifications.
  static List<DateTime> upcoming(NotificationItem item, DateTime now, {int count = upcomingCount}) {
    if (item.archived || item.repetitionData == null || item.dateTime == null) return [];

    final repetition = item.repetitionData!;
    var dateTime = item.dateTime!;
    var guard = 0;
    while (dateTime.isBefore(now) && guard++ < 100000) {
      dateTime = repetition.nextDateTime(dateTime);
    }

    final result = <DateTime>[];
    while (result.length < count) {
      result.add(dateTime);
      dateTime = repetition.nextDateTime(dateTime);
    }
    return result;
  }

  /// Repeat descriptions in the phone's language, without a [BuildContext], so it also works in background isolates.
  static Future<String Function(RepetitionData)> _repeatLabeller() async {
    final locale = basicLocaleListResolution(PlatformDispatcher.instance.locales, AppLocalisations.supportedLocales);
    final localeName = locale.toString();
    await initializeDateFormatting(localeName);

    final strings = lookupAppLocalisations(locale);
    // intl counts the first day of the week from Monday = 0; MaterialLocalizations from Sunday = 0
    final firstDayOfWeekIndex = (DateFormat.E(localeName).dateSymbols.FIRSTDAYOFWEEK + 1) % 7;
    return (RepetitionData repetition) => repetition.toReadableStringWith(strings, localeName, firstDayOfWeekIndex);
  }

  // #endregion

  // #region Commands

  /// What to do with [command], given the phone's current [item] (null if there is none with that ID).
  static WearCommandOutcome decide(AppData data, NotificationItem? item, WearCommand command) {
    if (data.appliedWearCommands.contains(command.commandId)) return WearCommandOutcome.duplicate;

    if (command.type == WearCommand.create) return item == null ? WearCommandOutcome.apply : WearCommandOutcome.ignore;
    if (item == null) return WearCommandOutcome.ignore;

    switch (command.type) {
      case WearCommand.done:
        if (item.archived) return WearCommandOutcome.ignore;
        // Done on both sides while apart: the phone has already moved the repeat on, so do not skip a second one
        final seen = command.seenDateTime;
        if (item.isRepeating && seen != null && item.dateTime != null && item.dateTime!.isAfter(seen)) return WearCommandOutcome.ignore;
        return WearCommandOutcome.apply;
      case WearCommand.snooze:
        return item.archived ? WearCommandOutcome.ignore : WearCommandOutcome.apply;
      case WearCommand.update:
        // Edited on the phone after the watch's edit was made: the phone's edit wins
        if (item.updatedAt != null && item.updatedAt!.isAfter(command.issuedAt)) return WearCommandOutcome.ignore;
        return WearCommandOutcome.apply;
      case WearCommand.restore:
        return item.archived ? WearCommandOutcome.apply : WearCommandOutcome.ignore;
      case WearCommand.delete:
        return WearCommandOutcome.apply;
      default:
        return WearCommandOutcome.ignore;
    }
  }

  /// Remembers [commandId] so it is never applied twice, keeping the most recent [maxAppliedCommands].
  static void recordApplied(AppData data, String commandId) {
    data.appliedWearCommands.add(commandId);
    if (data.appliedWearCommands.length > maxAppliedCommands) {
      data.appliedWearCommands.removeRange(0, data.appliedWearCommands.length - maxAppliedCommands);
    }
  }

  /// Applies every command the watch has queued, oldest first, and removes them from the Data Layer. Every command
  /// ends in a save, which sends a new snapshot. Returns whether anything was changed.
  static Future<bool> applyQueuedCommands() async {
    final queued = await NoterlyWear.fetchCommands();
    final commands = <(QueuedWearCommand, WearCommand)>[];
    for (final entry in queued) {
      try {
        commands.add((entry, WearCommand.fromJson(jsonDecode(entry.json))));
      } catch (e) {
        Log.logger.w('Unreadable watch command, removing it', error: e);
        await NoterlyWear.deleteCommand(entry.uri);
      }
    }
    commands.sort((a, b) => a.$2.issuedAt.compareTo(b.$2.issuedAt));

    var changed = false;
    for (final (entry, command) in commands) {
      // One failing command (bad payload, missing item) must not block the ones after it or stay queued forever
      try {
        final manager = AppManager.instance;
        final outcome = decide(manager.data, manager.getItem(command.itemId), command);
        Log.logger.d('Watch command ${command.type} for ${command.itemId}: ${outcome.name}');

        if (outcome != WearCommandOutcome.duplicate) recordApplied(manager.data, command.commandId);

        if (outcome == WearCommandOutcome.apply) {
          await _apply(command);
          changed = true;
        } else {
          // Nothing to change, but save so the applied list is kept and the watch gets a snapshot that drops the command
          await manager.saveSettings();
        }
      } catch (e, s) {
        Log.logger.e('Watch command ${command.type} for ${command.itemId} failed, removing it', error: e, stackTrace: s);
      }

      try {
        await NoterlyWear.deleteCommand(entry.uri);
      } catch (e) {
        Log.logger.w('Watch command ${command.commandId} not removed', error: e);
      }
    }
    return changed;
  }

  /// Applies a command with the same calls the phone's own screens and notification buttons use.
  static Future<void> _apply(WearCommand command) async {
    final manager = AppManager.instance;
    final notifications = NotificationManager.instance;
    final item = manager.getItem(command.itemId);

    switch (command.type) {
      case WearCommand.done:
        if (item!.isRepeating) {
          // As 'Mark as done' on the notification: clear the snooze and move on to the next repeat. The notification
          // is still shown here (the button press cancels it), so cancel it first or it would not be rescheduled.
          item.snoozeDateTime = null;
          // Done before the repeat is due counts for that repeat, so always move on at least once
          if (item.dateTime != null && !item.dateTime!.isBefore(DateTime.now())) item.dateTime = item.nextRepeatDateTime;
          await notifications.cancelNotification(item.id);
          await notifications.updateRepeatingNotification(item);
        } else {
          await manager.archiveItem(item.id);
        }
        break;

      case WearCommand.snooze:
        item!.snoozeDateTime = command.issuedAt.add(manager.data.snoozeDuration);
        await manager.editItem(item, deferNotificationManagerCall: true);
        await notifications.showOrUpdateNotification(item);
        break;

      case WearCommand.create:
        await manager.addItem(NotificationItem(
          id: command.itemId,
          title: command.payload['title'] ?? '',
          body: command.payload['body'] ?? '',
          dateTime: command.dateTime,
          repetitionData: command.repetitionData,
          colour: Color(command.payload['colour'] ?? Colors.blue.toARGB32()),
          dismissible: manager.data.dismissibleByDefault,
        ), deferNotificationManagerCall: true);
        // Awaited here: the background engine is shut down as soon as the commands are applied
        await notifications.showOrUpdateNotification(manager.getItem(command.itemId)!);
        break;

      case WearCommand.update:
        final repetitionChanged = jsonEncode(item!.repetitionData?.toJson()) != jsonEncode(command.repetitionData?.toJson()) || item.dateTime != command.dateTime;
        item.title = command.payload['title'] ?? item.title;
        item.body = command.payload['body'] ?? item.body;
        if (command.payload['colour'] != null) item.colour = Color(command.payload['colour']);
        item.dateTime = command.dateTime;
        item.repetitionData = command.repetitionData;
        await manager.editItem(item, deferNotificationManagerCall: true);
        if (item.isRepeating && repetitionChanged) {
          await notifications.cancelNotification(item.id);
          await notifications.updateRepeatingNotification(item);
        } else {
          await notifications.showOrUpdateNotification(item);
        }
        break;

      case WearCommand.delete:
        await manager.deleteItem(command.itemId);
        break;

      case WearCommand.restore:
        await manager.restoreArchivedItem(command.itemId, deferNotificationManagerCall: true);
        await notifications.showOrUpdateNotification(manager.getItem(command.itemId)!);
        break;
    }
  }

  // #endregion

  /// Tags each shown notification with its item and send time, so the watch can leave out the ones it already showed
  /// by itself while the phone was away. Immediate items have no send time and get an 'immediate' tag.
  static Future<void> applyBridgeTags(List<NotificationItem> items) async {
    final tags = <int, String>{
      for (final item in items)
        if (!item.archived) item.id.hashCode: bridgeTag(item.id, item.snoozeDateTime ?? item.dateTime),
    };
    try {
      await NoterlyWear.applyBridgeTags(tags);
    } catch (e) {
      Log.logger.d('Bridge tags not applied: $e');
    }
  }

  /// Must match WatchState.bridgeTag in the watch app. [due] is null for an immediate item.
  static String bridgeTag(String itemId, DateTime? due) => 'noterly:$itemId:${due?.millisecondsSinceEpoch ?? 'immediate'}';
}
