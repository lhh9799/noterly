import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:noterly/extensions/duration_extensions.dart';
import 'package:noterly/l10n/app_localisations.dart';
import 'package:noterly/models/repetition_data.dart';

void main() {
  final ko = lookupAppLocalisations(const Locale('ko'));

  // app_ko.arb keeps words together with invisible word joiners (scripts/l10n/ko_keep_all.py); compare the words
  String plain(String text) => text.replaceAll('⁠', '');

  setUpAll(() => initializeDateFormatting('ko'));

  test('Korean is one of the app languages', () {
    expect(AppLocalisations.supportedLocales, contains(const Locale('ko')));
  });

  test('durations, such as the snooze toast, read as Korean', () {
    expect(plain(const Duration(hours: 1).toRelativeDurationString(ko)), '1시간');
    expect(plain(const Duration(days: 1, minutes: 30).toRelativeDurationString(ko)), '1일, 30분');
    expect(plain(ko.toast_notificationSnoozed(const Duration(hours: 2).toRelativeDurationString(ko))), '2시간 후에 다시 알려 드립니다.');
  });

  test('a snoozed reminder says when it comes back', () {
    // As built by toSnoozedUntilDateTimeString for tomorrow
    final until = ko.time_snooze_until(ko.time_tomorrowAndTime('오전 6:36'));
    expect(plain(ko.page_activeNotifications_item_snoozed(until)), '내일 오전 6:36에 다시 알림');
  });

  test('repeat descriptions read as Korean', () {
    String repeats(RepetitionData repetition) =>
        plain(ko.page_activeNotifications_item_repeats(repetition.toReadableStringWith(ko, 'ko', 0)));

    expect(repeats(RepetitionData(type: Repetition.daily, number: 1)), '매일 반복');
    expect(repeats(RepetitionData(type: Repetition.hourly, number: 2)), '2시간마다 반복');
    expect(repeats(RepetitionData(type: Repetition.monthly, number: 3)), '3개월마다 반복');
    // Tuesday and Thursday, in a week that starts on Sunday
    expect(repeats(RepetitionData(type: Repetition.weekly, number: 1, weekdays: [4, 2])), '매주 (화, 목) 반복');
  });

  test('every Korean word is kept together, so lines only break at spaces', () {
    final text = ko.page_settings_google_backup_reminders_subtitle;
    expect(RegExp('[가-힣][가-힣]').hasMatch(text), isFalse);
  });
}
