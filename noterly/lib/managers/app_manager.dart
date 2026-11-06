import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:noterly/managers/file_manager.dart';
import 'package:noterly/managers/lifecycle_event_handler.dart';
import 'package:noterly/managers/notification_manager.dart';
import 'package:noterly/managers/wear_sync.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly/models/notification_item.dart';

import 'log.dart';

@pragma('vm:entry-point')
class AppManager {
  static final AppManager _instance = AppManager._internal();

  static AppManager get instance => _instance;

  AppManager._internal() {
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallback: () async {
          // If we're resuming, we need to reload the data from file in case an item has been deleted from a notification
          // action. In this case, a separate instance of the app will have been launched to handle the action, and the
          // data will have been saved to file. We need to reload the data from file to ensure the UI is up to date.
          Log.logger.d('Resuming app, reloading data from file...');
          await fullUpdate();

          // We also need to update the notifications, to ensure any notifications that need to be displayed are displayed.
          Log.logger.d('Updating notifications...');
          await NotificationManager.instance.updateAllNotifications();
        },
        suspendingCallback: () async => Log.logger.d('App suspended.'),
      ),
    );

    _load();
  }

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  Logger get logger => _logger;

  AppData data = AppData.defaults();

  final notifier = ValueNotifier<List<NotificationItem>>([]);

  List<NotificationItem?> deletedItems = [];

  var isInitialised = false;
  Future? _loadingFuture;

  Future ensureInitialised() async {
    if (isInitialised) {
      return;
    }

    return _loadingFuture;
  }

  Future _load() async {
    _loadingFuture = FileManager.load();
    AppData? newData;

    try {
      newData = await _loadingFuture;
    } on SaveFileUnreadableException catch (e, s) {
      // Never fall back to an empty list here: the next save would overwrite the user's notes (#42). Keep whatever
      // is in memory; the unreadable file has been copied aside by FileManager.
      Log.logger.e('Save file could not be read, keeping in-memory data', error: e, stackTrace: s);
      return;
    } finally {
      _loadingFuture = null;
    }

    if (newData == null) {
      Log.logger.d('No previous save found.');
      data = AppData.defaults();
      notifier.value = [];
      isInitialised = true;
      return;
    }

    data = newData;
    notifier.value = data.notificationItems;

    Log.logger.d('Loaded data from file.');

    isInitialised = true;
  }

  Future<void> _save() async {
    Log.logger.d('Saving data to file...');
    data.notificationItems = notifier.value;
    data.rev++;

    await FileManager.save(data);

    // Every save, from any isolate, sends the whole list to the watch app
    await WearSync.sendSnapshot(data);
  }

  // #region List management
  NotificationItem itemAt(int i) => notifier.value[i];

  NotificationItem? getItem(String id) {
    var found = notifier.value.where((element) => element.id == id);
    return found.isEmpty ? null : found.first;
  }

  Future addItem(NotificationItem item, {bool deferNotificationManagerCall = false}) async {
    item.updatedAt = DateTime.now();
    notifier.value.add(item);
    await _save();
    _updateNotifier();

    if (!deferNotificationManagerCall) {
      NotificationManager.instance.showOrUpdateNotification(item);
    }
  }

  /// [touch] marks the item as changed (updatedAt); false for changes the app makes by itself, like moving a repeat on.
  Future editItem(NotificationItem item, {bool deferNotificationManagerCall = false, bool touch = true}) async {
    var found = notifier.value.where((element) => element.id == item.id);
    if (found.isEmpty) {
      return;
    }

    var index = notifier.value.indexOf(found.first);
    if (touch) item.updatedAt = DateTime.now();
    notifier.value[index] = item;
    await _save();
    _updateNotifier();

    if (!deferNotificationManagerCall) {
      NotificationManager.instance.showOrUpdateNotification(item);
    }
  }

  Future deleteItem(String id, {bool deferNotificationManagerCall = false}) async {
    var found = notifier.value.where((element) => element.id == id);
    if (found.isEmpty) {
      return;
    }

    deletedItems = [found.first];
    notifier.value.remove(found.first);

    await _save();
    _updateNotifier();

    if (!deferNotificationManagerCall) {
      await NotificationManager.instance.cancelNotification(id);
    }
  }

  Future deleteAllArchivedItems({bool deferNotificationManagerCall = false}) async {
    var archivedItems = notifier.value.where((element) => element.archived).toList();
    if (archivedItems.isEmpty) {
      return;
    }

    deletedItems = archivedItems;

    for (var element in archivedItems) {
      notifier.value.remove(element);
      if (!deferNotificationManagerCall) {
        await NotificationManager.instance.cancelNotification(element.id);
      }
    }

    await _save();
    _updateNotifier();
  }

  Future archiveItem(String id, {bool deferNotificationManagerCall = false}) async {
    var found = notifier.value.where((element) => element.id == id);
    if (found.isEmpty) {
      return;
    }

    var index = notifier.value.indexOf(found.first);
    notifier.value[index].archived = true;
    notifier.value[index].archivedDateTime = DateTime.now();
    notifier.value[index].updatedAt = DateTime.now();
    await _save();
    _updateNotifier();

    if (!deferNotificationManagerCall) {
      await NotificationManager.instance.cancelNotification(id);
    }
  }

  Future restoreArchivedItem(String id, {bool deferNotificationManagerCall = false}) async {
    var found = notifier.value.where((element) => element.id == id);
    if (found.isEmpty) {
      return;
    }

    var index = notifier.value.indexOf(found.first);
    notifier.value[index].archived = false;
    notifier.value[index].archivedDateTime = null;
    notifier.value[index].updatedAt = DateTime.now();
    await _save();
    _updateNotifier();

    if (!deferNotificationManagerCall) {
      NotificationManager.instance.showOrUpdateNotification(notifier.value[index]);
    }
  }

  Future restoreLastDeletedItems({bool deferNotificationManagerCall = false}) async {
    if (deletedItems.isEmpty) {
      return;
    }

    for (var item in deletedItems) {
      await addItem(item!, deferNotificationManagerCall: deferNotificationManagerCall);
    }

    deletedItems = [];
  }

  /// Puts reminders read from an export file into the list and saves it (atomically, see [FileManager.save]).
  ///
  /// With [replace], the list becomes exactly the imported reminders. Otherwise an imported reminder is added when its
  /// ID is new, and replaces the current one only when it was changed more recently, so importing an older export
  /// never undoes newer edits. Only the notifications of reminders that were added, changed or removed are touched.
  Future<ImportResult> importItems(List<NotificationItem> imported, {required bool replace}) async {
    await ensureInitialised();

    final current = List<NotificationItem>.from(notifier.value);
    final currentById = {for (final item in current) item.id: item};

    final List<NotificationItem> result;
    final changed = <NotificationItem>[];
    final removed = <NotificationItem>[];
    var added = 0;

    if (replace) {
      final importedIds = imported.map((e) => e.id).toSet();
      removed.addAll(current.where((item) => !importedIds.contains(item.id)));
      result = List.of(imported);
      for (final item in imported) {
        if (!currentById.containsKey(item.id)) added++;
        changed.add(item);
      }
    } else {
      result = List.of(current);
      for (final item in imported) {
        final existing = currentById[item.id];
        if (existing == null) {
          result.add(item);
          changed.add(item);
          added++;
        } else if (_isNewer(item, existing)) {
          result[result.indexOf(existing)] = item;
          changed.add(item);
        }
      }
    }

    deletedItems = [];
    notifier.value = result;
    await _save();
    _updateNotifier();

    for (final item in removed) {
      await NotificationManager.instance.cancelNotification(item.id);
    }
    for (final item in changed) {
      await NotificationManager.instance.cancelNotification(item.id);
      if (item.archived) continue;
      if (item.isRepeating) {
        await NotificationManager.instance.updateRepeatingNotification(item);
      } else {
        await NotificationManager.instance.showOrUpdateNotification(item);
      }
    }

    return ImportResult(added: added, updated: changed.length - added, removed: removed.length);
  }

  static bool _isNewer(NotificationItem a, NotificationItem b) {
    if (a.updatedAt == null) return false;
    if (b.updatedAt == null) return true;
    return a.updatedAt!.isAfter(b.updatedAt!);
  }

  // #endregion

  Future saveSettings() async {
    Log.logger.d('Saving data for settings...');
    await _save();
    _updateNotifier();
    Log.logger.d('Data saved.');
  }

  Future fullUpdate() async {
    Log.logger.d('Full update requested, reloading data from file...');
    await _load();
    _updateNotifier();
    Log.logger.d('Full update completed.');
    printItems();
  }

  void _updateNotifier() {
    notifier.value = List.from(notifier.value); // Update value notifier
  }

  void printItems() => Log.logger.d(notifier.value);
}

class ImportResult {
  final int added;
  final int updated;
  final int removed;

  const ImportResult({required this.added, required this.updated, required this.removed});
}
