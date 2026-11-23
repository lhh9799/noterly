import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/managers/auto_backup.dart';
import 'package:noterly/managers/backup_manager.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly/models/notification_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('noterly/backup');
  final calls = <MethodCall>[];
  PlatformException? failure;

  setUpAll(() async {
    // A failed write is logged through AppManager, whose constructor loads the save file from the documents directory
    final documents = Directory.systemTemp.createTempSync('noterly_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => documents.path);
    await AppManager.instance.ensureInitialised();
  });

  setUp(() {
    calls.clear();
    failure = null;
    AutoBackup.lastWriteSucceeded = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (failure != null) throw failure!;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  AppData withItems(String? folder) => AppData.defaults()
    ..autoBackupFolderUri = folder
    ..notificationItems = [
      NotificationItem(id: 'a', title: 'Buy milk', body: '', colour: const Color(0xFF2196F3)),
      NotificationItem(id: 'b', title: 'Call Sam', body: 'After work', colour: const Color(0xFF4CAF50), archived: true),
    ];

  test('writes nothing while automatic backup is off', () async {
    await AutoBackup.write(withItems(null));
    expect(calls, isEmpty);
    expect(AutoBackup.lastWriteSucceeded, isNull);
  });

  test('writes every reminder, archived ones too, as an importable file', () async {
    await AutoBackup.write(withItems('content://tree/folder'));

    expect(calls, hasLength(1));
    expect(calls.single.method, 'write');
    final args = Map<String, dynamic>.from(calls.single.arguments as Map);
    expect(args['folder'], 'content://tree/folder');
    expect(args['name'], AutoBackup.fileName);

    final restored = BackupManager.decode(args['content'] as String);
    expect(restored.map((e) => e.id), ['a', 'b']);
    expect(restored.last.archived, isTrue);
    expect(AutoBackup.lastWriteSucceeded, isTrue);
  });

  test('a failed write does not throw, so the save it belongs to still succeeds', () async {
    failure = PlatformException(code: 'write_failed', message: 'Permission Denial');

    await AutoBackup.write(withItems('content://tree/folder'));

    expect(calls, hasLength(1));
    expect(AutoBackup.lastWriteSucceeded, isFalse);
  });
}
