import 'package:noterly/l10n/app_localisations.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/main.dart';

extension DurationExtensions on Duration {
  /// [strings] lets code without a BuildContext (background isolates) pass the strings in.
  String toRelativeDurationString([AppLocalisations? strings]) {
    final days = inDays;
    final hours = inHours % 24;
    final minutes = inMinutes % 60;

    final s = strings ?? Strings.of(MyApp.navigatorKey.currentContext!);

    final daysString = days == 0 ? '' : s.time_days_value(days);
    final hoursString = hours == 0 ? '' : s.time_hours_value(hours);
    final minutesString = minutes == 0 ? '' : s.time_minutes_value(minutes);

    final combined = '$daysString, $hoursString, $minutesString'.trim();
    return combined.replaceAll(RegExp(r', ,'), ',').replaceAll(RegExp(r',$'), '').replaceAll(RegExp(r'^,\s*'), ''); // Remove trailing, leading or double commas
  }
}
