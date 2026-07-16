import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/corpus.dart';
import 'package:gurbani_live/engine/smooth.dart';

void main() {
  group('smoothForward', () {
    Verse verse(int seq) =>
        Verse(id: '$seq', seq: seq, gurmukhi: '', normalized: '', page: 1);
    List<int?> seqs(List<Verse?> l) => [for (final e in l) e?.seq];

    test('holds through a single-window backward blip', () {
      expect(seqs(smoothForward([verse(1), verse(3), verse(2), verse(4)])), [
        1,
        3,
        3,
        4,
      ]);
    });

    test('accepts a sustained backward move (a real return)', () {
      expect(seqs(smoothForward([verse(5), verse(2), verse(2)])), [5, 2, 2]);
    });

    test('forward-fills gaps with the last shown verse', () {
      expect(seqs(smoothForward([null, verse(2), null, verse(3)])), [
        null,
        2,
        2,
        3,
      ]);
    });
  });
}
