import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/asr_service.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/tracking/cubit/tracking_cubit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqlite3/sqlite3.dart';

class _MockAsr extends Mock implements GurbaniAsr {}

class _MockPlayer extends Mock implements AudioPlayer {}

const _corpus = 'assets/corpus/gurbani.sqlite';
const _fixture = 'test/fixtures/kirtan_gurnam_chunks.json';

/// A sung shabad and where it should land. [firstChunk] is the 3s-hop index the
/// reciter starts it (from the recording's own timestamps); [angs] are the
/// corpus pages it may show (some shabads span two, and two of these have a
/// verbatim twin elsewhere - only the raag-correct ang is listed).
typedef Segment = ({String name, int firstChunk, Set<int> angs});

/// Dr. Gurnam Singh Ji & Jatha, Newcastle AU, six shabads across raags in one
/// hour - out of corpus order (ang 1111 → 469 → 408 → 349 → 6/7), so every
/// transition is a jump across the whole corpus. The instrumental intro and the
/// manglacharan are excluded: live mic gates them with VAD, and there's no
/// stable ground-truth line to assert against anyway.
const _segments = <Segment>[
  (name: 'Saajan Des Videsiarre', firstChunk: 128, angs: {1111}),
  (name: 'Balehaari Kudrat Vaseaa', firstChunk: 452, angs: {469}),
  (name: 'Kaam Krodh Lobh Tiaag', firstChunk: 618, angs: {408, 409}),
  (name: 'So Keon Visrai Meri Maaye', firstChunk: 845, angs: {349}),
  (name: 'Aades Tise Aades', firstChunk: 1018, angs: {6, 7}),
];

/// Chunk after which a segment's transition has settled - the tracker is allowed
/// this long to notice the reciter changed shabad and re-locate.
const _settle = 40;

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  test(
    'tracks six raag shabads in one hour of real kirtan, in and out of order',
    () async {
      final chunks = (json.decode(File(_fixture).readAsStringSync()) as List)
          .cast<String>();

      final asr = _MockAsr();
      final player = _MockPlayer();
      final onText = StreamController<String>.broadcast();
      when(() => asr.onText).thenAnswer((_) => onText.stream);
      when(() => asr.start()).thenAnswer((_) async => true);
      when(() => asr.stop()).thenAnswer((_) async {});
      when(() => asr.dispose()).thenAnswer((_) async {});
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});

      final cubit = TrackingCubit(
        database: GurbaniDatabase.forTesting(
          sqlite3.open(_corpus, mode: OpenMode.readOnly),
        ),
        asr: asr,
        player: player,
      );
      addTearDown(cubit.close);

      final angs = <int?>[];
      await cubit.toggleMic();
      for (final text in chunks) {
        onText.add(text);
        await Future<void>.delayed(Duration.zero);
        angs.add(cubit.state.verse?.page);
      }
      await onText.close();

      for (var s = 0; s < _segments.length; s++) {
        final seg = _segments[s];
        // Score from after the settle window to the next shabad's start.
        final from = seg.firstChunk + _settle;
        final to = s + 1 < _segments.length
            ? _segments[s + 1].firstChunk
            : angs.length;
        final slice = angs.sublist(from, to);
        final onTarget = slice.where((a) => seg.angs.contains(a)).length;
        final frac = onTarget / slice.length;
        expect(
          frac,
          greaterThan(0.7),
          reason:
              '${seg.name}: only ${(frac * 100).round()}% of chunks $from-$to '
              'on ang ${seg.angs}',
        );
      }
    },
    skip: File(_corpus).existsSync()
        ? null
        : 'corpus asset missing (gitignored, 46 MB): see docs/db_wiring_plan.md',
  );
}
