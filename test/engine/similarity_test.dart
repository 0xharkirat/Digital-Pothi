import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/normalizer.dart';
import 'package:gurbani_live/engine/similarity.dart';

const _line = 'ਭੁਖਿਆ ਭੁਖ ਨ ਉਤਰੀ ਜੇ ਬੰਨਾ ਪੁਰੀਆ ਭਾਰ';
const _other = 'ਸਹਸ ਸਿਆਣਪਾ ਲਖ ਹੋਹਿ ਤ ਇਕ ਨ ਚਲੈ ਨਾਲਿ';

double score(String query, String verse) =>
    lineSimilarity(normalize(query), normalize(verse));

void main() {
  group('lineSimilarity', () {
    test('an exact line scores near 1, an unrelated one near 0', () {
      expect(score(_line, _line), greaterThan(0.9));
      expect(score(_line, _other), lessThan(0.3));
    });

    test('survives misheard words, which is the whole job', () {
      // What the ASR actually produced for this line: two words wrong, one lost,
      // a stray word from the line before. It still has to clear the tracker's
      // anchor bar (0.40) and stay far clear of an unrelated line.
      const heard = 'ਅਤਾਰ ਭੁਖਿਆ ਭੁਖ ਨ ਉਤਰੇ ਜੈ ਬਨਾ ਪੁਰੀ';
      expect(score(heard, _line), greaterThan(0.40));
      expect(score(heard, _line), greaterThan(score(heard, _other) * 3));
    });

    test('ranks the right line above a rhyming neighbour', () {
      const heard = 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ';
      const soche = 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ';
      const chupe = 'ਚੁਪੈ ਚੁਪ ਨ ਹੋਵਈ ਜੇ ਲਾਇ ਰਹਾ ਲਿਵ ਤਾਰ';
      expect(score(heard, soche), greaterThan(score(heard, chupe)));
    });

    test('an empty side scores 0', () {
      expect(score('', _line), 0);
      expect(score(_line, ''), 0);
    });
  });
}
