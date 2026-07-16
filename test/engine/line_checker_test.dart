import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/corpus.dart';
import 'package:gurbani_live/engine/line_checker.dart';
import 'package:gurbani_live/engine/normalizer.dart';

const _lines = [
  'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ',
  'ਚੁਪੈ ਚੁਪ ਨ ਹੋਵਈ ਜੇ ਲਾਇ ਰਹਾ ਲਿਵ ਤਾਰ',
  'ਭੁਖਿਆ ਭੁਖ ਨ ਉਤਰੀ ਜੇ ਬੰਨਾ ਪੁਰੀਆ ਭਾਰ',
  'ਸਹਸ ਸਿਆਣਪਾ ਲਖ ਹੋਹਿ ਤ ਇਕ ਨ ਚਲੈ ਨਾਲਿ',
];

List<Verse> _verses() => [
  for (var i = 0; i < _lines.length; i++)
    Verse(
      id: '$i',
      seq: i + 1,
      gurmukhi: _lines[i],
      normalized: normalize(_lines[i]),
      page: 1,
    ),
];

void main() {
  group(LineChecker, () {
    test('slow reciter: many chunks of the same line hold, stay synced', () {
      final checker = LineChecker(_verses())..seek(1);
      for (var i = 0; i < 8; i++) {
        final check = checker.check(_lines[1]);
        expect(check.index, 1);
        expect(check.synced, isTrue);
      }
    });

    test('next-line content advances the line on the very next chunk', () {
      // No confirm streak: at real paath pace (~1 line per chunk) a "same line
      // twice" rule would never fire, and the follower would stick.
      final checker = LineChecker(_verses())..seek(1);
      final check = checker.check(_lines[2]);
      expect(check.index, 2);
      expect(check.synced, isTrue);
    });

    test('speed-independent: dwelling longer on a line changes nothing', () {
      int advanceAfter(int dwell) {
        final checker = LineChecker(_verses())..seek(0);
        for (var i = 0; i < dwell; i++) {
          checker.check(_lines[0]); // linger on line 0 at some tempo
        }
        checker.check(_lines[1]);
        return checker.current;
      }

      expect(advanceAfter(2), 1);
      expect(advanceAfter(6), 1); // tempo doesn't change the result
    });

    test('a chunk matching nothing holds the line and flags it', () {
      final checker = LineChecker(_verses())..seek(1);
      final check = checker.check('ਬਿਲਕੁਲ ਵਖਰੇ ਸਬਦ ਜੋ ਕਿਤੇ ਨਹੀਂ');
      expect(check.index, 1); // still showing what we had
      expect(check.synced, isFalse); // ...but "catching up"
    });

    test('overshooting on a noisy chunk self-corrects on the next one', () {
      // The backward horizon is what replaces hysteresis: a chunk that drags the
      // follower forward leaves the true line behind us but still in view.
      final checker = LineChecker(_verses())..seek(1);
      expect(checker.check(_lines[3]).index, 3); // noise pulls it ahead
      expect(checker.check(_lines[1]).index, 1); // the real line pulls it back
    });
  });
}
