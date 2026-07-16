import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:gurbani_live/presenter/view/presenter_keyboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_corpus.dart';

void main() {
  testWidgets('arrow keys move the line, esc blanks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs)..search('ssnh');
    cubit.selectResult(cubit.state.results.first); // shabad a,b at line 0
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const PresenterKeyboard(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cubit.state.current, 1, reason: 'arrow down -> next line');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(cubit.state.current, 0, reason: 'arrow up -> previous line');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(cubit.state.line?.id, 'special', reason: 'esc -> blank slide');
  });

  testWidgets('space runs the intelligent spacebar, not plain next', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs)
      ..openHistory(
        const HistoryEntry(
          lineId: 'k4', // the kirtan shabad's rahao line - home
          gurmukhi: '',
          author: '',
          section: '',
          page: 100,
        ),
      );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const PresenterKeyboard(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(
      cubit.state.current,
      2,
      reason: 'space resumes past the headers - nextLine would land on 5',
    );
  });

  testWidgets('typing in a text field keeps its spaces and arrows', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs)..search('ssnh');
    cubit.selectResult(cubit.state.results.first);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const PresenterKeyboard(
            child: Material(child: TextField(key: Key('query'))),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('query')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(cubit.state.current, 0, reason: 'space must not advance the line');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(cubit.state.current, 0, reason: 'arrows stay with the caret');
  });
}
