import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/search_highlight.dart';

void main() {
  // The ਸੋਚੈ line: 8 words, one first letter each (font code / Unicode).
  final words = 'ਸੋਚੈ ਸੋਚਿ ਨ ਹੋਵਈ ਜੇ ਸੋਚੀ ਲਖ ਵਾਰ'.split(' ');
  const fl = 'ssnhjslv';
  const flu = 'ਸਸਨਹਜਸਲਵ';

  Set<int> match(String query, SearchMode mode) => matchedWordIndices(
    words: words,
    firstLetters: fl,
    firstLettersUni: flu,
    query: query,
    mode: mode,
  );

  test('first-letter start highlights the opening run', () {
    expect(match('ss', SearchMode.firstLetterStart), {0, 1});
    expect(match('ssnh', SearchMode.firstLetterStart), {0, 1, 2, 3});
  });

  test('first-letter anywhere finds the run mid-line (roman)', () {
    expect(match('nh', SearchMode.firstLetterAnywhere), {2, 3});
    expect(match('ssnh', SearchMode.firstLetterAnywhere), {0, 1, 2, 3});
  });

  test('first-letter anywhere matches Gurmukhi input directly', () {
    expect(match('ਨਹ', SearchMode.firstLetterAnywhere), {2, 3});
  });

  test('roman folds phonetically when locating the run', () {
    // ਥ is font code q; a t-query must still reach it.
    expect(
      matchedWordIndices(
        words: ['ਪਹਿਲਾ', 'ਥੋੜਾ'],
        firstLetters: 'pq',
        firstLettersUni: 'ਪਥ',
        query: 't',
        mode: SearchMode.firstLetterAnywhere,
      ),
      {1},
    );
  });

  test('full-word highlights every word containing the query', () {
    expect(match('ਸੋਚ', SearchMode.fullWordGurmukhi), {0, 1, 5});
  });

  test('anywhere never guesses when first letters do not align 1:1', () {
    expect(
      matchedWordIndices(
        words: words, // 8 words
        firstLetters: 'ssn', // only 3 - misaligned (danda/number drift)
        firstLettersUni: 'ਸਸਨ',
        query: 'nh',
        mode: SearchMode.firstLetterAnywhere,
      ),
      isEmpty,
    );
  });

  test('English and Ang modes carry no Gurmukhi highlight', () {
    expect(match('ਸੋਚ', SearchMode.fullWordEnglish), isEmpty);
    expect(match('4', SearchMode.ang), isEmpty);
  });

  test('empty query highlights nothing', () {
    expect(match('   ', SearchMode.firstLetterStart), isEmpty);
  });
}
