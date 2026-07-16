/// Similarity in [0,1] between an ASR transcript and a corpus line: char-bigram
/// Dice (order-robust, survives a misheard word), token overlap, and a small
/// containment bonus for a partial window that sits inside a longer tuk.
///
/// One scorer for the whole app: the locator reranks the database's candidates
/// with it and the follower advances on it, so locate and follow can never
/// disagree about what "matches" means.
///
/// [query] and [verseNormalized] must both already be normalized.
double lineSimilarity(String query, String verseNormalized) {
  if (query.isEmpty || verseNormalized.isEmpty) return 0;
  final dice = _bigramDice(query, verseNormalized);
  final overlap = _tokenOverlap(query, verseNormalized);
  var bonus = 0.0;
  if (verseNormalized.contains(query)) {
    bonus = 0.1;
  } else if (query.contains(verseNormalized)) {
    bonus = 0.05;
  }
  return (dice * 0.6 + overlap * 0.3 + bonus).clamp(0, 1);
}

double _bigramDice(String a, String b) {
  final ga = _bigrams(a), gb = _bigrams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  var inter = 0;
  for (final g in ga) {
    if (gb.contains(g)) inter++;
  }
  return 2 * inter / (ga.length + gb.length);
}

List<String> _bigrams(String s) {
  final t = s.replaceAll(' ', '');
  return [for (var i = 0; i < t.length - 1; i++) t.substring(i, i + 2)];
}

double _tokenOverlap(String a, String b) {
  final ta = a.split(' ').toSet(), tb = b.split(' ').toSet();
  if (ta.isEmpty || tb.isEmpty) return 0;
  return ta.intersection(tb).length / ta.union(tb).length;
}
