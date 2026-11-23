import 'package:noterly/models/notification_item.dart';

/// What swiping a reminder in the active list does.
enum SwipeAction { archive, delete, none }

class AppData {
  List<NotificationItem> notificationItems;

  Duration snoozeDuration;

  int firstLaunchDialogLastShown;

  /// Whether the per-reminder "dismissible" option is in effect. When false, every notification is ongoing, but each
  /// reminder keeps its own setting so it is restored when this is turned back on.
  bool dismissibleNotificationsEnabled;

  /// The "dismissible" option of a new reminder, made on the phone or the watch.
  bool dismissibleByDefault;

  /// Goes up by one on every save, so the watch can tell a newer snapshot from an older one.
  int rev;

  /// IDs of the most recent watch commands that were applied or ignored, so a command is never applied twice.
  List<String> appliedWearCommands;

  /// Whether reminders can be swiped in the lists at all.
  bool swipeEnabled;

  /// What a swipe to the right (start to end) and to the left does in the active list.
  SwipeAction swipeRightAction;
  SwipeAction swipeLeftAction;

  /// The folder the automatic backup is written to (a tree URI from the system folder picker), or null when automatic
  /// backup is off. After a reinstall it may still be set while the app no longer has access to the folder.
  String? autoBackupFolderUri;

  /// The name of that folder, to show in the settings.
  String? autoBackupFolderName;

  /// Whether Android's own backup (Google backup) includes the reminders and the settings. NoterlyBackupAgent
  /// (packages/noterly_backup) reads these two keys from the save file when Android backs the app up.
  bool googleBackupReminders;
  bool googleBackupSettings;

  AppData({
    required this.notificationItems,
    required this.snoozeDuration,
    required this.firstLaunchDialogLastShown,
    required this.dismissibleNotificationsEnabled,
    this.dismissibleByDefault = false,
    this.rev = 0,
    List<String>? appliedWearCommands,
    this.swipeEnabled = true,
    this.swipeRightAction = SwipeAction.archive,
    this.swipeLeftAction = SwipeAction.archive,
    this.autoBackupFolderUri,
    this.autoBackupFolderName,
    this.googleBackupReminders = true,
    this.googleBackupSettings = true,
  }) : appliedWearCommands = appliedWearCommands ?? [];

  Map<String, dynamic> toJson() {
    return {
      'notificationItems': notificationItems.map((e) => e.toJson()).toList(),
      'snoozeDuration': snoozeDuration.inSeconds,
      'firstLaunchDialogLastShown': firstLaunchDialogLastShown,
      'dismissibleNotificationsEnabled': dismissibleNotificationsEnabled,
      'dismissibleByDefault': dismissibleByDefault,
      'rev': rev,
      'appliedWearCommands': appliedWearCommands,
      'swipeEnabled': swipeEnabled,
      'swipeRightAction': swipeRightAction.name,
      'swipeLeftAction': swipeLeftAction.name,
      'autoBackupFolderUri': autoBackupFolderUri,
      'autoBackupFolderName': autoBackupFolderName,
      'googleBackupReminders': googleBackupReminders,
      'googleBackupSettings': googleBackupSettings,
    };
  }

  factory AppData.defaults() => AppData.fromJson({});

  factory AppData.fromJson(Map<String, dynamic> json) => AppData(
        notificationItems: AppDataJsonParser<List<NotificationItem>>('notificationItems', [], parser: (value) => (value as List).map((item) => NotificationItem.fromJson(item)).toList()).parse(json),
        snoozeDuration: AppDataJsonParser<Duration>('snoozeDuration', const Duration(hours: 1), parser: (value) => Duration(seconds: value)).parse(json),
        firstLaunchDialogLastShown: AppDataJsonParser<int>('firstLaunchDialogLastShown', -1).parse(json),
        dismissibleNotificationsEnabled: AppDataJsonParser<bool>('dismissibleNotificationsEnabled', true).parse(json),
        dismissibleByDefault: AppDataJsonParser<bool>('dismissibleByDefault', false).parse(json),
        rev: AppDataJsonParser<int>('rev', 0).parse(json),
        appliedWearCommands: AppDataJsonParser<List<String>>('appliedWearCommands', [], parser: (value) => List<String>.from(value)).parse(json),
        swipeEnabled: AppDataJsonParser<bool>('swipeEnabled', true).parse(json),
        swipeRightAction: AppDataJsonParser<SwipeAction>('swipeRightAction', SwipeAction.archive, parser: _parseSwipeAction).parse(json),
        swipeLeftAction: AppDataJsonParser<SwipeAction>('swipeLeftAction', SwipeAction.archive, parser: _parseSwipeAction).parse(json),
        autoBackupFolderUri: AppDataJsonParser<String?>('autoBackupFolderUri', null).parse(json),
        autoBackupFolderName: AppDataJsonParser<String?>('autoBackupFolderName', null).parse(json),
        googleBackupReminders: AppDataJsonParser<bool>('googleBackupReminders', true).parse(json),
        googleBackupSettings: AppDataJsonParser<bool>('googleBackupSettings', true).parse(json),
      );

  static SwipeAction _parseSwipeAction(dynamic value) => SwipeAction.values.asNameMap()[value] ?? SwipeAction.archive;

  @override
  String toString() => 'AppData(notificationItems: $notificationItems, snoozeDuration: $snoozeDuration, firstLaunchDialogLastShown: $firstLaunchDialogLastShown, dismissibleNotificationsEnabled: $dismissibleNotificationsEnabled, dismissibleByDefault: $dismissibleByDefault, rev: $rev)';
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
