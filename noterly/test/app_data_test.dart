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
}
