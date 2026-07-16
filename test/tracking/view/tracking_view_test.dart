import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/engine/corpus.dart';
import 'package:gurbani_live/tracking/cubit/tracking_cubit.dart';
import 'package:gurbani_live/tracking/view/tracking_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/pump_app.dart';

class _MockTrackingCubit extends MockCubit<TrackingState>
    implements TrackingCubit {}

void main() {
  late TrackingCubit cubit;

  setUp(() => cubit = _MockTrackingCubit());

  Widget subject() =>
      BlocProvider.value(value: cubit, child: const TrackingView());

  void seed(TrackingState state) => when(() => cubit.state).thenReturn(state);

  group(TrackingView, () {
    testWidgets('shows the mic icon and idle prompt when idle', (tester) async {
      seed(const TrackingState());
      await tester.pumpApp(subject());
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('Tap the mic, or open an audio file'), findsOneWidget);
    });

    testWidgets('swaps to the stop icon while listening', (tester) async {
      seed(const TrackingState(status: TrackingStatus.listening));
      await tester.pumpApp(subject());
      expect(find.byIcon(Icons.stop), findsOneWidget);
    });

    testWidgets('disables open-file while transcribing', (tester) async {
      seed(const TrackingState(status: TrackingStatus.transcribing));
      await tester.pumpApp(subject());
      final button = tester.widget<IconButton>(
        find.byKey(const Key('open_file')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows transport controls once audio is loaded', (
      tester,
    ) async {
      seed(
        const TrackingState(
          status: TrackingStatus.playing,
          duration: Duration(minutes: 1),
        ),
      );
      await tester.pumpApp(subject());
      expect(find.byKey(const Key('play_pause')), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('renders the current verse', (tester) async {
      seed(
        const TrackingState(
          status: TrackingStatus.playing,
          verse: Verse(
            id: '1',
            seq: 3,
            gurmukhi: 'ਹੁਕਮੀ ਹੁਕਮੁ',
            normalized: '',
            page: 2,
          ),
        ),
      );
      await tester.pumpApp(subject());
      expect(find.text('ਹੁਕਮੀ ਹੁਕਮੁ'), findsOneWidget);
      expect(find.text('Ang 2'), findsOneWidget);
    });
  });
}
