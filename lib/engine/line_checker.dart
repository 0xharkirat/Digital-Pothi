import 'corpus.dart';
import 'normalizer.dart';
import 'similarity.dart';

/// Result of checking the live audio against the currently shown line.
class LineCheck {
  const LineCheck({
    required this.index,
    required this.synced,
    required this.score,
  });

  /// Line index we believe is being recited now.
  final int index;

  /// True when the audio actually matched a line in the horizon - i.e. the
  /// display is confirmed current. False when nothing matched, so we are holding
  /// the last known line and guessing (UI shows a subtle "catching up").
  final bool synced;
  final double score;
}

/// Confirms - every audio chunk - which line is being recited, by scoring the
/// chunk against a short horizon around the line we are showing.
///
/// Speed-independent by construction: the line advances on content, not on a
/// clock. A slow reciter keeps matching the current line, so it holds; a fast
/// reciter's next-line words arrive sooner, so it advances sooner. No tempo
/// assumption anywhere.
///
/// It commits to the best line in the horizon immediately, with no confirm
/// streak. A streak sounds safer and is not: real paath runs about one line per
/// transcription chunk (Japji is ~385 lines in ~18 minutes, against a 3 s hop),
/// so the best-matching line is a *different* one on each chunk and a "same line
/// twice" rule never confirms - the follower sticks while the reciter walks
/// away. [back] is what absorbs a bad chunk instead: overshoot on noise and the
/// true line is still behind us, in the horizon, so the next chunk pulls us back.
class LineChecker {
  LineChecker(this._verses, {this.back = 2, this.ahead = 3, this.floor = 0.30});

  final List<Verse> _verses;

  /// How far back / ahead of the current line to look each chunk.
  final int back;
  final int ahead;

  /// Minimum similarity to trust any match at all.
  final double floor;

  int _current = 0;

  int get current => _current;

  /// Jump the checker to a known line (e.g. after a locate).
  void seek(int index) => _current = index.clamp(0, _verses.length - 1);

  LineCheck check(String transcript) {
    final query = normalize(transcript);
    if (query.replaceAll(' ', '').length < 3) {
      return LineCheck(index: _current, synced: true, score: 0);
    }

    final lo = (_current - back).clamp(0, _verses.length - 1);
    final hi = (_current + ahead + 1).clamp(0, _verses.length);
    var bestIdx = _current;
    var best = 0.0;
    for (var i = lo; i < hi; i++) {
      final score = lineSimilarity(query, _verses[i].normalized);
      if (score > best) {
        best = score;
        bestIdx = i;
      }
    }

    // Nothing in the horizon matches - hold the line, but flag it as unconfirmed.
    if (best < floor) {
      return LineCheck(index: _current, synced: false, score: best);
    }

    _current = bestIdx;
    return LineCheck(index: _current, synced: true, score: best);
  }
}
