import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test("translations write an apostrophe once, not ICU's escaped ''", () {
    // l10n.yaml sets use-escaping: false, so '' would be shown as two apostrophes ("That''s it!")
    final found = <String>[];
    for (final file in Directory('lib/l10n').listSync().whereType<File>().where((f) => f.path.endsWith('.arb'))) {
      final strings = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      strings.forEach((key, value) {
        if (value is String && value.contains("''")) found.add('${file.uri.pathSegments.last} $key');
      });
    }
    expect(found, isEmpty);
  });
}
