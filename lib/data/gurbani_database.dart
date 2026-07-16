import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../engine/corpus.dart';
import '../engine/normalizer.dart';
import '../engine/similarity.dart';

/// A candidate answer to "where in the corpus is this transcript?". Carries the
/// storage identity (shabad, global order) so [Verse] doesn't have to - it stays
/// a display model.
class LocateHit {
  const LocateHit({
    required this.lineId,
    required this.shabadId,
    required this.orderId,
    required this.gurmukhi,
    required this.page,
    required this.score,
  });

  final String lineId;
  final String shabadId;

  /// Global reading order - the anchor point for a window.
  final int orderId;
  final String gurmukhi;
  final int page;
  final double score;
}

/// Read-only on-device Gurbani corpus (ShabadOS SQLite, 141k lines, all
/// sources). The DB does the wide search; the follower only ever scans the small
/// slice it hands back.
///
/// Queries are synchronous (package:sqlite3), so callers never await them.
/// `Verse.normalized` is produced by the Dart [normalize] here, so the scorer
/// never depends on the DB's own tokenization.
/// A line's secondary text for the presenter: translations keyed by language
/// code (`en`, `pa`) and transliterations keyed by script (`roman`, `devnagri`).
/// The [Verse] stays a pure Gurmukhi model; this is fetched on demand for the
/// one line on screen, not carried on every line the tracker scans.
class LineDisplay {
  const LineDisplay({
    required this.translations,
    required this.transliterations,
  });

  final Map<String, String> translations;
  final Map<String, String> transliterations;

  static const empty = LineDisplay(translations: {}, transliterations: {});
}

/// A hit for the presenter's search box: the line plus what the results list
/// shows - ang, a roman transliteration preview, and the shabad's author + raag.
/// [translation] is only populated by [GurbaniDatabase.searchEnglish], so an
/// English hit can show why it matched; other modes leave it empty.
class SearchResult {
  const SearchResult({
    required this.lineId,
    required this.shabadId,
    required this.orderId,
    required this.gurmukhi,
    required this.transliteration,
    required this.page,
    required this.author,
    required this.section,
    this.translation = '',
    this.sourceId = 0,
  });

  final String lineId;
  final String shabadId;
  final int orderId;
  final String gurmukhi;
  final String transliteration;
  final int page;
  final String author; // writer, e.g. "Guru Nanak Dev Ji"
  final String section; // raag / bani division, e.g. "Raag Tukhaari"
  final String translation; // English, searchEnglish results only
  final int sourceId; // corpus `sources` id - drives the result accent colour
}

/// Search methods cap their results here (Ang search is uncapped - a page is
/// a page). The view uses it to tell a truncated list from a complete one.
const kSearchLimit = 40;

/// One row for a search filter dropdown (writers / raags / sources).
class FilterOption {
  const FilterOption({required this.id, required this.name});

  final int id;
  final String name;
}

/// STTM's four bani-length tiers, mapped from BaniDB's per-verse flags
/// (short=SGPC, medium, long=Taksal, extralong=BuddhaDal).
enum BaniLength { short, medium, long, extralong }

/// One entry in the Sundar Gutka bani list (Japji, Jaap, Rehras, ...), sourced
/// from BaniDB. [hasLengths] is true for the banis whose length tiers differ
/// (Rehras, Anand, ...), so the length picker only matters for those.
class Bani {
  const Bani({
    required this.id,
    required this.group,
    required this.gurmukhi,
    required this.roman,
    required this.english,
    this.hasLengths = false,
  });

  final int id;
  final String group; // 'nitnem' | 'popular' | 'other'
  final String gurmukhi; // Unicode bani name, e.g. ਰਹਿਰਾਸ ਸਾਹਿਬ
  final String roman;
  final String english; // e.g. "Rehras Sahib"
  final bool hasLengths;
}

/// A bani's line: its own text carried inline (the Sundar Gutka DB is
/// self-contained), plus the resolved [display] for the translations pane.
class BaniLine {
  const BaniLine({required this.verse, required this.display});

  final Verse verse;
  final LineDisplay display;
}

/// A shabad's lines plus its author + raag - the context the presenter shows
/// around a line, whether it was searched for or found by the tracker.
class ShabadContext {
  const ShabadContext({
    required this.lines,
    required this.author,
    required this.section,
  });

  final List<Verse> lines;
  final String author;
  final String section;
}

class GurbaniDatabase {
  GurbaniDatabase._(this._db, this._sg);

  /// Wrap already-open databases (in-memory, in tests). The Sundar Gutka handle
  /// defaults to the same DB so one fixture can hold both schemas.
  factory GurbaniDatabase.forTesting(Database db, [Database? sg]) =>
      GurbaniDatabase._(db, sg ?? db);

  final Database _db;
  final Database _sg; // self-contained Sundar Gutka DB (banis + length flags)

  static const _asset = 'assets/corpus/gurbani.sqlite';
  static const _sgAsset = 'assets/corpus/sundar_gutka.sqlite';
  static const _version = '6'; // bump to re-copy (6: Anand Bhog order + Salok)

  /// Copy the bundled DBs to a readable path once (atomically), then open them.
  /// Throws on failure; the caller surfaces a corpus-error screen.
  static Future<GurbaniDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final stamp = File('${dir.path}/gurbani.version');
    final fresh = !stamp.existsSync() || stamp.readAsStringSync() != _version;

    final corpus = await _ensure(_asset, '${dir.path}/gurbani.sqlite', fresh);
    final sg = await _ensure(
      _sgAsset,
      '${dir.path}/sundar_gutka.sqlite',
      fresh,
    );
    if (fresh) await stamp.writeAsString(_version);

    return GurbaniDatabase._(
      sqlite3.open(corpus, mode: OpenMode.readOnly),
      sqlite3.open(sg, mode: OpenMode.readOnly),
    );
  }

  /// Copy a bundled asset to [path] when the version changed or it's missing.
  static Future<String> _ensure(String asset, String path, bool fresh) async {
    if (fresh || !File(path).existsSync()) {
      final data = await rootBundle.load(asset);
      final tmp = File('$path.tmp');
      await tmp.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await tmp.rename(
        path,
      ); // atomic: a half-written temp never becomes the DB
    }
    return path;
  }

  static const _cols =
      'SELECT l.id, l.gurmukhi_uni AS g, l.source_page AS page, '
      'l.order_id AS ord, l.type_id AS type, l.source_line AS sline ';

  /// The Sundar Gutka bani list (from BaniDB), in BaniDB id order - the same
  /// order STTM lists them (the corpus-bridged Anand Bhog sorts to the end).
  List<Bani> banis() => [
    for (final r in _sg.select(
      'SELECT id, grp, gurmukhi, roman, english, has_lengths FROM sg_banis '
      'ORDER BY id',
    ))
      Bani(
        id: r['id'] as int,
        group: (r['grp'] as String?) ?? 'other',
        gurmukhi: (r['gurmukhi'] as String?) ?? '',
        roman: (r['roman'] as String?) ?? '',
        english: (r['english'] as String?) ?? '',
        hasLengths: (r['has_lengths'] as int? ?? 0) == 1,
      ),
  ];

  static const _lenCol = {
    BaniLength.short: 'len_short',
    BaniLength.medium: 'len_medium',
    BaniLength.long: 'len_long',
    BaniLength.extralong: 'len_extralong',
  };

  /// A bani's lines at the chosen [length]. Self-contained: each line carries
  /// its own text + translations, so no cross-DB line-id lookup is needed. The
  /// length column name comes from a fixed enum map, never user input.
  List<BaniLine> sgBaniLines(int baniId, BaniLength length) {
    final rows = _sg.select(
      'SELECT seq, gurmukhi, roman, english, punjabi, page FROM sg_lines '
      'WHERE bani_id = ? AND ${_lenCol[length]} = 1 ORDER BY seq',
      [baniId],
    );
    return [
      for (final r in rows)
        BaniLine(
          verse: Verse(
            id: 'sg:$baniId:${r['seq']}',
            seq: r['seq'] as int,
            gurmukhi: (r['gurmukhi'] as String?) ?? '',
            normalized: normalize((r['gurmukhi'] as String?) ?? ''),
            page: (r['page'] as int?) ?? 0,
          ),
          display: LineDisplay(
            translations: {
              if ((r['english'] as String?)?.isNotEmpty ?? false)
                'en': r['english'] as String,
              if ((r['punjabi'] as String?)?.isNotEmpty ?? false)
                'pa': r['punjabi'] as String,
            },
            transliterations: {
              if ((r['roman'] as String?)?.isNotEmpty ?? false)
                'roman': r['roman'] as String,
            },
          ),
        ),
    ];
  }

  /// A bani's lines in reading order - the linear-paath corpus (Japji = 1).
  List<Verse> baniLines(int baniId) => _toVerses(
    _db.select(
      '$_cols FROM lines l JOIN bani_lines bl ON bl.line_id = l.id '
      'WHERE bl.bani_id = ? ORDER BY l.order_id',
      [baniId],
    ),
  );

  /// One shabad's lines in order.
  List<Verse> shabadLines(String shabadId) => _toVerses(
    _db.select(
      '$_cols FROM lines l WHERE l.shabad_id = ? ORDER BY l.order_id',
      [shabadId],
    ),
  );

  /// The shabad that contains [lineId], with its author + raag - for showing a
  /// line (a search hit or one the tracker found) in its full context. Empty
  /// [ShabadContext.lines] if the line is unknown.
  ShabadContext shabadContextFor(String lineId) {
    final rows = _db.select(
      'SELECT l.shabad_id AS sid, w.name_english AS author, '
      'sec.name_english AS section FROM lines l '
      'JOIN shabads sh ON sh.id = l.shabad_id '
      'JOIN writers w ON w.id = sh.writer_id '
      'JOIN sections sec ON sec.id = sh.section_id WHERE l.id = ?',
      [lineId],
    );
    if (rows.isEmpty) {
      return const ShabadContext(lines: [], author: '', section: '');
    }
    final r = rows.first;
    return ShabadContext(
      lines: shabadLines(r['sid'].toString()),
      author: (r['author'] as String?) ?? '',
      section: (r['section'] as String?) ?? '',
    );
  }

  /// The first line of the shabad that follows the one ending at [maxOrderId] -
  /// for stepping to the next shabad. Shabads are contiguous in `order_id`, so
  /// the line just past the current shabad's last is the next shabad's first.
  /// Null at the end of the corpus.
  String? nextShabadLine(int maxOrderId) {
    final rows = _db.select(
      'SELECT id FROM lines WHERE order_id > ? ORDER BY order_id LIMIT 1',
      [maxOrderId],
    );
    return rows.isEmpty ? null : rows.first['id'].toString();
  }

  /// The first line of the shabad before the one starting at [minOrderId]. The
  /// line just before belongs to the previous shabad; we then jump to *its*
  /// first line so the previous shabad opens at its top. Null at the start.
  String? prevShabadLine(int minOrderId) {
    final prev = _db.select(
      'SELECT shabad_id AS sid FROM lines WHERE order_id < ? '
      'ORDER BY order_id DESC LIMIT 1',
      [minOrderId],
    );
    if (prev.isEmpty) return null;
    final first = _db.select(
      'SELECT id FROM lines WHERE shabad_id = ? ORDER BY order_id LIMIT 1',
      [prev.first['sid'].toString()],
    );
    return first.isEmpty ? null : first.first['id'].toString();
  }

  /// The anchor the follower runs over: a window of corpus lines around
  /// [orderId]. Wide enough to contain the whole shabad (so kirtan's returns to
  /// the asthaai stay in-window) and to let linear paath run on without
  /// re-locating every few lines.
  List<Verse> windowAround(int orderId, {int radius = 150}) => _toVerses(
    _db.select(
      '$_cols FROM lines l WHERE l.order_id BETWEEN ? AND ? ORDER BY l.order_id',
      [orderId - radius, orderId + radius],
    ),
  );

  /// The translations + transliterations to show under a line in the presenter.
  /// Two small indexed lookups by line id; empty maps where a line has none
  /// (Dasam / Bhai Gurdas lines have no English translation, for instance).
  LineDisplay displayFor(String lineId) {
    final translations = <String, String>{
      for (final r in _db.select(
        'SELECT lang, text FROM translations WHERE line_id = ?',
        [lineId],
      ))
        r['lang'] as String: r['text'] as String,
    };
    final transliterations = <String, String>{
      for (final r in _db.select(
        'SELECT script, text FROM transliterations WHERE line_id = ?',
        [lineId],
      ))
        r['script'] as String: r['text'] as String,
    };
    return LineDisplay(
      translations: translations,
      transliterations: transliterations,
    );
  }

  /// Find where a (noisy) ASR transcript sits in the *whole* corpus.
  ///
  /// FTS5 OR-matches the transcript's words, so a misheard word just drops out
  /// of the OR instead of killing the match - validated on real ASR that got 3
  /// words wrong and still ranked the true line first out of 141k. bm25 picks
  /// the candidates; we rerank with the same scorer the follower uses, so
  /// locate and follow agree.
  List<LocateHit> locate(
    String transcript, {
    int limit = 5,
    int candidates = 40,
  }) {
    final query = normalize(transcript);
    final terms = query.split(' ').where((w) => w.length > 1).take(10).toList();
    if (terms.isEmpty) return const [];

    final match = terms.map((w) => '"$w"').join(' OR ');
    final rows = _db.select(
      'SELECT l.id, l.shabad_id AS sid, l.order_id AS ord, l.gurmukhi_uni AS g, '
      'l.source_page AS page FROM lines_fts f JOIN lines l ON l.rowid = f.rowid '
      'WHERE lines_fts MATCH ? ORDER BY bm25(lines_fts) LIMIT ?',
      [match, candidates],
    );

    return [
        for (final r in rows)
          LocateHit(
            lineId: r['id'].toString(),
            shabadId: r['sid'].toString(),
            orderId: r['ord'] as int,
            gurmukhi: r['g'] as String,
            page: (r['page'] as int?) ?? 0,
            score: lineSimilarity(query, normalize(r['g'] as String)),
          ),
      ]
      ..sort((a, b) => b.score.compareTo(a.score))
      ..length = rows.length < limit ? rows.length : limit;
  }

  // Search results carry the shabad's author + raag and a roman transliteration,
  // so every search query joins the same four tables. Select list and joins are
  // split so searchEnglish can add its translation column + join between them.
  static const _searchSelect =
      'SELECT l.id, l.shabad_id AS sid, l.order_id AS ord, l.gurmukhi_uni AS g, '
      'l.source_page AS page, sh.source_id AS src, w.name_english AS author, '
      "sec.name_english AS section, COALESCE(tl.text, '') AS translit";
  static const _searchJoins =
      ' FROM lines l '
      'JOIN shabads sh ON sh.id = l.shabad_id '
      'JOIN writers w ON w.id = sh.writer_id '
      'JOIN sections sec ON sec.id = sh.section_id '
      "LEFT JOIN transliterations tl ON tl.line_id = l.id AND tl.script = 'roman' ";
  static const _searchCols = '$_searchSelect$_searchJoins';

  /// The writer / raag / source filter fragments shared by every search query
  /// (0 = All). One place builds them so the four search methods never
  /// hand-copy the same SQL.
  (String, List<Object>) _filterClauses({
    int writerId = 0,
    int sectionId = 0,
    int sourceId = 0,
  }) {
    final sql = StringBuffer();
    final args = <Object>[];
    if (writerId > 0) {
      sql.write(' AND sh.writer_id = ?');
      args.add(writerId);
    }
    if (sectionId > 0) {
      sql.write(' AND sh.section_id = ?');
      args.add(sectionId);
    }
    if (sourceId > 0) {
      sql.write(' AND sh.source_id = ?');
      args.add(sourceId);
    }
    return (sql.toString(), args);
  }

  /// First-letter search - STTM's default. Type the first letter of each word
  /// ("sdvsd" for ਸਾਜਨ ਦੇਸਿ ਵਿਦੇਸੀਅੜੇ ਸਾਨੇਹੜੇ ਦੇਦੀ), roman or Gurmukhi; the script
  /// is auto-detected. [anywhere] matches the run anywhere in a line's first
  /// letters (STTM's default), else only at the start.
  List<SearchResult> searchFirstLetters(
    String letters, {
    bool anywhere = true,
    int writerId = 0,
    int sectionId = 0,
    int sourceId = 0,
    int limit = kSearchLimit,
  }) {
    final query = letters.replaceAll(' ', '');
    if (query.isEmpty) return const [];
    // Gurmukhi codepoints are U+0A00..U+0A7F; anything in that range → Gurmukhi.
    final gurmukhi = query.runes.any((r) => r >= 0x0A00 && r <= 0x0A7F);
    final col = gurmukhi ? 'first_letters_uni' : 'first_letters';
    final (filterSql, filterArgs) = _filterClauses(
      writerId: writerId,
      sectionId: sectionId,
      sourceId: sourceId,
    );
    return _toResults(
      _db.select(
        '$_searchCols WHERE l.$col LIKE ?$filterSql '
        'ORDER BY l.order_id LIMIT ?',
        [anywhere ? '%$query%' : '$query%', ...filterArgs, limit],
      ),
    );
  }

  /// Full-word search over the Gurmukhi text (STTM's "Full Word(s)"). All words
  /// must appear; bm25 ranks the hits.
  List<SearchResult> searchFullText(
    String query, {
    int writerId = 0,
    int sectionId = 0,
    int sourceId = 0,
    int limit = kSearchLimit,
  }) {
    final terms = normalize(
      query,
    ).split(' ').where((w) => w.length > 1).toList();
    if (terms.isEmpty) return const [];
    final match = terms.map((w) => '"$w"').join(' AND ');
    final (filterSql, filterArgs) = _filterClauses(
      writerId: writerId,
      sectionId: sectionId,
      sourceId: sourceId,
    );
    return _toResults(
      _db.select(
        '$_searchCols JOIN lines_fts f ON f.rowid = l.rowid '
        'WHERE lines_fts MATCH ?$filterSql ORDER BY bm25(lines_fts) LIMIT ?',
        [match, ...filterArgs, limit],
      ),
    );
  }

  /// Full-word search over the English translations (STTM's "English Word").
  /// Every word must appear (case-insensitive `LIKE`); `%`/`_` in the query are
  /// escaped so they match literally. Measured 11-44ms over the 60k English
  /// rows, so no FTS index. Only lines with an English translation can match.
  List<SearchResult> searchEnglish(
    String query, {
    int writerId = 0,
    int sectionId = 0,
    int sourceId = 0,
    int limit = kSearchLimit,
  }) {
    final words = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return const [];
    final likes = words.map((_) => "tr.text LIKE ? ESCAPE '\\'").join(' AND ');
    final (filterSql, filterArgs) = _filterClauses(
      writerId: writerId,
      sectionId: sectionId,
      sourceId: sourceId,
    );
    return _toResults(
      _db.select(
        '$_searchSelect, tr.text AS translation$_searchJoins'
        "JOIN translations tr ON tr.line_id = l.id AND tr.lang = 'en' "
        'WHERE $likes$filterSql ORDER BY l.order_id LIMIT ?',
        [for (final w in words) '%${_escapeLike(w)}%', ...filterArgs, limit],
      ),
      withTranslation: true,
    );
  }

  /// All lines of one page (STTM's "Ang" search). Source-scoped by necessity -
  /// page numbers repeat across 10 of the 12 sources - defaulting to Sri Guru
  /// Granth Sahib exactly like STTM's `PageNo = N AND SourceID = 'G'`. Takes no
  /// writer/section filters on purpose: a page listing with holes is confusing.
  /// No LIMIT either: a page is corpus-bounded (worst case ~1k lines, lazily
  /// rendered) and capping it silently truncated non-SGGS pages.
  List<SearchResult> searchAng(int page, {int sourceId = 0}) {
    if (page <= 0) return const [];
    return _toResults(
      _db.select(
        '$_searchCols WHERE l.source_page = ? AND sh.source_id = ? '
        'ORDER BY l.order_id',
        [page, sourceId > 0 ? sourceId : 1],
      ),
    );
  }

  /// Option lists for the search filter dropdowns.
  List<FilterOption> writers() => _options('writers', orderByName: true);
  List<FilterOption> sections() => _options('sections', orderByName: true);
  List<FilterOption> sources() => _options('sources', orderByName: false);

  // [table] is always one of the three literals above, never user input.
  List<FilterOption> _options(String table, {required bool orderByName}) => [
    for (final r in _db.select(
      'SELECT id, name_english FROM $table '
      'ORDER BY ${orderByName ? 'name_english' : 'id'}',
    ))
      FilterOption(
        id: r['id'] as int,
        name: (r['name_english'] as String?) ?? '',
      ),
  ];

  /// Escape `%`, `_`, and the escape char itself for a literal LIKE match.
  static String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  List<SearchResult> _toResults(
    ResultSet rows, {
    bool withTranslation = false,
  }) => [
    for (final r in rows)
      SearchResult(
        lineId: r['id'].toString(),
        shabadId: r['sid'].toString(),
        orderId: r['ord'] as int,
        gurmukhi: r['g'] as String,
        transliteration: r['translit'] as String,
        page: (r['page'] as int?) ?? 0,
        author: (r['author'] as String?) ?? '',
        section: (r['section'] as String?) ?? '',
        translation: withTranslation ? (r['translation'] as String?) ?? '' : '',
        sourceId: (r['src'] as int?) ?? 0,
      ),
  ];

  /// `seq` is the **global** `order_id`, not a per-slice index - a sliding window
  /// must not renumber lines, or forward/backward comparisons break.
  List<Verse> _toVerses(ResultSet rows) => [
    for (final r in rows)
      Verse(
        id: r['id'].toString(),
        seq: r['ord'] as int,
        gurmukhi: r['g'] as String,
        normalized: normalize(r['g'] as String),
        page: (r['page'] as int?) ?? 0,
        typeId: (r['type'] as int?) ?? 4,
        sourceLine: r['sline'] as int?,
      ),
  ];

  void dispose() => _db.close();
}
