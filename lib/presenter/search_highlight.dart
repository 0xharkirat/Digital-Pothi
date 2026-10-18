import '../data/gurbani_database.dart';
import 'cubit/presenter_cubit.dart';

/// Which words of a result's Gurmukhi to emphasise for [query] under [mode] -
/// STTM's search-term highlighting. [words] are the displayed (vishraam-stripped)
/// words; [firstLetters] / [firstLettersUni] are the corpus per-word first
/// letters (GurbaniAkhar font codes / Unicode), one char per word.
///
/// Returns the indices to emphasise. Empty when the mode carries no Gurmukhi
/// match (English, Ang) or when the first-letter data can't be aligned to the
/// words 1:1 - we never guess and emphasise the wrong ones.
Set<int> matchedWordIndices({
  required List<String> words,
  required String firstLetters,
  required String firstLettersUni,
  required String query,
  required SearchMode mode,
}) {
  final q = query.replaceAll(' ', '');
  if (q.isEmpty || words.isEmpty) return const {};
  switch (mode) {
    // Full word: every word that contains the typed Gurmukhi (STTM type 2).
    case SearchMode.fullWordGurmukhi:
      return {
        for (var i = 0; i < words.length; i++)
          if (words[i].contains(q)) i,
      };
    // First letter (start): the search guaranteed the opening run matches, so
    // the first N words are the hit (STTM type 0).
    case SearchMode.firstLetterStart:
      final n = q.length < words.length ? q.length : words.length;
      return {for (var i = 0; i < n; i++) i};
    // First letter (anywhere): find the matching run in the per-word first
    // letters (STTM type 1). Guarded on 1:1 alignment with the words.
    case SearchMode.firstLetterAnywhere:
      final isGurmukhi = q.runes.any((r) => r >= 0x0A00 && r <= 0x0A7F);
      final fl = isGurmukhi ? firstLettersUni : firstLetters;
      if (fl.length != words.length) return const {};
      final ql = isGurmukhi ? q : q.toLowerCase();
      bool runAt(int s) {
        for (var j = 0; j < ql.length; j++) {
          if (!_firstLetterMatches(fl[s + j], ql[j], roman: !isGurmukhi)) {
            return false;
          }
        }
        return true;
      }

      for (var s = 0; s + ql.length <= fl.length; s++) {
        if (runAt(s)) return {for (var j = 0; j < ql.length; j++) s + j};
      }
      return const {};
    case SearchMode.fullWordEnglish:
    case SearchMode.ang:
      return const {};
  }
}

/// Does a per-word first-letter [code] satisfy one query char? Roman input folds
/// phonetically through the same [GurbaniDatabase.romanClasses] the query uses
/// (t reaches ਤ ਥ ਟ ਠ); Gurmukhi input matches the letter directly.
bool _firstLetterMatches(String code, String qChar, {required bool roman}) {
  if (!roman) return code == qChar;
  final cls = GurbaniDatabase.romanClasses[qChar];
  if (cls == null) return code == qChar;
  // cls is a GLOB class like '[sS]'; membership is the literal chars inside.
  return cls.substring(1, cls.length - 1).contains(code);
}
