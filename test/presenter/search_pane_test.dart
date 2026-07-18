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

    // The match types are one-of, so they render as a radio group - picking
    // any one is a single tap from anywhere (the old checkbox pair needed an
    // uncheck-first dance).
    await tester.tap(find.byKey(const Key('match_start')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterStart);

    await tester.tap(find.byKey(const Key('match_full')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.fullWordGurmukhi);
    expect(find.text('Full words in Gurmukhi'), findsOneWidget);

    // The language radio picks the script only; the match radio is stable.
    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.fullWordEnglish);
    expect(find.text('Search English translations'), findsOneWidget);

    // English + first letters = ROMANIZED first letters (STTM's
    // FIRST_LETTERS_ENGLISH), not translation search.
    await tester.tap(find.byKey(const Key('match_anywhere')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);
    expect(find.text('Romanized first letters - mkjt'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lang_gr')));
    await tester.pump();
    expect(cubit.state.mode, SearchMode.firstLetterAnywhere);
    expect(find.text('First letters - sdvsd or ਸਦਵਸਦ'), findsOneWidget);
  });

  testWidgets('the Ang box takes over and disables Writer/Raag', (
    tester,
  ) async {
    await pumpPane(tester);
    await tester.enterText(find.byKey(const Key('ang_field')), '4');
    await tester.pump();
    expect(cubit.state.mode, SearchMode.ang);
    expect(cubit.state.results.map((r) => r.lineId), ['a', 'b']);

    InkWell filter(String key) => tester.widget<InkWell>(
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell)),
    );
    expect(filter('filter_writer').onTap, isNull); // disabled
    expect(filter('filter_raag').onTap, isNull); // disabled
    expect(filter('filter_source').onTap, isNotNull); // scopes the Ang

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
    await tester.tap(find.byKey(const Key('match_full')));
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

  testWidgets('on-screen Gurmukhi keyboard types, deletes, hides for English', (
    tester,
  ) async {
    await pumpPane(tester);
    // Closed until toggled.
    expect(find.byKey(const Key('gurmukhi_keyboard')), findsNothing);
    await tester.tap(find.byKey(const Key('kb_toggle')));
    await tester.pump();
    expect(find.byKey(const Key('gurmukhi_keyboard')), findsOneWidget);

    Future<void> key(String ch) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('gurmukhi_keyboard')),
          matching: find.text(ch),
        ),
      );
      await tester.pump();
    }

    // ਸਸਨਹ = line a's first letters (anywhere), typed on the keyboard.
    await key('ਸ');
    await key('ਸ');
    await key('ਨ');
    await key('ਹ');
    expect(cubit.state.query, 'ਸਸਨਹ');
    expect(cubit.state.results.single.lineId, 'a');

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('gurmukhi_keyboard')),
        matching: find.byIcon(Icons.backspace_outlined),
      ),
    );
    await tester.pump();
    expect(cubit.state.query, 'ਸਸਨ');

    // English input is roman: no Gurmukhi keyboard, no toggle.
    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.pump();
    expect(find.byKey(const Key('gurmukhi_keyboard')), findsNothing);
    expect(find.byKey(const Key('kb_toggle')), findsNothing);
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
