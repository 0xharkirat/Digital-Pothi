import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/view/search_pane.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_corpus.dart';

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

  Future<void> pumpPane(WidgetTester tester) => tester.pumpApp(
    RepositoryProvider.value(
      value: db,
      child: BlocProvider.value(
        value: cubit,
        child: const Scaffold(body: SearchPane()),
      ),
    ),
  );

  testWidgets('toggles map onto the search modes (STTM header model)', (
    tester,
  ) async {
    await pumpPane(tester);
    // Default: Gurmukhi first-letter anywhere.
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);
    expect(find.text('First letters - sdvsd or ਸਦਵਸਦ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('opt_anywhere')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterStart);

    await tester.tap(find.byKey(const Key('opt_full_word')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.fullWordGurmukhi);
    expect(find.text('Full words in Gurmukhi'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.fullWordEnglish);
    expect(find.text('Search English translations'), findsOneWidget);

    // Back to Gurmukhi: full-word unlocks off (STTM resets to first letters);
    // the Anywhere checkbox keeps its earlier unchecked state.
    await tester.tap(find.byKey(const Key('lang_gr')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterStart);

    await tester.tap(find.byKey(const Key('opt_anywhere')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);
  });

  testWidgets('the Ang box takes over and disables Writer/Raag', (
    tester,
  ) async {
    await pumpPane(tester);
    await tester.enterText(find.byKey(const Key('ang_field')), '4');
    await tester.pump();
    expect(cubit.state.mode, SearchMode.ang);
    expect(cubit.state.results.map((r) => r.lineId), ['a', 'b']);

    PopupMenuButton<int> filter(String key) =>
        tester.widget<PopupMenuButton<int>>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(PopupMenuButton<int>),
          ),
        );
    expect(filter('filter_writer').enabled, isFalse);
    expect(filter('filter_raag').enabled, isFalse);
    expect(filter('filter_source').enabled, isTrue); // scopes the Ang

    // Clearing the box falls back to the toggles' mode + main query.
    await tester.enterText(find.byKey(const Key('ang_field')), '');
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);

    // Typing in the main box also takes over from the Ang box.
    await tester.enterText(find.byKey(const Key('ang_field')), '4');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('search_field')), 'ssnh');
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);
    expect(cubit.state.results.single.lineId, 'a');
    expect(find.byKey(const Key('ang_field')), findsOneWidget);
  });

  testWidgets('empty states: prompt, no results, filters active', (
    tester,
  ) async {
    await pumpPane(tester);
    expect(find.text('Type to search the whole corpus'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search_field')), 'zzzz');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);

    cubit.setWriterFilter(2);
    await tester.pump();
    expect(find.text('No results (filters active)'), findsOneWidget);
  });

  testWidgets('English mode shows the matched translation on the tile', (
    tester,
  ) async {
    await pumpPane(tester);
    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('search_field')), 'thinking');
    await tester.pump();
    expect(find.textContaining('By thinking'), findsOneWidget);
  });

  testWidgets('footer legend shows the sources present and the count', (
    tester,
  ) async {
    await pumpPane(tester);
    // 'dtpc' hits the Dasam line only (source 2).
    await tester.enterText(find.byKey(const Key('search_field')), 'dtpc');
    await tester.pump();
    expect(find.text('1 result'), findsOneWidget);
    expect(find.text('Sri Dasam Granth'), findsOneWidget);
    expect(find.text('Sri Guru Granth Sahib Ji'), findsNothing);
  });

  testWidgets('Enter opens the first result', (tester) async {
    await pumpPane(tester);
    await tester.enterText(find.byKey(const Key('search_field')), 'ssnh');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(cubit.state.line?.id, 'a'); // shabad opened at the searched line
  });
}
