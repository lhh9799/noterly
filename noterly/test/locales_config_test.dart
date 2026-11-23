import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/l10n/app_localisations.dart';

void main() {
  test("Android's per-app language list matches the app's translations", () {
    final xml = File('android/app/src/main/res/xml/locales_config.xml').readAsStringSync();
    final listed = RegExp(r'android:name="([^"]+)"').allMatches(xml).map((m) => m[1]).toSet();

    // Plain "en" is left out of the list on purpose: it reads the same as en-GB
    final translations =
        AppLocalisations.supportedLocales.map((l) => l.toLanguageTag()).where((tag) => tag != 'en').toSet();

    expect(listed, translations);
  });
}
