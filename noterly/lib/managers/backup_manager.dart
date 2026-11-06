import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:noterly/models/notification_item.dart';

/// Thrown when a picked file is not a reminders export (or a Noterly save file) that this version can read.
class BackupFormatException implements Exception {
  final String message;

  BackupFormatException(this.message);

  @override
  String toString() => 'BackupFormatException: $message';
}

/// Reads and writes reminder export files.
///
/// An export is a JSON object with a format marker and the same `notificationItems` list as the app's own data.json,
/// so a copy of data.json can be imported too.
class BackupManager {
  static const formatId = 'noterly-reminders';
  static const formatVersion = 1;

  static String encode(List<NotificationItem> items) => const JsonEncoder.withIndent('  ').convert({
        'format': formatId,
        'version': formatVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'notificationItems': items.map((e) => e.toJson()).toList(),
      });

  /// Parses an export file (or a data.json save file). If the same ID appears more than once, the last one wins.
  static List<NotificationItem> decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw BackupFormatException('Not JSON: ${e.message}');
    }

    if (json is! Map) throw BackupFormatException('Not a JSON object');

    final format = json['format'];
    if (format != null && format != formatId) throw BackupFormatException('Unknown format "$format"');

    final version = json['version'];
    if (version is int && version > formatVersion) throw BackupFormatException('Made by a newer version ($version)');

    final rawItems = json['notificationItems'];
    if (rawItems is! List) throw BackupFormatException('No notificationItems list');

    final byId = <String, NotificationItem>{};
    for (final raw in rawItems) {
      try {
        final item = NotificationItem.fromJson(Map<String, dynamic>.from(raw as Map));
        byId[item.id] = item;
      } catch (e) {
        throw BackupFormatException('Unreadable reminder: $e');
      }
    }
    return byId.values.toList();
  }

  /// Opens the system "save as" screen with a dated file name. Returns false if the user cancelled.
  static Future<bool> exportToFile(List<NotificationItem> items) async {
    final bytes = Uint8List.fromList(utf8.encode(encode(items)));
    final fileName = 'noterly-reminders-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';

    final path = await FilePicker.platform.saveFile(
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return path != null;
  }

  /// Lets the user pick a file and parses it. Returns null if the user cancelled.
  static Future<List<NotificationItem>?> pickAndRead() async {
    // Any file type: files shared from other apps or cloud drives often lose the JSON MIME type.
    final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.single.bytes;
    if (bytes == null) throw BackupFormatException('Could not read the file');

    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw BackupFormatException('Not a text file');
    }
    return decode(text);
  }
}
