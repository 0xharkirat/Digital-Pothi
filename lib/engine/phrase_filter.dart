import 'normalizer.dart';

/// Ritual / announcement phrases that surround paath but are not bani text:
/// invocations, jaikaras, and spoken bani names. Stripping them stops the
/// tracker locking onto "satnam sri waheguru" instead of the actual first line.
///
/// Whole phrases only (never bare shared words like ਸਾਹਿਬ, which occurs inside
/// real tuks). ponytail: exact-substring on a curated list - the ASR is
/// consistent enough; add fuzzy matching only if variants slip through.
const _rawPhrases = [
  'ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫਤਹ',
  'ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖ਼ਾਲਸਾ ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫ਼ਤਹ',
  'ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ',
  'ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫਤਹ',
  'ਸਤਿ ਨਾਮੁ ਸ੍ਰੀ ਵਾਹਿਗੁਰੂ',
  'ਸਤਿਨਾਮੁ ਸ੍ਰੀ ਵਾਹਿਗੁਰੂ',
  'ਸ੍ਰੀ ਵਾਹਿਗੁਰੂ ਜੀ',
  'ਬੋਲੇ ਸੋ ਨਿਹਾਲ ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ',
  'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ',
  'ਜਪੁਜੀ ਸਾਹਿਬ',
  'ਜਾਪੁ ਸਾਹਿਬ',
  'ਰਹਿਰਾਸ ਸਾਹਿਬ',
  'ਅਨੰਦ ਸਾਹਿਬ',
  'ਸੁਖਮਨੀ ਸਾਹਿਬ',
  'ਕੀਰਤਨ ਸੋਹਿਲਾ',
  'ਚੌਪਈ ਸਾਹਿਬ',
  // Bare chant - safe for Nitnem paath; revisit for Bhatt bani where it occurs.
  'ਵਾਹਿਗੁਰੂ',
];

final List<String> _phrases =
    (_rawPhrases.map(normalize).where((p) => p.isNotEmpty).toList())
      ..sort((a, b) => b.length.compareTo(a.length)); // longest first

/// The chant, cut short. A fixed transcription window clips its last word, so
/// the jaikara routinely lands as "…ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ ਵਾਹਿਗੁਰ" - the phrase
/// list matches the whole part and leaves the stub, which is enough to match a
/// ਵਾਹਿਗੁਰੂ line somewhere in 141k and drag the tracker off the bani. Match by
/// prefix instead of listing every truncation; nothing in bani begins this way.
final _chantStub = RegExp('ਵਾਹਿਗੁਰ[^ ]*');

/// Remove known non-verse phrases from ASR text. Returns normalized residue
/// (empty if the window was pure invocation/announcement).
String stripNonVerse(String text) {
  var s = ' ${normalize(text)} ';
  var changed = true;
  while (changed) {
    changed = false;
    for (final p in _phrases) {
      final needle = ' $p ';
      if (s.contains(needle)) {
        s = s.replaceAll(needle, ' ');
        changed = true;
      }
    }
  }
  return s.replaceAll(_chantStub, ' ').trim().replaceAll(RegExp(r'\s+'), ' ');
}
