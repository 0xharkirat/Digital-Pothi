import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';
import 'package:gurbani_live/data/preferences.dart';
import 'package:gurbani_live/presenter/cubit/presenter_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_corpus.dart';

void main() {
  group(PresenterCubit, () {
    late GurbaniDatabase db;
    late PresenterCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      db = openTestCorpus();
      cubit = PresenterCubit(db, prefs);
    });

    tearDown(() {
      cubit.close();
      db.dispose();
    });

    test('search populates results; empty query clears them', () {
      cubit.search('ssnh');
      expect(cubit.state.results, isNotEmpty);
      expect(cubit.state.results.first.lineId, 'a');
      cubit.search('   ');
      expect(cubit.state.results, isEmpty);
    });

    test('switching mode re-runs the query', () {
      cubit
        ..search('ਸੋਚੈ')
        ..setMode(SearchMode.fullWordGurmukhi);
      expect(cubit.state.mode, SearchMode.fullWordGurmukhi);
      expect(cubit.state.results.first.lineId, 'a');
    });

    test('every search mode dispatches to the right query', () {
      // First letter (start vs anywhere): 'nhjs' is mid-run in line a.
      cubit
        ..setMode(SearchMode.firstLetterAnywhere)
        ..search('nhjs');
      expect(cubit.state.results.single.lineId, 'a');
      cubit.setMode(SearchMode.firstLetterStart);
      expect(cubit.state.results, isEmpty);

      // Full word English carries the matched translation.
      cubit
        ..setMode(SearchMode.fullWordEnglish)
        ..search('thinking');
      expect(cubit.state.results.single.lineId, 'a');
      expect(cubit.state.results.single.translation, startsWith('By thinking'));

      // Ang: numeric lists the page (SGGS-scoped); junk yields empty.
      cubit
        ..setMode(SearchMode.ang)
        ..search('4');
      expect(cubit.state.results.map((r) => r.lineId), ['a', 'b']);
      cubit.search('abc');
      expect(cubit.state.results, isEmpty);
      cubit.search('-4');
      expect(cubit.state.results, isEmpty);
    });

    test('filter changes re-run the active query immediately', () {
      cubit.search('ssnh'); // line a, writer 1
      expect(cubit.state.results, isNotEmpty);
      cubit.setWriterFilter(2);
      expect(cubit.state.results, isEmpty);
      cubit.setWriterFilter(0); // back to All
      expect(cubit.state.results.single.lineId, 'a');
      // Source filter scopes Ang.
      cubit
        ..setMode(SearchMode.ang)
        ..setSourceFilter(2)
        ..search('4');
      expect(cubit.state.results.single.lineId, 'd');
    });

    test('emptyStateText distinguishes prompt, no-results, and filters', () {
      expect(cubit.state.emptyStateText, contains('Type to search'));
      cubit.setMode(SearchMode.ang);
      expect(cubit.state.emptyStateText, contains('Ang number'));
      cubit
        ..setMode(SearchMode.firstLetterAnywhere)
        ..search('zzzz');
      expect(cubit.state.emptyStateText, 'No results');
      cubit.setWriterFilter(2);
      expect(cubit.state.emptyStateText, 'No results (filters active)');

      // Ang mode ignores writer/raag, so they must not be blamed - only an
      // active Source filter counts there.
      cubit
        ..setMode(SearchMode.ang)
        ..search('9999');
      expect(cubit.state.emptyStateText, 'No results');
      cubit.setSourceFilter(2);
      expect(cubit.state.emptyStateText, 'No results (filters active)');
      cubit.setSourceFilter(0);
    });

    test('selecting a result loads its shabad and shows the line', () {
      cubit.search('ssnh');
      cubit.selectResult(cubit.state.results.first);
      expect(cubit.state.shabad.map((v) => v.id), ['a', 'b']);
      expect(cubit.state.current, 0);
      expect(cubit.state.line?.id, 'a');
      expect(cubit.state.author, 'Guru Nanak Dev Ji');
      expect(cubit.state.section, 'Raag Tukhaari');
      expect(cubit.state.display.translations['en'], startsWith('By thinking'));
      expect(cubit.state.following, isFalse);
    });

    test('nextLine/prevLine move within the shabad and stop at the ends', () {
      cubit.search('ssnh');
      cubit.selectResult(cubit.state.results.first);
      cubit.nextLine();
      expect(cubit.state.line?.id, 'b');
      cubit.nextLine(); // already last - no move
      expect(cubit.state.current, 1);
      cubit.prevLine();
      expect(cubit.state.line?.id, 'a');
    });

    test('nextShabad / prevShabad step between shabads in reading order', () {
      cubit
        ..search('ssnh')
        ..selectResult(cubit.state.results.first); // shabad S1, lines a,b
      expect(cubit.state.shabad.map((v) => v.id), ['a', 'b']);

      cubit.nextShabad(); // -> S2
      expect(cubit.state.shabad.map((v) => v.id), ['c']);
      expect(cubit.state.current, 0);

      cubit.prevShabad(); // back to S1, opened at its first line
      expect(cubit.state.shabad.map((v) => v.id), ['a', 'b']);
      expect(cubit.state.line?.id, 'a');
    });

    test('the tracker drives the line only while following is on', () {
      final verseB = db.shabadLines('S1').last; // line 'b'

      // Not following: the tracker verse is ignored.
      cubit.showTrackerVerse(verseB);
      expect(cubit.state.line, isNull);

      // Following: it shows the tracked line in context.
      cubit.setFollowing(on: true);
      cubit.showTrackerVerse(verseB);
      expect(cubit.state.line?.id, 'b');
      expect(cubit.state.following, isTrue);

      // Manual selection takes over and turns following off.
      cubit.showLine(0);
      expect(cubit.state.line?.id, 'a');
      expect(cubit.state.following, isFalse);
    });

    test('settings + history persist across cubit instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      final first = PresenterCubit(db, prefs)
        ..setBaniLength(BaniLength.long)
        ..toggleBaniNames()
        ..toggleLarivaar()
        ..bumpFontScale(0.2)
        ..search('ssnh');
      first.selectResult(first.state.results.first); // records history
      await first.close();

      final second = PresenterCubit(db, prefs); // same on-device store
      expect(second.state.baniLength, BaniLength.long);
      expect(second.state.englishBaniNames, isTrue);
      expect(second.state.larivaar, isTrue);
      expect(second.state.fontScale, closeTo(1.2, 1e-9));
      expect(second.state.history.map((e) => e.lineId), contains('a'));
      await second.close();
    });

    test('favorites: star, persist, reopen, remove', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      final c = PresenterCubit(db, prefs)..search('ssnh');
      c.selectResult(c.state.results.first); // shabad line 'a'
      expect(c.state.canFavorite, isTrue);
      c.toggleFavorite();
      expect(c.state.isFavorite, isTrue);
      expect(c.state.favorites.map((f) => f.lineId), ['a']);
      await c.close();

      final reopened = PresenterCubit(db, prefs); // same store
      expect(reopened.state.favorites.map((f) => f.lineId), ['a']);
      reopened.removeFavorite(reopened.state.favorites.first);
      expect(reopened.state.favorites, isEmpty);
      await reopened.close();
    });

    test('display background is selectable', () {
      expect(cubit.state.displayBg, DisplayBg.navy);
      cubit.setDisplayBg(DisplayBg.black);
      expect(cubit.state.displayBg, DisplayBg.black);
    });

    test('history records shown shabads, most recent first, deduped', () {
      cubit
        ..search('ssnh')
        ..selectResult(cubit.state.results.first); // line 'a'
      expect(cubit.state.history.map((e) => e.lineId), ['a']);

      cubit
        ..search('hsdb')
        ..selectResult(cubit.state.results.first); // line 'c', other shabad
      expect(cubit.state.history.map((e) => e.lineId), ['c', 'a']);

      // Re-showing 'a' moves it to the front instead of duplicating.
      cubit
        ..search('ssnh')
        ..selectResult(cubit.state.results.first);
      expect(cubit.state.history.map((e) => e.lineId), ['a', 'c']);
      expect(cubit.state.history.first.author, 'Guru Nanak Dev Ji');
      expect(cubit.state.history.first.page, 4);
    });

    test('openHistory re-opens a past shabad at its line', () {
      cubit
        ..search('hsdb')
        ..selectResult(cubit.state.results.first); // 'c'
      cubit.showWaheguru(); // move away to a quick-insert slide
      expect(cubit.state.line?.id, 'special');
      cubit.openHistory(cubit.state.history.first);
      expect(cubit.state.line?.id, 'c');
    });

    test('showBani loads a bani from the self-contained bani DB', () {
      final banis = db.banis();
      expect(banis.map((b) => b.gurmukhi), contains('ਜਪੁਜੀ ਸਾਹਿਬ'));
      cubit.showBani(banis.first); // bani 1
      expect(cubit.state.shabad.length, 2);
      expect(cubit.state.shabad.first.gurmukhi, 'ਜਪੁ ਲਾਈਨ');
      expect(cubit.state.author, 'ਜਪੁਜੀ ਸਾਹਿਬ');
      expect(cubit.state.section, 'Nitnem');
      expect(cubit.state.display.translations['en'], 'Jap line one');
      expect(cubit.state.history.first.author, 'ਜਪੁਜੀ ਸਾਹਿਬ');
    });

    test('bani name language toggles between Gurmukhi and English', () {
      final japji = db.banis().first;
      cubit.showBani(japji);
      expect(cubit.state.author, 'ਜਪੁਜੀ ਸਾਹਿਬ'); // Gurmukhi by default
      cubit
        ..toggleBaniNames()
        ..showBani(japji);
      expect(cubit.state.author, 'Japji Sahib');
    });

    test('bani length filters which lines show, and re-loads on change', () {
      final rehras = db.banis().firstWhere((b) => b.hasLengths);
      cubit.showBani(rehras); // default short: only the first line
      expect(cubit.state.shabad.length, 1);
      cubit.setBaniLength(BaniLength.extralong); // reloads: both lines
      expect(cubit.state.shabad.length, 2);
      cubit.setBaniLength(BaniLength.short);
      expect(cubit.state.shabad.length, 1);
    });

    test('quick-insert shows a one-line slide and stays out of history', () {
      cubit.showWaheguru();
      expect(cubit.state.line?.gurmukhi, 'ਵਾਹਿਗੁਰੂ');
      expect(cubit.state.shabad, hasLength(1));
      expect(cubit.state.following, isFalse);
      expect(cubit.state.history, isEmpty);

      cubit.showBlank();
      expect(cubit.state.line?.gurmukhi, '');
    });

    test('display options toggle and font scale clamps', () {
      cubit.toggleLarivaar();
      expect(cubit.state.larivaar, isTrue);
      expect(cubit.state.vishraam, isTrue); // default on
      cubit.toggleVishraam();
      expect(cubit.state.vishraam, isFalse);

      cubit.bumpFontScale(0.3);
      expect(cubit.state.fontScale, closeTo(1.3, 1e-9));
      cubit.bumpFontScale(1); // clamps at 1.5
      expect(cubit.state.fontScale, 1.5);
      cubit.bumpFontScale(-5); // clamps at 0.7
      expect(cubit.state.fontScale, 0.7);
    });
  });
}
