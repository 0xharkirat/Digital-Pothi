import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/view/history_pane.dart';
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
    cubit = PresenterCubit(db, prefs)..search('ssnh');
    cubit.selectResult(cubit.state.results.first); // history: a
    cubit
      ..search('hsdb')
      ..selectResult(cubit.state.results.first); // history: [c, a]
  });

  tearDown(() async {
    await cubit.close();
    db.dispose();
  });

  Future<void> pumpPane(WidgetTester tester) => tester.pumpApp(
    BlocProvider.value(
      value: cubit,
      child: const Scaffold(body: HistoryPane()),
    ),
  );

  testWidgets('the close icon removes that entry without opening it', (
    tester,
  ) async {
    cubit.showBlank(); // shown line is now a quick-insert slide, not a/c
    await pumpPane(tester);
    expect(cubit.state.history, hasLength(2));

    // The delete on the ਸੋਚੈ (a) tile.
    final aRow = find
        .ancestor(of: find.textContaining('ਸੋਚੈ'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: aRow, matching: find.byIcon(Icons.close)),
    );
    await tester.pump();

    expect(cubit.state.history.map((e) => e.lineId), ['c']);
    expect(
      cubit.state.line?.id,
      'special',
      reason: 'deleting must not re-open the entry',
    );
  });

  testWidgets('the sort toggle flips newest/oldest order', (tester) async {
    await pumpPane(tester);
    // Newest-first: c (ਹੋਰ) sits above a (ਸੋਚੈ).
    expect(
      tester.getCenter(find.textContaining('ਹੋਰ')).dy,
      lessThan(tester.getCenter(find.textContaining('ਸੋਚੈ')).dy),
    );

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pump();

    // Oldest-first: a now sits above c.
    expect(
      tester.getCenter(find.textContaining('ਸੋਚੈ')).dy,
      lessThan(tester.getCenter(find.textContaining('ਹੋਰ')).dy),
    );
  });
}
