import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:noterly/extensions/date_time_extensions.dart';
import 'package:noterly/extensions/duration_extensions.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/main.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/managers/isolate_manager.dart';
import 'package:noterly/managers/log.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/pages/edit_notification_page.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;


@pragma('vm:entry-point')
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();

  static NotificationManager get instance => _instance;

  NotificationManager._internal() {
    _initialised = init();
  }

  final _plugin = FlutterLocalNotificationsPlugin();

  /// Completes once the plugin is set up. A background engine (watch commands) can show a notification right away.
  late final Future<void> _initialised;

  Future<void> init() async {
    Log.logger.d('Initialising notification manager...');

    tz.initializeTimeZones();

    const initializationSettingsAndroid = AndroidInitializationSettings('notification_icon_48');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );
  }

  static Future handleResponse(NotificationResponse response, {bool isBackground = false}) async {
    Log.logger.d('Handling notification response. ${isBackground ? 'Background' : 'Foreground'} mode. Action: "${response.actionId}". Payload: "${response.payload}"');

    if (response.payload == null) {
      Log.logger.d('No payload, ignoring');
      return;
    }

    if (isBackground) {
      await AppManager.instance.ensureInitialised();
      // The background engine stays alive between button presses, so its copy of the list can be out of date: the
      // app or the watch may have changed the file since the last press. Reload it, otherwise the save below writes
      // the old copy back and reminders that were marked as done or archived elsewhere come back with a notification.
      await AppManager.instance.fullUpdate();
    }

    // The old notification system used the item ID as the payload, but the new system uses a JSON string
    // containing the item JSON. For backwards compatibility, we need to check if the payload is a JSON string
    // and if so, extract the item ID from it.
    String itemId;

    try {
      var decoded = jsonDecode(response.payload!);
      itemId = NotificationItem.fromJson(decoded).id;
    } on FormatException catch (_) {
      Log.logger.d('Payload is not a JSON string, assuming it is an item ID');
      itemId = response.payload!;
    }

    var item = AppManager.instance.getItem(itemId);
    if (item == null) {
      Log.logger.d('No item found for payload, requesting a full update and retrying...');
      await AppManager.instance.fullUpdate();
      item = AppManager.instance.getItem(itemId);
      if (item == null) {
        Log.logger.d('Still no item found for payload, ignoring');
        return;
      }
    }

    if (response.actionId == 'done') {
      if (item.isRepeating) {
        Log.logger.d('Marking repeating notification "${item.title}" as done and rescheduling');
        // Clear any snooze, otherwise the past snooze time is scheduled again and the notification reappears
        // immediately every time it is marked as done (#20).
        item.snoozeDateTime = null;
        await NotificationManager.instance.updateRepeatingNotification(item);
      } else {
        Log.logger.d('Archiving notification "${item.title}"');
        await AppManager.instance.archiveItem(item.id, deferNotificationManagerCall: true);
      }

      // If we're in the background, we need to send a message to the main isolate to update the UI
      if (isBackground) {
        var sendPort = IsolateNameServer.lookupPortByName(IsolateManager.mainPortName);
        sendPort?.send('update');
        if (sendPort == null) {
          Log.logger.w('Failed to send message to main isolate (port not found).');
        }
      }

      return;
    }

    if (response.actionId == 'snooze') {
      var snoozeDateTime = DateTime.now().add(AppManager.instance.data.snoozeDuration);
      item.snoozeDateTime = snoozeDateTime;

      Log.logger.d('Snoozing notification "${item.title}" for ${AppManager.instance.data.snoozeDuration.inMinutes} minutes (${snoozeDateTime.toDateTimeString()})');

      await AppManager.instance.editItem(item, deferNotificationManagerCall: true);
      await _instance.showOrUpdateNotification(item);

      // Show the toast, in the phone's current language
      final strings = Strings.current();
      await Fluttertoast.showToast(
        msg: strings.toast_notificationSnoozed(AppManager.instance.data.snoozeDuration.toRelativeDurationString(strings)),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );

      // If we're in the background, we need to send a message to the main isolate to update the UI
      if (isBackground) {
        var sendPort = IsolateNameServer.lookupPortByName(IsolateManager.mainPortName);
        sendPort?.send('update');
        if (sendPort == null) {
          Log.logger.w('Failed to send message to main isolate (port not found).');
        }
      }

      return;
    }

    if (!isBackground) {
      if (MyApp.navigatorKey.currentState == null) {
        Log.logger.w('Failed to open notification "${item.title}": navigator key is null');
        return;
      }

      MyApp.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => EditNotificationPage(item: item!)),
        (route) => route.isFirst,
      );
      Log.logger.d('Opening notification "${item.title}"');
    }
  }

  static Future onResponse(NotificationResponse response) async => handleResponse(response, isBackground: false);

  @pragma('vm:entry-point')
  static Future onBackgroundResponse(NotificationResponse response) async => handleResponse(response, isBackground: true);

  Future requestAndroid13Permissions() async {
    try {
      var android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (android != null) {
        var result = await android.requestNotificationsPermission();
        Log.logger.d('Got A13 permission result: $result');
      }
    } catch (e) {
      Log.logger.e('Failed to request A13 notification permission, $e');
    }
  }

  Future cancelNotification(String itemId) async => await _plugin.cancel(itemId.hashCode);

  Future<bool> _notificationIsShown(NotificationItem item) async {
    var notifications = await _plugin.getActiveNotifications();
    return notifications.any((n) => n.id == item.id.hashCode);
  }

  /// Force updates all notifications. This should only be used where necessary as every notification is cancelled and recreated.
  Future forceUpdateAllNotifications() async {
    for (var item in AppManager.instance.notifier.value) {
      if (item.archived) continue;

      if (item.isRepeating) {
        await updateRepeatingNotification(item);
      } else {
        await showOrUpdateNotification(item);
      }
    }
  }

  Future updateAllNotifications() async {
    var notifications = await _plugin.getActiveNotifications();
    var shownIds = notifications.map((n) => n.id).toList();

    for (var item in AppManager.instance.notifier.value) {
      if (shownIds.contains(item.id.hashCode)) {
        // Notification is already shown. We don't need to do anything, as the notification will be updated when the item is updated.
        // This is either done when editing a notification, or when force updating all notifications.
        continue;
      }

      if (item.archived) continue;

      if (item.isRepeating) {
        await updateRepeatingNotification(item);
      } else if (_isDismissible(item) && !_isDueInFuture(item)) {
        // A dismissible notification that is due but not shown was swiped away by the user. Keep the reminder in the
        // list but do not show it again.
        continue;
      } else {
        await showOrUpdateNotification(item);
      }
    }
  }

  bool _isDismissible(NotificationItem item) => AppManager.instance.data.dismissibleNotificationsEnabled && item.dismissible;

  /// Re-posts every notification so that a change to a global notification setting takes effect: shown notifications
  /// are updated in place, and the rest are rescheduled.
  Future refreshAllNotifications() async {
    var shownIds = (await _plugin.getActiveNotifications()).map((n) => n.id).toSet();

    for (var item in AppManager.instance.notifier.value) {
      if (item.archived) continue;
      if (shownIds.contains(item.id.hashCode)) await _showNotification(item);
    }

    await updateAllNotifications();
  }

  bool _isDueInFuture(NotificationItem item) {
    var due = item.isSnoozed ? item.snoozeDateTime : item.dateTime;
    return due != null && due.isAfter(DateTime.now());
  }

  /// Updates a single notification. If the notification is already shown, it is cancelled.
  Future showOrUpdateNotification(NotificationItem item) async {
    if (item.archived) return;

    if (await _notificationIsShown(item)) await cancelNotification(item.id);

    await _showOrScheduleNotification(item);
  }

  /// Updates a repeating notification. This consists of updating its datetime to the next time it should be shown, and then showing it.
  Future updateRepeatingNotification(NotificationItem item) async {
    if (item.archived) return;
    if (!item.isRepeating) return;

    var isShown = await _notificationIsShown(item);
    var now = DateTime.now();

    bool dirty = false;

    if (item.dateTime == null) {
      // For some reason, the notification has no dateTime, so set it to now
      // This should not happen as we force a notification to be scheduled when it is set to repeating
      Log.logger.d('Repeating notification "${item.title}" has no dateTime, setting it to now');
      item.dateTime = now;
      dirty = true;
    }

    if (isShown) {
      Log.logger.d('Repeating notification "${item.title}" is already shown, no need to update');
      if (dirty) await AppManager.instance.editItem(item, deferNotificationManagerCall: true, touch: false);
      return;
    }

    while (item.dateTime!.isBefore(now)) {
      item.dateTime = item.nextRepeatDateTime; // Increment the dateTime until it's in the future
    }

    await AppManager.instance.editItem(item, deferNotificationManagerCall: true, touch: false);
    await _scheduleNotification(item);
  }

  Future _showOrScheduleNotification(NotificationItem item) async {
    if (item.isImmediate && !item.isSnoozed) {
      await _showNotification(item);
    } else {
      await _scheduleNotification(item);
    }
  }

  Future _showNotification(NotificationItem item) async {
    await _initialised;
    await _createChannels();
    var androidDetails = _getNotificationDetails(item);
    var details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.show(
        item.id.hashCode,
        item.title,
        item.body,
        details,
        payload: jsonEncode(item),
      );
    } on Exception catch (e) {
      Log.logger.e('Failed to show notification "${item.title}" at ${item.dateTime}', error: e);
      try {
        Fluttertoast.showToast(msg: Strings.current().toast_notificationFailed);
      } catch (e) {
        Log.logger.w('Failed to show toast', error: e);
      }
    }
  }

  Future _scheduleNotification(NotificationItem item) async {
    await _initialised;
    // send the notification either at its datetime or if its snoozed, at its snooze datetime
    var dateTime = item.isSnoozed ? item.snoozeDateTime : item.dateTime;

    if (dateTime?.isBefore(DateTime.now()) ?? false) {
      // Show notification immediately if it's in the past
      await _showNotification(item);
      return;
    }

    await _createChannels();
    var androidDetails = _getNotificationDetails(item);
    var details = NotificationDetails(android: androidDetails);

    try {
      await _plugin.zonedSchedule(
        item.id.hashCode,
        item.title,
        item.body,
        tz.TZDateTime.from(dateTime!, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: jsonEncode(item),
      );
    } on Exception catch (e) {
      Log.logger.e('Failed to schedule notification "${item.title}" at ${item.dateTime}', error: e);
      try {
        Fluttertoast.showToast(msg: Strings.current().toast_notificationFailed);
      } catch (e) {
        Log.logger.w('Failed to show toast', error: e);
      }
    }
  }

  static const _immediateChannelId = 'immediate_notifications';
  static const _scheduledChannelId = 'scheduled_notifications';

  /// Creates both channels, or gives existing ones the name and description in the phone's current language.
  /// Android keeps the user's settings of an existing channel. Done before every notification, because a channel that
  /// does not exist makes Android drop the notification ("No Channel found"), e.g. right after a fresh install.
  Future<void> _createChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    // Notifications are also built in background isolates, so the strings come without a BuildContext
    final strings = Strings.current();
    try {
      await android.createNotificationChannel(AndroidNotificationChannel(
        _immediateChannelId,
        strings.notification_channel_immediate_name,
        description: strings.notification_channel_immediate_description,
        importance: Importance.max,
      ));
      await android.createNotificationChannel(AndroidNotificationChannel(
        _scheduledChannelId,
        strings.notification_channel_scheduled_name,
        description: strings.notification_channel_scheduled_description,
        importance: Importance.max,
      ));
    } on Exception catch (e) {
      Log.logger.e('Failed to create the notification channels', error: e);
    }
  }

  AndroidNotificationDetails _getNotificationDetails(NotificationItem item) {
    // Notifications are also built in background isolates, so the strings come without a BuildContext
    final strings = Strings.current();
    return AndroidNotificationDetails(
        item.isImmediate ? _immediateChannelId : _scheduledChannelId,
        item.isImmediate ? strings.notification_channel_immediate_name : strings.notification_channel_scheduled_name,
        channelDescription: item.isImmediate
            ? strings.notification_channel_immediate_description
            : strings.notification_channel_scheduled_description,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('done', strings.notification_action_markAsDone),
          AndroidNotificationAction('snooze', strings.notification_action_snooze),
        ],
        category: AndroidNotificationCategory.reminder,
        importance: Importance.max,
        priority: Priority.max,
        groupKey: 'uk.co.tdsstudios.noterly.ALL_NOTIFICATIONS_GROUP',
        color: item.colour,
        ongoing: !_isDismissible(item),
        when: item.isImmediate ? null : item.dateTime!.millisecondsSinceEpoch,
        autoCancel: false,
      );
  }
}
