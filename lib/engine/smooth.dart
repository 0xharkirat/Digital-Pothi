import 'corpus.dart';

/// Forward-fill a per-window verse sequence for display: hold the last shown
/// verse rather than snapping backward on a single-window blip, but accept a
/// backward move that persists into the next window (a real return to an earlier
/// line). Also fills the gaps, so a window of pure invocation shows the line
/// still standing rather than nothing at all.
///
/// Only usable when the whole timeline is known up front (file playback) - it
/// reads one window ahead.
List<Verse?> smoothForward(List<Verse?> raw) {
  final out = <Verse?>[];
  Verse? shown;
  for (var i = 0; i < raw.length; i++) {
    final verse = raw[i];
    if (verse != null) {
      if (shown == null || verse.seq >= shown.seq) {
        shown = verse;
      } else {
        final next = i + 1 < raw.length ? raw[i + 1] : null;
        if (next != null && next.seq < shown.seq) shown = verse; // sustained
      }
    }
    out.add(shown);
  }
  return out;
}
