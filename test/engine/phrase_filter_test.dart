import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/normalizer.dart';
import 'package:gurbani_live/engine/phrase_filter.dart';

void main() {
  group('stripNonVerse', () {
    test('drops the invocation but keeps the real mul mantar', () {
      final out = stripNonVerse(
        'ਸਤਿਨਾਮੁ ਸ੍ਰੀ ਵਾਹਿਗੁਰੂ ਜੀ ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖ',
      );
      expect(out.contains('ਕਰਤਾ ਪੁਰਖ'), isTrue);
      expect(out.contains('ਵਾਹਿਗੁਰੂ'), isFalse); // invocation waheguru removed
    });

    test('a pure jaikara / khalsa-fateh line collapses to empty', () {
      expect(stripNonVerse('ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫਤਹ'), isEmpty);
      expect(stripNonVerse('ਬੋਲੇ ਸੋ ਨਿਹਾਲ ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ'), isEmpty);
    });

    test('a spoken bani name collapses to empty', () {
      expect(stripNonVerse('ਜਪੁਜੀ ਸਾਹਿਬ'), isEmpty);
    });

    test('leaves a real verse untouched (normalized)', () {
      const verse = 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ';
      expect(stripNonVerse(verse), normalize(verse));
    });
  });
}
