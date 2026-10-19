import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/main.dart';

enum Repetition {
  hourly,
  daily,
  weekly,
  monthly,
  yearly;
}

class RepetitionData {
  Repetition type = Repetition.daily;
  int number = 1;

  /// Days of the week ([DateTime.monday] to [DateTime.sunday]) a weekly repetition fires on, like a clock app alarm.
  /// Empty means every [number] weeks on the weekday of the reminder's date.
  List<int> weekdays;

  bool get hasWeekdays => type == Repetition.weekly && weekdays.isNotEmpty;

  RepetitionData({
    required this.type,
    required this.number,
    List<int>? weekdays,
  }) : weekdays = weekdays ?? [];

  RepetitionData copy() => RepetitionData(type: type, number: number, weekdays: [...weekdays]);

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'number': number,
        'weekdays': weekdays,
      };

  factory RepetitionData.fromJson(Map<String, dynamic> json) => RepetitionData(
        type: Repetition.values[json['type']],
        number: json['number'],
        weekdays: json['weekdays'] != null ? List<int>.from(json['weekdays']) : null,
      );

  @override
  String toString() {
    return 'RepetitionData(type: $type, number: $number, weekdays: $weekdays)';
  }

  /// Returns [dateTime] if it falls on one of the selected weekdays, otherwise the same time on the next selected weekday.
  DateTime alignToWeekdays(DateTime dateTime) {
    if (!hasWeekdays) return dateTime;

    for (var i = 0; i < 7; i++) {
      var candidate = _addDays(dateTime, i);
      if (weekdays.contains(candidate.weekday)) return candidate;
    }
    return dateTime;
  }

  /// Returns the next time after [lastSent] that falls on a selected weekday, in a week that is a multiple of [number]
  /// weeks after the week of [lastSent].
  DateTime nextWeekdayDateTime(DateTime lastSent) {
    var lastSentWeek = _startOfWeek(lastSent);

    for (var i = 1; i <= 7 * number; i++) {
      var candidate = _addDays(lastSent, i);
      if (!weekdays.contains(candidate.weekday)) continue;

      var weeks = (_startOfWeek(candidate).difference(lastSentWeek).inHours / (24 * 7)).round();
      if (weeks % number == 0) return candidate;
    }

    return _addDays(lastSent, 7 * number); // Not reached while at least one weekday is selected
  }

  // Calendar days rather than a Duration, so the time of day stays the same across daylight saving changes
  static DateTime _addDays(DateTime dateTime, int days) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day + days, dateTime.hour, dateTime.minute, dateTime.second);

  static DateTime _startOfWeek(DateTime dateTime) => DateTime(dateTime.year, dateTime.month, dateTime.day - (dateTime.weekday - 1));

  String toReadableString() {
    final context = MyApp.navigatorKey.currentContext!;

    if (hasWeekdays) {
      final locale = Localizations.localeOf(context).toString();
      // List the days in the locale's week order, e.g. "Mon, Wed, Fri"
      final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
      final days = [
        for (var i = 0; i < 7; i++)
          if (weekdays.contains(weekdayFromIndex((firstDay + i) % 7))) DateFormat.E(locale).format(_dateOnWeekday(weekdayFromIndex((firstDay + i) % 7))),
      ];
      return '${_readableInterval(context)} (${days.join(', ')})';
    }

    return _readableInterval(context);
  }

  /// Converts a [MaterialLocalizations] weekday index (0 = Sunday) to a [DateTime] weekday (7 = Sunday).
  static int weekdayFromIndex(int index) => index == 0 ? DateTime.sunday : index;

  // 2024-01-01 was a Monday
  static DateTime _dateOnWeekday(int weekday) => DateTime(2024, 1, weekday);

  String _readableInterval(BuildContext context) {
    if (number == 1) {
      return switch (type) {
        Repetition.hourly => Strings.of(context).time_hourly,
        Repetition.daily => Strings.of(context).time_daily,
        Repetition.weekly => Strings.of(context).time_weekly,
        Repetition.monthly => Strings.of(context).time_monthly,
        Repetition.yearly => Strings.of(context).time_yearly,
      };
    }

    return Strings.of(context).time_repetition_every_value(
        number,
        switch (type) {
          Repetition.hourly => Strings.of(context).time_hours(number),
          Repetition.daily => Strings.of(context).time_days(number),
          Repetition.weekly => Strings.of(context).time_weeks(number),
          Repetition.monthly => Strings.of(context).time_months(number),
          Repetition.yearly => Strings.of(context).time_years(number),
        });
  }
}
