/// Coarse normalization for matching ASR output against the corpus.
///
/// Gurmukhi has no case; lowercasing only touches stray Latin. We keep the
/// Gurmukhi block and alphanumerics, drop punctuation (danda ॥, etc.), and
/// collapse whitespace. Port of the Python `normalize_text`.
///
/// ponytail: no NFC pass - both corpus (anvaad) and ASR (sherpa) emit NFC.
/// Add `unorm` only if a diacritic mismatch actually shows up in matching.
library;

final _nonWord = RegExp(r'[^0-9a-zA-Z਀-੿\s]+');
final _spaces = RegExp(r'\s+');

String normalize(String text) {
  var v = text.trim().toLowerCase();
  v = v.replaceAll(_nonWord, ' ');
  v = v.replaceAll(_spaces, ' ');
  return v.trim();
}
