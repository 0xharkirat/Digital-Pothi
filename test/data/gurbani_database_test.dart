import 'package:flutter_test/flutter_test.dart';
import 'package:gurbani_live/data/gurbani_database.dart';

import '../helpers/test_corpus.dart';

void main() {
  group(GurbaniDatabase, () {
    late GurbaniDatabase gurbani;

    setUp(() => gurbani = openTestCorpus());
    tearDown(() => gurbani.dispose());

    test(
      'baniLines returns a bani in reading order, seq = global order_id',
      () {
        final lines = gurbani.baniLines(1);
        // Not 1,2 - seq is the corpus-wide order_id, so a sliding window never
        // renumbers a line out from under the follower.
        expect(lines.map((v) => v.seq), [10, 20]);
        expect(lines.first.gurmukhi, kLineA);
        expect(lines.last.gurmukhi, kLineB);
        expect(lines.first.normalized, isNotEmpty);
        expect(lines.first.page, 4);
      },
    );

    test('an unknown bani returns no lines', () {
      expect(gurbani.baniLines(999), isEmpty);
    });

    test('shabadLines returns that shabad only, in order', () {
      expect(gurbani.shabadLines('S1').map((v) => v.gurmukhi), [
        kLineA,
        kLineB,
      ]);
      expect(gurbani.shabadLines('S2').single.gurmukhi, kLineC);
    });

    test('windowAround spans the radius and excludes what is outside it', () {
      expect(gurbani.windowAround(20).map((v) => v.seq), [10, 20, 30]);
      // Radius 5 around order_id 10 reaches 5..15 - only the one line.
      expect(gurbani.windowAround(10, radius: 5).map((v) => v.seq), [10]);
    });

    test(
      'locate finds the right line and its anchor despite misheard words',
      () {
        // 'ਉਤਰੇ' and 'ਬਨਾ' are wrong (real line has ਉਤਰੀ / ਬੰਨਾ) - the OR-match
        // survives it.
        final hits = gurbani.locate('ਭੁਖਿਆ ਭੁਖ ਨ ਉਤਰੇ ਜੈ ਬਨਾ ਪੁਰੀਆ ਭਾਰ');
        expect(hits, isNotEmpty);
        expect(hits.first.lineId, 'b');
        expect(hits.first.shabadId, 'S1');
        expect(hits.first.orderId, 20); // where to centre the window
        expect(hits.first.score, greaterThan(0.3));
      },
    );

    test('locate returns nothing for an empty or too-short transcript', () {
      expect(gurbani.locate(''), isEmpty);
      expect(gurbani.locate('ਨ'), isEmpty);
    });

    test('displayFor returns translations + transliterations for a line', () {
      final d = gurbani.displayFor('a');
      expect(d.translations['en'], startsWith('By thinking'));
      expect(d.translations['pa'], isNotEmpty);
      expect(d.transliterations['roman'], 'sochai soch na hovee');
      expect(d.transliterations['devnagri'], startsWith('सोचै'));
    });

    test('displayFor returns empty maps for a line with no display data', () {
      final d = gurbani.displayFor('c');
      expect(d.translations, isEmpty);
      expect(d.transliterations, isEmpty);
    });

    test('first-letter search (roman) finds the line with author + raag', () {
      final hits = gurbani.searchFirstLetters('ssnh');
      expect(hits.single.lineId, 'a');
      expect(hits.single.author, 'Guru Nanak Dev Ji');
      expect(hits.single.section, 'Raag Tukhaari');
      expect(hits.single.transliteration, 'sochai soch na hovee');
      expect(hits.single.page, 4);
    });

    test('first-letter search auto-detects Gurmukhi input', () {
      expect(gurbani.searchFirstLetters('ਸਸਨ').single.lineId, 'a');
    });

    test('first-letter "anywhere" matches mid-run; "start" does not', () {
      expect(gurbani.searchFirstLetters('nhjs').single.lineId, 'a');
      expect(gurbani.searchFirstLetters('nhjs', anywhere: false), isEmpty);
    });

    test('full-word search matches Gurmukhi text and ranks by relevance', () {
      final hits = gurbani.searchFullText('ਸੋਚੈ ਸੋਚਿ');
      expect(hits.first.lineId, 'a');
      expect(hits.first.author, 'Guru Nanak Dev Ji');
    });

    test('search returns nothing for empty input', () {
      expect(gurbani.searchFirstLetters('  '), isEmpty);
      expect(gurbani.searchFullText(''), isEmpty);
      expect(gurbani.searchEnglish('   '), isEmpty);
    });

    test('English search matches all words and carries the translation', () {
      // 'a' has en "By thinking, He cannot be reduced to thought".
      final hits = gurbani.searchEnglish('thinking thought');
      expect(hits.single.lineId, 'a');
      expect(hits.single.translation, startsWith('By thinking'));
      // Other modes leave translation empty - no extra join paid.
      expect(gurbani.searchFirstLetters('ssnh').single.translation, isEmpty);
    });

    test('English search treats LIKE wildcards literally', () {
      // Unescaped, LIKE '%_%' matches any 1+ char text - i.e. everything.
      expect(gurbani.searchEnglish('_'), isEmpty);
      expect(gurbani.searchEnglish('%'), isEmpty);
      expect(gurbani.searchEnglish('think%ing'), isEmpty);
    });

    test(
      'Ang search is source-scoped: SGGS by default, collision stays out',
      () {
        // Page 4 exists in source 1 (lines a,b) AND source 2 (line d).
        expect(gurbani.searchAng(4).map((r) => r.lineId), ['a', 'b']);
        expect(gurbani.searchAng(4, sourceId: 2).single.lineId, 'd');
        expect(gurbani.searchAng(0), isEmpty);
        expect(gurbani.searchAng(-3), isEmpty);
        expect(gurbani.searchAng(9999), isEmpty);
      },
    );

    test('filters narrow every search mode', () {
      // Writer filter: line 'a' is writer 1; writer 2 excludes it.
      expect(gurbani.searchFirstLetters('ssnh', writerId: 1), isNotEmpty);
      expect(gurbani.searchFirstLetters('ssnh', writerId: 2), isEmpty);
      // Section filter on full-word.
      expect(gurbani.searchFullText('ਸੋਚੈ ਸੋਚਿ', sectionId: 1), isNotEmpty);
      expect(gurbani.searchFullText('ਸੋਚੈ ਸੋਚਿ', sectionId: 2), isEmpty);
      // Source filter on first-letter: 'd' is in source 2 only.
      expect(
        gurbani.searchFirstLetters('dtpc', sourceId: 2).single.lineId,
        'd',
      );
      expect(gurbani.searchFirstLetters('dtpc', sourceId: 1), isEmpty);
      // English + source filter: only SGGS has translations in the fixture.
      expect(gurbani.searchEnglish('thinking', sourceId: 2), isEmpty);
    });

    test('filter option lists come from the corpus', () {
      expect(gurbani.writers().map((o) => o.name), [
        'Guru Arjan Dev Ji',
        'Guru Nanak Dev Ji',
      ]); // alphabetical
      expect(gurbani.sections(), hasLength(2));
      final sources = gurbani.sources();
      expect(sources.first.id, 1); // SGGS first (id order)
      expect(sources.first.name, 'Sri Guru Granth Sahib Ji');
    });
  });
}
