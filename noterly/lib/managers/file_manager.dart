import 'dart:convert';
import 'dart:io';

import 'package:noterly/models/app_data.dart';
import 'package:path_provider/path_provider.dart';

import 'log.dart';

/// Thrown by [FileManager.load] when a save file exists but neither it nor its backup could be read.
class SaveFileUnreadableException implements Exception {
  final Object cause;

  SaveFileUnreadableException(this.cause);

  @override
  String toString() => 'SaveFileUnreadableException: $cause';
}

class FileManager {
  static const _fileName = 'data.json';

  // Saves within one isolate are chained so two writes never overlap.
  static Future<void> _pendingSave = Future.value();

  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async => File('${await _localPath}/$_fileName');

  static Future<File> get _backupFile async => File('${await _localPath}/$_fileName.bak');

  static Future<File> get _tempFile async => File('${await _localPath}/$_fileName.tmp');

  /// Writes [data] atomically: the JSON is written and flushed to a temporary file, the current save file is copied
  /// to a backup, then the temporary file is renamed over the save file. A reader (or a process killed mid-save)
  /// therefore only ever sees a complete file.
  static Future save(AppData data) {
    final json = jsonEncode(data.toJson());
    _pendingSave = _pendingSave.then((_) => _writeAtomically(json)).catchError((Object e, StackTrace s) {
      Log.logger.e('Failed to save data', error: e, stackTrace: s);
    });
    return _pendingSave;
  }

  static Future _writeAtomically(String json) async {
    final file = await _localFile;
    final temp = await _tempFile;

    await temp.writeAsString(json, flush: true);

    if (await file.exists()) {
      try {
        // Only back up a file that is readable, so a corrupt file never replaces a good backup.
        jsonDecode(await file.readAsString());
        await file.copy((await _backupFile).path);
      } catch (e) {
        Log.logger.w('Current save file is unreadable, not backing it up', error: e);
      }
    }

    await temp.rename(file.path);
  }

  /// Returns the saved data, or `null` if nothing has been saved yet.
  ///
  /// Throws [SaveFileUnreadableException] if a save file exists but neither it nor the backup can be parsed. Callers
  /// must not treat that as "no data", otherwise the next save would overwrite the user's notes with an empty list.
  static Future<AppData?> load() async {
    final file = await _localFile;
    final backup = await _backupFile;

    if (!await file.exists() && !await backup.exists()) {
      return null;
    }

    try {
      return AppData.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      Log.logger.w('Failed to read save file, trying backup', error: e);
    }

    try {
      final data = AppData.fromJson(jsonDecode(await backup.readAsString()));
      Log.logger.w('Loaded data from backup file');
      return data;
    } catch (e) {
      // Keep a copy of the unreadable file so it can be recovered manually.
      if (await file.exists()) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        await file.copy('${file.path}.corrupt-$stamp');
      }
      throw SaveFileUnreadableException(e);
    }
  }

  static Future<String?> loadRaw() async {
    try {
      final file = await _localFile;

      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      Log.logger.d('No previous save found. Error $e');
      return null;
    }
  }

  static Future delete() async {
    for (final file in [await _localFile, await _backupFile, await _tempFile]) {
      try {
        if (await file.exists()) await file.delete();
      } catch (e) {
        Log.logger.d('Failed to delete ${file.path}. Error $e');
      }
    }
  }
}
