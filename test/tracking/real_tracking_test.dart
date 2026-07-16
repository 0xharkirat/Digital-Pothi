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

/// The bundled corpus, gitignored for size.
const _corpus = 'assets/corpus/gurbani.sqlite';

/// Japji occupies order_id 1..385 of the corpus's 141,264 lines - and sits right
/// on the low edge, where the anchor window has nothing behind it to slide into.
const _japjiFirst = 1;
const _japjiLast = 385;

/// End-to-end on REAL ASR output: the finetuned IndicConformer-CTC (ONNX, via
/// sherpa) transcript of japuji-full.wav, fed chunk by chunk through the real
/// [TrackingCubit] against the real 141k-line corpus.
///
/// Nothing tells it that this is Japji. Finding that out - out of every line in
/// every source - is the thing under test.
void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  test(
    'discovers Japji in the full corpus from real ASR, then follows it',
    () async {
      final chunks =
          (json.decode(
                    File(
                      'test/fixtures/japuji_sherpa_chunks.json',
                    ).readAsStringSync(),
                  )
                  as List)
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

      final seqs = <int>[];
      await cubit.toggleMic();
      for (final text in chunks) {
        onText.add(text);
        await Future<void>.delayed(Duration.zero);
        final verse = cubit.state.verse;
        if (verse != null) seqs.add(verse.seq);
      }
      await onText.close();

      expect(seqs, isNotEmpty, reason: 'never found a line');

      // Locked on early...
      expect(
        seqs.first,
        lessThan(60),
        reason: 'located too late in the bani: line ${seqs.first}',
      );
      // ...never wandered out of Japji, though 140,879 other lines were reachable...
      expect(
        seqs.every((s) => s >= _japjiFirst && s <= _japjiLast),
        isTrue,
        reason: 'wandered outside Japji: ${seqs.where((s) => s > _japjiLast)}',
      );
      // ...ran the bani out to its final line...
      expect(
        seqs.last,
        greaterThanOrEqualTo(_japjiLast - 5),
        reason: 'stalled; ended on line ${seqs.last}',
      );
      expect(
        _forwardFraction(seqs),
        greaterThan(0.98),
        reason: 'too jumpy: ${(_forwardFraction(seqs) * 100).round()}% forward',
      );
      // ...and *followed* it, line by line, rather than lurching between
      // relocates. A follower that sticks still ends up far along, it just gets
      // there in leaps, so hold it to how many distinct lines it actually showed.
      expect(
        seqs.toSet().length,
        greaterThan(200),
        reason:
            'only showed ${seqs.toSet().length} distinct lines; not following',
      );
    },
    skip: File(_corpus).existsSync()
        ? null
        : 'corpus asset missing (gitignored, 46 MB): build it from the '
              'ShabadOS SQLite - see docs/db_wiring_plan.md',
  );
}

/// Fraction of consecutive steps that did not regress.
double _forwardFraction(List<int> seqs) {
  if (seqs.length < 2) return 1;
  var ok = 0;
  for (var i = 1; i < seqs.length; i++) {
    if (seqs[i] >= seqs[i - 1]) ok++;
  }
  return ok / (seqs.length - 1);
}
