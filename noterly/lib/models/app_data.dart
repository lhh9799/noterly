import 'package:noterly/models/notification_item.dart';

class AppData {
  List<NotificationItem> notificationItems;

  Duration snoozeDuration;
  String snoozeToastText;

  int firstLaunchDialogLastShown;

  /// Whether the per-reminder "dismissible" option is in effect. When false, every notification is ongoing, but each
  /// reminder keeps its own setting so it is restored when this is turned back on.
  bool dismissibleNotificationsEnabled;

  /// Goes up by one on every save, so the watch can tell a newer snapshot from an older one.
  int rev;

  /// IDs of the most recent watch commands that were applied or ignored, so a command is never applied twice.
  List<String> appliedWearCommands;

  AppData({
    required this.notificationItems,
    required this.snoozeDuration,
    required this.snoozeToastText,
    required this.firstLaunchDialogLastShown,
    required this.dismissibleNotificationsEnabled,
    this.rev = 0,
    List<String>? appliedWearCommands,
  }) : appliedWearCommands = appliedWearCommands ?? [];

  Map<String, dynamic> toJson() {
    return {
      'notificationItems': notificationItems.map((e) => e.toJson()).toList(),
      'snoozeDuration': snoozeDuration.inSeconds,
      'snoozeToastText': snoozeToastText,
      'firstLaunchDialogLastShown': firstLaunchDialogLastShown,
      'dismissibleNotificationsEnabled': dismissibleNotificationsEnabled,
      'rev': rev,
      'appliedWearCommands': appliedWearCommands,
    };
  }

  factory AppData.defaults() => AppData.fromJson({});

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        notificationItems: AppDataJsonParser<List<NotificationItem>>('notificationItems', [], parser: (value) => (value as List).map((item) => NotificationItem.fromJson(item)).toList()).parse(json),
        snoozeDuration: AppDataJsonParser<Duration>('snoozeDuration', const Duration(hours: 1), parser: (value) => Duration(seconds: value)).parse(json),
        snoozeToastText: AppDataJsonParser<String>('snoozeToastText', 'Notification snoozed').parse(json),
        firstLaunchDialogLastShown: AppDataJsonParser<int>('firstLaunchDialogLastShown', -1).parse(json),
        dismissibleNotificationsEnabled: AppDataJsonParser<bool>('dismissibleNotificationsEnabled', true).parse(json),
        rev: AppDataJsonParser<int>('rev', 0).parse(json),
        appliedWearCommands: AppDataJsonParser<List<String>>('appliedWearCommands', [], parser: (value) => List<String>.from(value)).parse(json),
      );

  @override
  String toString() => 'AppData(notificationItems: $notificationItems, snoozeDuration: $snoozeDuration, snoozeToastText: $snoozeToastText, firstLaunchDialogLastShown: $firstLaunchDialogLastShown, dismissibleNotificationsEnabled: $dismissibleNotificationsEnabled, rev: $rev)';
}

class AppDataJsonParser<T> {
  final String key;
  final T defaultValue;
  final T Function(dynamic)? parser;

  AppDataJsonParser(this.key, this.defaultValue, {this.parser});

  T parse(Map<String, dynamic> json) {
    if (!json.containsKey(key)) return defaultValue;
    if (parser != null) return parser!(json[key]);
    return json[key];
  }
}
