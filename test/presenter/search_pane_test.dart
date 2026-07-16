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

  Future<void> pickMode(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('search_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('hint follows the mode and Ang disables Writer/Raag', (
    tester,
  ) async {
    await pumpPane(tester);
    expect(find.text('First letters - sdvsd or ਸਦਵਸਦ'), findsOneWidget);

    await pickMode(tester, 'Ang');
    expect(
      find.text('Ang number (Sri Guru Granth Sahib by default)'),
      findsOneWidget,
    );
    DropdownButtonFormField<int> field(String key) =>
        tester.widget<DropdownButtonFormField<int>>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(DropdownButtonFormField<int>),
          ),
        );
    expect(field('filter_writer').onChanged, isNull); // disabled
    expect(field('filter_raag').onChanged, isNull); // disabled
    expect(field('filter_source').onChanged, isNotNull); // scopes the Ang
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
    await pickMode(tester, 'Full word (English)');
    await tester.enterText(find.byKey(const Key('search_field')), 'thinking');
    await tester.pump();
    expect(find.textContaining('By thinking'), findsOneWidget);
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
