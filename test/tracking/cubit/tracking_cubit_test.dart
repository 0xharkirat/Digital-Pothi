import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/asr_service.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/engine/transcribe_isolate.dart';
import 'package:gurbani_live/tracking/cubit/tracking_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_corpus.dart';

class _MockAsr extends Mock implements GurbaniAsr {}

class _MockPlayer extends Mock implements AudioPlayer {}

void main() {
  setUpAll(() {
    registerFallbackValue((double _) {});
    registerFallbackValue(Duration.zero);
    registerFallbackValue(DeviceFileSource('x'));
  });

  group(TrackingCubit, () {
    late _MockAsr asr;
    late _MockPlayer player;
    late GurbaniDatabase database;
    late StreamController<String> onText;

    setUp(() {
      asr = _MockAsr();
      player = _MockPlayer();
      database = openTestCorpus();
      onText = StreamController<String>.broadcast();
      when(() => asr.onText).thenAnswer((_) => onText.stream);
      when(() => asr.stop()).thenAnswer((_) async {});
      when(() => asr.dispose()).thenAnswer((_) async {});
      when(() => player.stop()).thenAnswer((_) async {});
      when(() => player.dispose()).thenAnswer((_) async {});
    });

    tearDown(() {
      database.dispose();
      return onText.close();
    });

    TrackingCubit build({Future<String?> Function()? pickPath}) =>
        TrackingCubit(
          database: database,
          asr: asr,
          player: player,
          pickPath: pickPath,
        );

    void micGranted() => when(() => asr.start()).thenAnswer((_) async => true);

    test('initial state is idle', () {
      expect(build().state, const TrackingState());
    });

    blocTest<TrackingCubit, TrackingState>(
      'mic granted → loadingModel then listening',
      setUp: micGranted,
      build: build,
      act: (c) => c.toggleMic(),
      expect: () => const [
        TrackingState(status: TrackingStatus.loadingModel),
        TrackingState(status: TrackingStatus.listening),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'mic denied → loadingModel then micDenied',
      setUp: () => when(() => asr.start()).thenAnswer((_) async => false),
      build: build,
      act: (c) => c.toggleMic(),
      expect: () => const [
        TrackingState(status: TrackingStatus.loadingModel),
        TrackingState(status: TrackingStatus.micDenied),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'toggleMic while listening stops and returns to idle',
      seed: () => const TrackingState(status: TrackingStatus.listening),
      build: build,
      act: (c) => c.toggleMic(),
      expect: () => const [TrackingState()],
      verify: (_) => verify(() => asr.stop()).called(1),
    );

    blocTest<TrackingCubit, TrackingState>(
      'a mic transcript discovers its line in the corpus',
      setUp: micGranted,
      build: build,
      act: (c) async {
        await c.toggleMic();
        onText.add(kLineB);
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2, // loadingModel, listening
      expect: () => [
        isA<TrackingState>()
            .having((s) => s.lastHeard, 'lastHeard', kLineB)
            .having((s) => s.verse?.gurmukhi, 'verse', kLineB)
            .having((s) => s.synced, 'synced', isTrue),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'a transcript matching nothing in the corpus shows no verse',
      setUp: micGranted,
      build: build,
      act: (c) async {
        await c.toggleMic();
        onText.add('ਕੁਝ ਵੀ ਨਹੀਂ ਮਿਲਦਾ ਇਥੇ');
        await Future<void>.delayed(Duration.zero);
      },
      skip: 2,
      expect: () => [
        isA<TrackingState>()
            .having((s) => s.verse, 'verse', isNull)
            .having((s) => s.synced, 'synced', isFalse),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'follows on to the next line even when the window is at a corpus edge',
      // Japji starts on ang 1, so its anchor window is clamped and the follower
      // sits permanently within edgeMargin of the low edge - the case where a
      // re-anchor fires on every single chunk.
      setUp: micGranted,
      build: build,
      act: (c) async {
        await c.toggleMic();
        for (final heard in [kLineA, kLineB]) {
          onText.add(heard);
          await Future<void>.delayed(Duration.zero);
        }
      },
      skip: 3, // loadingModel, listening, lock on A
      expect: () => [
        isA<TrackingState>()
            .having((s) => s.verse?.gurmukhi, 'verse', kLineB)
            .having((s) => s.synced, 'synced', isTrue),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'an invocation-only transcript never drags the tracker off the line',
      setUp: micGranted,
      build: build,
      act: (c) async {
        await c.toggleMic();
        onText.add(kLineB);
        await Future<void>.delayed(Duration.zero);
        onText.add('ਵਾਹਿਗੁਰੂ ਜੀ ਕਾ ਖਾਲਸਾ ਵਾਹਿਗੁਰੂ ਜੀ ਕੀ ਫਤਹਿ');
        await Future<void>.delayed(Duration.zero);
      },
      skip: 3, // loadingModel, listening, the kLineB lock
      expect: () => [
        isA<TrackingState>().having((s) => s.verse?.gurmukhi, 'verse', kLineB),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'undecodable file → transcribing then fileError',
      setUp: () => when(
        () => asr.recognizeWindows(any(), onProgress: any(named: 'onProgress')),
      ).thenAnswer((_) async => <AsrWindow>[]),
      build: build,
      act: (c) => c.trackFile('/nope.wav'),
      expect: () => const [
        TrackingState(status: TrackingStatus.transcribing),
        TrackingState(status: TrackingStatus.fileError),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'decodable file → transcribing then playing',
      setUp: () {
        when(
          () =>
              asr.recognizeWindows(any(), onProgress: any(named: 'onProgress')),
        ).thenAnswer(
          (_) async => const [
            (startMs: 0, endMs: 3000, text: kLineA),
            (startMs: 3000, endMs: 6000, text: kLineB),
          ],
        );
        when(
          () => player.onPositionChanged,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(
          () => player.onDurationChanged,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(
          () => player.onPlayerStateChanged,
        ).thenAnswer((_) => const Stream<PlayerState>.empty());
        when(() => player.play(any())).thenAnswer((_) async {});
      },
      build: build,
      act: (c) => c.trackFile('/ok.wav'),
      expect: () => const [
        TrackingState(status: TrackingStatus.transcribing),
        TrackingState(status: TrackingStatus.playing),
      ],
      verify: (_) => verify(() => player.play(any())).called(1),
    );

    blocTest<TrackingCubit, TrackingState>(
      'togglePlayPause pauses when playing',
      setUp: () => when(() => player.pause()).thenAnswer((_) async {}),
      seed: () => const TrackingState(status: TrackingStatus.playing),
      build: build,
      act: (c) => c.togglePlayPause(),
      expect: () => const <TrackingState>[],
      verify: (_) => verify(() => player.pause()).called(1),
    );

    blocTest<TrackingCubit, TrackingState>(
      'seek emits the new position',
      setUp: () => when(() => player.seek(any())).thenAnswer((_) async {}),
      seed: () => const TrackingState(status: TrackingStatus.playing),
      build: build,
      act: (c) => c.seek(const Duration(seconds: 5)),
      expect: () => const [
        TrackingState(
          status: TrackingStatus.playing,
          position: Duration(seconds: 5),
        ),
      ],
    );

    blocTest<TrackingCubit, TrackingState>(
      'pickFile with no selection does nothing',
      build: () => build(pickPath: () async => null),
      act: (c) => c.pickFile(),
      expect: () => const <TrackingState>[],
    );
  });
}
