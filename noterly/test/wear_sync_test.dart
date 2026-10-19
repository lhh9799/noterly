import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/managers/wear_sync.dart';
import 'package:noterly/models/app_data.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/models/repetition_data.dart';

void main() {
  final now = DateTime(2026, 10, 19, 12);

  NotificationItem single() => NotificationItem(id: 'single', title: 'Call mum', body: 'Before 6', colour: Colors.red, dateTime: DateTime(2026, 10, 19, 18));

  NotificationItem weekly() => NotificationItem(
        id: 'weekly',
        title: 'Gym',
        body: '',
        colour: Colors.green,
        dateTime: DateTime(2026, 10, 19, 9), // Monday
        repetitionData: RepetitionData(type: Repetition.weekly, number: 1, weekdays: [1, 3, 5]),
      );

  AppData data(List<NotificationItem> items) => AppData.fromJson({})..notificationItems = items;

  WearCommand command(String type, String itemId, {Map<String, dynamic> payload = const {}, DateTime? issuedAt, String id = 'c1'}) =>
      WearCommand(commandId: id, type: type, itemId: itemId, baseRev: 1, issuedAt: issuedAt ?? now, payload: payload);

  group('snapshot', () {
    test('holds the items as saved, settings, rev and applied commands', () {
      final appData = data([single(), weekly()])
        ..rev = 128
        ..snoozeDuration = const Duration(minutes: 30)
        ..appliedWearCommands = ['old'];
      final snapshot = jsonDecode(jsonEncode(WearSync.buildSnapshot(appData, now: now, repeatLabel: (r) => 'weekly (Mon, Wed, Fri)')));

      expect(snapshot['schema'], 1);
      expect(snapshot['rev'], 128);
      expect(snapshot['settings'], {'snoozeSeconds': 1800, 'dismissibleEnabled': true});
      expect(snapshot['appliedCommands'], ['old']);

      final items = snapshot['items'] as List;
      expect(items[0]['title'], 'Call mum');
      expect(items[0]['dateTime'], '2026-10-19T18:00:00.000');
      expect(items[0]['upcoming'], isEmpty);
      expect(items[0]['repeatLabel'], isNull);
      expect(items[1]['repeatLabel'], 'weekly (Mon, Wed, Fri)');
      // Monday 09:00 has passed at noon
      expect(items[1]['upcoming'].take(3), ['2026-10-21T09:00:00.000', '2026-10-23T09:00:00.000', '2026-10-26T09:00:00.000']);

      // The watch reads the item fields with NotificationItem.fromJson's format
      expect(NotificationItem.fromJson(Map<String, dynamic>.from(items[1])).repetitionData!.weekdays, [1, 3, 5]);
    });

    test('old save files without rev, updatedAt or applied commands still load', () {
      final old = AppData.fromJson({
        'notificationItems': [single().toJson()..remove('updatedAt')],
        'snoozeDuration': 3600,
      });
      expect(old.rev, 0);
      expect(old.appliedWearCommands, isEmpty);
      expect(old.notificationItems.single.updatedAt, isNull);
    });
  });

  group('commands', () {
    test('a command ID is only applied once', () {
      final appData = data([single()]);
      expect(WearSync.decide(appData, single(), command(WearCommand.done, 'single')), WearCommandOutcome.apply);
      WearSync.recordApplied(appData, 'c1');
      expect(WearSync.decide(appData, single(), command(WearCommand.done, 'single')), WearCommandOutcome.duplicate);
    });

    test('done or snooze on an archived or missing item is ignored', () {
      final archived = single()
        ..archived = true
        ..archivedDateTime = now;
      final appData = data([archived]);
      expect(WearSync.decide(appData, archived, command(WearCommand.done, 'single')), WearCommandOutcome.ignore);
      expect(WearSync.decide(appData, archived, command(WearCommand.snooze, 'single')), WearCommandOutcome.ignore);
      expect(WearSync.decide(appData, null, command(WearCommand.done, 'gone')), WearCommandOutcome.ignore);
      expect(WearSync.decide(appData, archived, command(WearCommand.restore, 'single')), WearCommandOutcome.apply);
    });

    test('a repeat done on both sides only moves on once', () {
      // The phone already marked Monday as done and moved on to Wednesday; the watch's command saw Monday
      final movedOn = weekly()..dateTime = DateTime(2026, 10, 21, 9);
      final done = command(WearCommand.done, 'weekly', payload: {'seenDateTime': DateTime(2026, 10, 19, 9).toIso8601String()});
      expect(WearSync.decide(data([movedOn]), movedOn, done), WearCommandOutcome.ignore);
      expect(WearSync.decide(data([weekly()]), weekly(), done), WearCommandOutcome.apply);
    });

    test('an update older than the phone\'s last edit is dropped', () {
      final edited = single()..updatedAt = now.add(const Duration(minutes: 5));
      final update = command(WearCommand.update, 'single', payload: {'title': 'Call dad'});
      expect(WearSync.decide(data([edited]), edited, update), WearCommandOutcome.ignore);
      expect(WearSync.decide(data([single()]), single(), update), WearCommandOutcome.apply);
    });

    test('create only applies to a new ID', () {
      expect(WearSync.decide(data([]), null, command(WearCommand.create, 'new')), WearCommandOutcome.apply);
      expect(WearSync.decide(data([single()]), single(), command(WearCommand.create, 'single')), WearCommandOutcome.ignore);
    });

    test('the applied list keeps the last 200', () {
      final appData = data([]);
      for (var i = 0; i < 250; i++) {
        WearSync.recordApplied(appData, 'c$i');
      }
      expect(appData.appliedWearCommands.length, WearSync.maxAppliedCommands);
      expect(appData.appliedWearCommands.first, 'c50');
    });

    test('command JSON from the watch parses', () {
      final parsed = WearCommand.fromJson(jsonDecode('''
        {"commandId":"c9","type":"update","itemId":"single","baseRev":7,"issuedAt":"2026-10-19T12:00:00.000",
         "payload":{"seenDateTime":null,"title":"T","body":"","dateTime":"2026-10-20T08:00:00.000",
                    "repetitionData":{"type":2,"number":2,"weekdays":[2,4]},"colour":4283215696}}
      '''));
      expect(parsed.dateTime, DateTime(2026, 10, 20, 8));
      expect(parsed.repetitionData!.number, 2);
      expect(parsed.repetitionData!.weekdays, [2, 4]);
      expect(Color(parsed.payload['colour']).toARGB32(), 0xFF4CAF50);
    });
  });

  test('bridge tag matches the watch', () {
    expect(WearSync.bridgeTag('id', DateTime.fromMillisecondsSinceEpoch(1792400000000)), 'noterly:id:1792400000000');
    expect(WearSync.bridgeTag('id', null), 'noterly:id:immediate');
  });
}
