import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jiffy/jiffy.dart';
import 'package:noterly/l10n/app_localisations.dart';

class Strings {
  static AppLocalisations of(BuildContext context) => Localizations.of<AppLocalisations>(context, AppLocalisations)!;

  /// The phone's language among the app's, for code without a [BuildContext] (notifications, background isolates).
  static Locale currentLocale() =>
      basicLocaleListResolution(PlatformDispatcher.instance.locales, AppLocalisations.supportedLocales);

  /// The strings in the phone's language, for code without a [BuildContext].
  static AppLocalisations current() => lookupAppLocalisations(currentLocale());

  static String? _dateLocale;

  /// Makes DateFormat without a locale, and Jiffy's relative times ("5 minutes ago"), use [locale].
  static Future<void> useForDates(Locale locale) async {
    final name = Intl.canonicalizedLocale(locale.toString());
    if (name == _dateLocale) return;
    _dateLocale = name;

    await initializeDateFormatting(name);
    Intl.defaultLocale = name;
    try {
      await Jiffy.setLocale(locale.languageCode);
    } catch (_) {
      // A language Jiffy does not know keeps its English relative times
      await Jiffy.setLocale('en');
    }
  }
}
