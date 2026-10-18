import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/view/search_pane.dart';
import 'package:gurbani_live/presenter/view/shabad_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_corpus.dart';

/// Every interactive surface must hover the click (hand) cursor, like STTM.
void main() {
  late GurbaniDatabase db;
  late PresenterCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    db = openTestCorpus();
    cubit = PresenterCubit(db, prefs);
  });

  tearDown(() async {
    await cubit.close();
    db.dispose();
  });

  Future<MouseCursor?> hoverCursor(WidgetTester tester, Finder f) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(tester.getCenter(f));
    await tester.pump();
    // TestGesture's default mouse device id is 1.
    final cursor = RendererBinding.instance.mouseTracker
        .debugDeviceActiveCursor(1);
    await gesture.removePointer();
    await tester.pump();
    return cursor;
  }

  testWidgets('search pane interactives hover the click cursor', (
    tester,
  ) async {
    await tester.pumpApp(
      RepositoryProvider.value(
        value: db,
        child: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: SearchPane()),
        ),
      ),
    );
    cubit.search('ssnh');
    await tester.pump();

    for (final f in [
      find.byKey(const Key('lang_en')),
      find.byKey(const Key('match_full')),
      find.byKey(const Key('filter_writer')),
      find.textContaining('Ang 4', findRichText: true), // result tile
    ]) {
      expect(
        await hoverCursor(tester, f),
        SystemMouseCursors.click,
        reason: '$f must show the hand cursor',
      );
    }
  });

  testWidgets('shabad rows + toolbar hover the click cursor', (tester) async {
    cubit
      ..search('ssnh')
      ..selectResult(cubit.state.results.first);
    await tester.pumpApp(
      BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: ShabadView()),
      ),
    );

    for (final f in [
      find.text('Next'), // toolbar TextButton
      find.widgetWithText(InkWell, kLineB), // a line row
    ]) {
      expect(
        await hoverCursor(tester, f),
        SystemMouseCursors.click,
        reason: '$f must show the hand cursor',
      );
    }
  });
}
