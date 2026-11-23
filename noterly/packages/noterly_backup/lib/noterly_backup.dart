import 'package:flutter/services.dart';

/// A folder picked with the system folder picker.
class BackupFolder {
  /// The tree URI the app keeps write access to.
  final String uri;

  /// The folder's name, to show in the settings.
  final String name;

  const BackupFolder(this.uri, this.name);
}

/// Dart side of the 'noterly/backup' channel.
class NoterlyBackup {
  static const _channel = MethodChannel('noterly/backup');

  /// Opens the system folder picker and keeps write access to the folder. Returns null if the user cancelled. Only
  /// works from the app's UI (it needs the activity).
  static Future<BackupFolder?> pickFolder() async {
    final result = await _channel.invokeMapMethod<String, String>('pickFolder');
    if (result == null) return null;
    return BackupFolder(result['uri']!, result['name']!);
  }

  /// Replaces the file [name] in the folder with [content], creating it the first time. Throws a [PlatformException]
  /// if the folder cannot be written to.
  static Future<void> write(String folderUri, String name, String content) =>
      _channel.invokeMethod('write', {'folder': folderUri, 'name': name, 'content': content});

  /// Whether the app still holds write access to the folder. It loses it when the app is reinstalled.
  static Future<bool> canWrite(String folderUri) async =>
      await _channel.invokeMethod<bool>('canWrite', {'folder': folderUri}) ?? false;

  /// Gives up access to the folder.
  static Future<void> release(String folderUri) => _channel.invokeMethod('release', {'folder': folderUri});

  /// Whether the phone has Google Play services, which runs Google backup and its settings screen.
  static Future<bool> hasGooglePlayServices() async =>
      await _channel.invokeMethod<bool>('hasGooglePlayServices') ?? false;
}
