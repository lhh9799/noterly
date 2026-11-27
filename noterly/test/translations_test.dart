import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:noterly/extensions/duration_extensions.dart';
import 'package:noterly/l10n/app_localisations.dart';

void main() {
  Map<String, Map<String, dynamic>> arbFiles() => {
        for (final file in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb')))
          file.uri.pathSegments.last: jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
      };

  test("translations write an apostrophe once, not ICU's escaped ''", () {
    // l10n.yaml sets use-escaping: false, so '' would be shown as two apostrophes ("That''s it!")
    final found = <String>[];
    arbFiles().forEach((file, strings) {
      strings.forEach((key, value) {
        if (value is String && value.contains("''")) found.add('$file $key');
      });
    });
    expect(found, isEmpty);
  });

  test('translations keep every placeholder of the English template', () {
    final files = arbFiles();
    final template = files['app.arb']!;
    final missing = <String>[];
    files.forEach((file, strings) {
      template.forEach((key, meta) {
        if (!key.startsWith('@') || key.startsWith('@@') || meta is! Map || meta['placeholders'] is! Map) return;
        final message = strings[key.substring(1)];
        if (message is! String) return;
        for (final name in (meta['placeholders'] as Map).keys) {
          if (!RegExp('\\{$name[,}]').hasMatch(message)) missing.add('$file ${key.substring(1)} {$name}');
        }
      });
    });
    expect(missing, isEmpty);
  });

  test('one of a unit reads differently from two, so durations are not "1 hours"', () {
    for (final locale in AppLocalisations.supportedLocales.where((locale) => locale.languageCode != 'ko')) {
      final strings = lookupAppLocalisations(locale);
      String unit(Duration duration) => duration.toRelativeDurationString(strings).replaceAll(RegExp(r'\d'), '').trim();

      expect(unit(const Duration(minutes: 1)), isNot(unit(const Duration(minutes: 2))), reason: '$locale minutes');
      expect(unit(const Duration(hours: 1)), isNot(unit(const Duration(hours: 2))), reason: '$locale hours');
      expect(unit(const Duration(days: 1)), isNot(unit(const Duration(days: 2))), reason: '$locale days');
    }
  });
}
