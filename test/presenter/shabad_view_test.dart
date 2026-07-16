import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/view/shabad_view.dart';
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
    cubit = PresenterCubit(db, prefs)
      ..openHistory(
        const HistoryEntry(
          lineId: 'k4', // kirtan shabad opened at its rahao line
          gurmukhi: '',
          author: '',
          section: '',
          page: 100,
        ),
      );
  });

  tearDown(() async {
    await cubit.close();
    db.dispose();
  });

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    BlocProvider.value(
      value: cubit,
      child: const Scaffold(body: ShabadView()),
    ),
  );

  testWidgets('badges the rahao line and fills home on the opened line', (
    tester,
  ) async {
    await pumpView(tester);
    // The chip is its own exact-text widget; the line's full text differs.
    expect(find.text('ਰਹਾਉ'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    // The filled icon sits on the same row as the rahao chip (home = k4).
    expect(
      find.ancestor(
        of: find.byIcon(Icons.home),
        matching: find.widgetWithText(InkWell, 'ਰਹਾਉ'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row home icon repaints the fill onto that row', (
    tester,
  ) async {
    await pumpView(tester);
    // Re-home to the first couplet line (index 2): tap ITS outlined icon.
    await tester.tap(find.byIcon(Icons.home_outlined).at(2));
    await tester.pump();

    expect(cubit.state.homeIndex, 2);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.home),
        matching: find.widgetWithText(InkWell, 'ਪਹਿਲੀ ਅੰਤਰਾ ਤੁਕ ਇਕ ॥'),
      ),
      findsOneWidget,
      reason: 'the fill must MOVE to the tapped row, not just update state',
    );
  });

  testWidgets('banis show no home affordance', (tester) async {
    cubit.showBani(db.banis().first);
    await pumpView(tester);
    expect(find.byIcon(Icons.home), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });
}
