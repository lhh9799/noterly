import 'package:noterly/managers/backup_manager.dart';
import 'package:noterly/managers/log.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly_backup/noterly_backup.dart';

/// Keeps a copy of all reminders in the folder picked in the settings, in the same format as an export, so the file can
/// be brought back with "Import reminders" after the app was reinstalled.
class AutoBackup {
  static const fileName = 'noterly-backup.json';

  /// Whether the last write in this isolate succeeded (null before the first one), so the settings can show a problem.
  static bool? lastWriteSucceeded;

  /// Writes the backup file when automatic backup is on. Never throws: a failed backup must not fail the save.
  static Future<void> write(AppData data) async {
    final folder = data.autoBackupFolderUri;
    if (folder == null) return;
    try {
      await NoterlyBackup.write(folder, fileName, BackupManager.encode(data.notificationItems));
      lastWriteSucceeded = true;
    } catch (e, s) {
      lastWriteSucceeded = false;
      Log.logger.w('Automatic backup failed', error: e, stackTrace: s);
    }
  }
}
