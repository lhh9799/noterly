import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/models/app_data.dart';

void main() {
  group('swipe settings', () {
    test('an old save file without them swipes to archive both ways', () {
      final data = AppData.fromJson({});
      expect(data.swipeEnabled, isTrue);
      expect(data.swipeRightAction, SwipeAction.archive);
      expect(data.swipeLeftAction, SwipeAction.archive);
    });

    test('are kept through a save and load', () {
      final data = AppData.defaults()
        ..swipeEnabled = false
        ..swipeRightAction = SwipeAction.delete
        ..swipeLeftAction = SwipeAction.none;

      final loaded = AppData.fromJson(data.toJson());
      expect(loaded.swipeEnabled, isFalse);
      expect(loaded.swipeRightAction, SwipeAction.delete);
      expect(loaded.swipeLeftAction, SwipeAction.none);
    });

    test('an unknown action falls back to archive', () {
      final data = AppData.fromJson({'swipeRightAction': 'snooze'});
      expect(data.swipeRightAction, SwipeAction.archive);
    });
  });

  group('automatic backup settings', () {
    test('an old save file without them has automatic backup off', () {
      final data = AppData.fromJson({});
      expect(data.autoBackupFolderUri, isNull);
      expect(data.autoBackupFolderName, isNull);
    });

    test('are kept through a save and load', () {
      final data = AppData.defaults()
        ..autoBackupFolderUri = 'content://com.android.externalstorage.documents/tree/primary%3ADownload'
        ..autoBackupFolderName = 'Download';

      final loaded = AppData.fromJson(data.toJson());
      expect(loaded.autoBackupFolderUri, data.autoBackupFolderUri);
      expect(loaded.autoBackupFolderName, 'Download');
    });
  });

  group('Google backup', () {
    AppData changed() => AppData.fromJson({
          'notificationItems': [
            {'id': 'a', 'title': 'Buy milk', 'body': '', 'colour': 0xFF2196F3},
          ],
          'rev': 7,
          'snoozeDuration': 7200,
          'swipeLeftAction': 'delete',
        });

    test('an old save file without the switches backs up reminders and settings', () {
      final data = AppData.fromJson({});
      expect(data.googleBackupReminders, isTrue);
      expect(data.googleBackupSettings, isTrue);
    });

    test('the switches are kept through a save and load', () {
      final data = AppData.defaults()
        ..googleBackupReminders = false
        ..googleBackupSettings = false;

      final loaded = AppData.fromJson(data.toJson());
      expect(loaded.googleBackupReminders, isFalse);
      expect(loaded.googleBackupSettings, isFalse);
    });

    // The backup agent hands over only the save file entries of the parts that are on; these are what comes back
    test('a restore without the settings keeps the reminders and starts the settings from their defaults', () {
      final json = changed().toJson()..removeWhere((key, _) => !{'notificationItems', 'rev', 'appliedWearCommands'}.contains(key));

      final restored = AppData.fromJson(json);
      expect(restored.notificationItems.map((e) => e.title), ['Buy milk']);
      expect(restored.rev, 7);
      expect(restored.snoozeDuration, const Duration(hours: 1));
      expect(restored.swipeLeftAction, SwipeAction.archive);
    });

    test('a restore without the reminders keeps the settings and starts with no reminders', () {
      final json = changed().toJson()..removeWhere((key, _) => {'notificationItems', 'rev', 'appliedWearCommands'}.contains(key));

      final restored = AppData.fromJson(json);
      expect(restored.notificationItems, isEmpty);
      expect(restored.snoozeDuration, const Duration(hours: 2));
      expect(restored.swipeLeftAction, SwipeAction.delete);
    });
  });
}
