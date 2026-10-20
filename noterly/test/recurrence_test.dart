import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/models/repetition_data.dart';

/// Runs the repeat cases shared with the watch app (wearshared RecurrenceTest.kt in noterly-watch). Dart uses the
/// process's time zone, so only the cases for the TZ the test runs in are checked:
///
///   TZ=Asia/Seoul flutter test test/recurrence_test.dart
///   TZ=America/New_York flutter test test/recurrence_test.dart
void main() {
  final cases = (jsonDecode(File('test/recurrence_cases.json').readAsStringSync())['cases'] as List).cast<Map<String, dynamic>>();
  final zone = Platform.environment['TZ'];

  for (final testCase in cases) {
    final name = testCase['name'] as String;
    test(name, () {
      final repetition = RepetitionData.fromJson(testCase['repetition']);
      final start = DateTime.parse(testCase['start']);

      if (testCase['next'] != null) {
        var item = NotificationItem(id: 'id', title: name, body: '', colour: Colors.red, dateTime: start, repetitionData: repetition);
        for (final expected in testCase['next']) {
          item.dateTime = item.nextRepeatDateTime;
          expect(item.dateTime, DateTime.parse(expected));
        }
      }

      if (testCase['advance'] != null) {
        // What updateRepeatingNotification does when a repeat is marked as done
        final now = DateTime.parse(testCase['now']);
        var dateTime = start;
        while (dateTime.isBefore(now)) {
          dateTime = repetition.nextDateTime(dateTime);
        }
        expect(dateTime, DateTime.parse(testCase['advance']));
      }
    }, skip: zone == testCase['zone'] ? false : 'Run with TZ=${testCase['zone']}');
  }
}
