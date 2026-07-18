import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';

void main() {
  test('roman fold classes match the realm-derived fixture', () {
    // tools/data/fold_pairs.json is DERIVED from STTM's shipped realm (every
    // FirstLetterStr/FirstLetterEng pair); the code map must never drift from
    // it silently - re-derive the fixture, then change both.
    final fixture =
        jsonDecode(File('tools/data/fold_pairs.json').readAsStringSync())
            as Map<String, dynamic>;
    final classes = (fixture['classes'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as String),
    );
    expect(GurbaniDatabase.romanClasses, classes);
  });
}
