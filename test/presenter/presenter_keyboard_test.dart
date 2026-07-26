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

  testWidgets('Ctrl+C copies the active verse and shows a toast', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs)..search('ssnh');
    cubit.selectResult(cubit.state.results.first); // line 'a'
    addTearDown(cubit.close);

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const PresenterKeyboard(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(copied, [kLineA], reason: 'the clean Gurmukhi of the active line');
    expect(find.text('Verse copied to clipboard'), findsOneWidget);
  });

  testWidgets('Ctrl+C in the search box does not copy the verse', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs)..search('ssnh');
    cubit.selectResult(cubit.state.results.first);
    addTearDown(cubit.close);

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      copied,
      isNot(contains(kLineA)),
      reason: 'text-field copy must not be hijacked by the verse copy',
    );
  });

  testWidgets('Ctrl+digit opens quick-insert slides', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs);
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

    Future<void> chord(LogicalKeyboardKey k) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(k);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    await chord(LogicalKeyboardKey.digit1);
    expect(cubit.state.line?.gurmukhi, 'ਵਾਹਿਗੁਰੂ', reason: 'Ctrl+1 = Waheguru');
    await chord(LogicalKeyboardKey.digit3);
    expect(cubit.state.line?.gurmukhi, '', reason: 'Ctrl+3 = Blank');
  });

  testWidgets('Ctrl+slash requests focus on the search field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    final db = openTestCorpus();
    addTearDown(db.dispose);
    final cubit = PresenterCubit(db, prefs);
    addTearDown(cubit.close);

    var focusRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: PresenterKeyboard(
            onFocusSearch: () => focusRequested = true,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(focusRequested, isTrue);
  });

  testWidgets('Ctrl+digit chords fire even while the search box is focused', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      cubit.state.line?.gurmukhi,
      'ਵਾਹਿਗੁਰੂ',
      reason: 'a quick-insert chord bypasses the typing guard, like STTM',
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
