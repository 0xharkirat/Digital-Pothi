import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/gurbani_database.dart';
import '../../data/preferences.dart';
import '../../engine/corpus.dart';

part 'presenter_state.dart';

const _kBaniLength = 'baniLength';
const _kEnglishNames = 'englishBaniNames';
const _kLarivaar = 'larivaar';
const _kVishraam = 'vishraam';
const _kFontScale = 'fontScale';
const _kDisplayBg = 'displayBg';
const _kHistory = 'history';
const _kFavorites = 'favorites';
const _kIntelligentSpacebar = 'intelligentSpacebar';
const _kLeftAlign = 'leftAlign';
const _kSlideTransitions = 'slideTransitions';

/// Drives the presenter: search the corpus, load a shabad, and choose which line
/// is shown. The shown line comes from one of two places - the operator (search
/// then tap) or the AI tracker (via [showTrackerVerse]) - and this cubit owns it
/// either way, so the display and overlay have a single source of truth.
class PresenterCubit extends Cubit<PresenterState> {
  PresenterCubit(this._db, Preferences prefs)
    : _prefs = prefs,
      super(_loadState(prefs));

  final GurbaniDatabase _db;
  final Preferences _prefs;

  // When a Sundar Gutka bani is shown, its lines carry their own translations
  // (the bani DB is self-contained), so displays come from here instead of a
  // per-line DB lookup. Empty when a searched shabad is shown. [_currentBani]
  // lets a length change re-load the same bani.
  List<LineDisplay> _displays = const [];
  Bani? _currentBani;

  /// Rebuild the persisted settings + history from the on-device store, so a
  /// restart comes back exactly where the operator left off.
  static PresenterState _loadState(Preferences p) => PresenterState(
    baniLength:
        BaniLength.values[p.getInt(_kBaniLength) ?? BaniLength.short.index],
    englishBaniNames: p.getBool(_kEnglishNames) ?? false,
    larivaar: p.getBool(_kLarivaar) ?? false,
    vishraam: p.getBool(_kVishraam) ?? true,
    fontScale: p.getDouble(_kFontScale) ?? 1.0,
    displayBg: DisplayBg.values[p.getInt(_kDisplayBg) ?? DisplayBg.navy.index],
    history: _decodeEntries(p.getString(_kHistory)),
    favorites: _decodeEntries(p.getString(_kFavorites)),
    intelligentSpacebar: p.getBool(_kIntelligentSpacebar) ?? true,
    leftAlign: p.getBool(_kLeftAlign) ?? false,
    slideTransitions: p.getBool(_kSlideTransitions) ?? true,
  );

  static List<HistoryEntry> _decodeEntries(String? json) {
    if (json == null || json.isEmpty) return const [];
    return [
      for (final e in jsonDecode(json) as List)
        HistoryEntry(
          lineId: e['l'] as String,
          gurmukhi: e['g'] as String,
          author: e['a'] as String,
          section: e['s'] as String,
          page: e['p'] as int,
        ),
    ];
  }

  void _save(String key, List<HistoryEntry> entries) => _prefs.setString(
    key,
    jsonEncode([
      for (final e in entries)
        {
          'l': e.lineId,
          'g': e.gurmukhi,
          'a': e.author,
          's': e.section,
          'p': e.page,
        },
    ]),
  );

  void setMode(SearchMode mode) {
    emit(state.copyWith(mode: mode));
    search(state.query);
  }

  /// Filter setters re-run the active query, like [setMode] - a filter change
  /// must never silently do nothing until the next keystroke.
  void setWriterFilter(int id) {
    emit(state.copyWith(writerFilter: id));
    search(state.query);
  }

  void setSectionFilter(int id) {
    emit(state.copyWith(sectionFilter: id));
    search(state.query);
  }

  void setSourceFilter(int id) {
    emit(state.copyWith(sourceFilter: id));
    search(state.query);
  }

  void search(String query) {
    final q = query.trim();
    final results = q.isEmpty ? const <SearchResult>[] : _runSearch(q);
    emit(state.copyWith(query: query, results: results));
  }

  // Exhaustive over SearchMode: a sixth mode fails compilation, not falls
  // through. Ang takes only the source filter (a page listing with writer/raag
  // holes is confusing) and rejects non-numeric / non-positive input.
  List<SearchResult> _runSearch(String q) => switch (state.mode) {
    SearchMode.firstLetterStart => _db.searchFirstLetters(
      q,
      anywhere: false,
      writerId: state.writerFilter,
      sectionId: state.sectionFilter,
      sourceId: state.sourceFilter,
    ),
    SearchMode.firstLetterAnywhere => _db.searchFirstLetters(
      q,
      writerId: state.writerFilter,
      sectionId: state.sectionFilter,
      sourceId: state.sourceFilter,
    ),
    SearchMode.fullWordGurmukhi => _db.searchFullText(
      q,
      writerId: state.writerFilter,
      sectionId: state.sectionFilter,
      sourceId: state.sourceFilter,
    ),
    SearchMode.fullWordEnglish => _db.searchEnglish(
      q,
      writerId: state.writerFilter,
      sectionId: state.sectionFilter,
      sourceId: state.sourceFilter,
    ),
    SearchMode.ang => switch (int.tryParse(q)) {
      final page? when page > 0 => _db.searchAng(
        page,
        sourceId: state.sourceFilter,
      ),
      _ => const <SearchResult>[],
    },
  };

  /// Operator picked a search hit: show its shabad from that line. Taking manual
  /// control turns AI-follow off - the operator is driving now.
  void selectResult(SearchResult result) =>
      _showLineOf(result.lineId, following: false);

  /// Move within the shown shabad (arrows / tapping a line). Also manual.
  void showLine(int index) {
    if (index < 0 || index >= state.shabad.length) return;
    _advanceTo(index);
  }

  void nextLine() => showLine(state.current + 1);
  void prevLine() => showLine(state.current - 1);

  /// STTM's intelligent spacebar (`intelligentNextVerse` in change-verse.js) -
  /// space maps here; arrows stay plain. At home it resumes the antara run;
  /// away it walks the current couplet (same physical ang line) and snaps back
  /// home at the line boundary. Documented deviations from STTM: header-skip
  /// is type-driven ([Verse.isHeader]), home index 0 is valid, and at-home is
  /// derived from the shown line instead of a stored flag.
  void advance() {
    final home = state.homeIndex;
    if (home == -1) return nextLine(); // banis / quick-inserts: plain
    if (!state.intelligentSpacebar) return _advanceTo(home); // snap home
    final n = state.shabad.length;
    if (state.atHome) {
      // Resume the run where it left off, skipping headers.
      var next = state.resumeIndex == -1 ? 0 : state.resumeIndex + 1;
      if (next >= n) next = 0;
      next = _skipHeaders(next);
      // STTM steps past a home collision without re-skipping headers; the
      // wrap guard is ours (STTM overflows here).
      if (next == home) next = (next + 1) % n;
      _advanceTo(next, resumeIndex: next);
    } else {
      var cand = state.current + 1;
      // STTM wraps via its out-of-range guard, without a header skip.
      cand = cand >= n ? 0 : _skipHeaders(cand);
      final cur = state.shabad[state.current];
      final nxt = state.shabad[cand];
      // A physical ang line is (page, source_line) - line numbers restart
      // each ang, so a page-crossing shabad must not chain 19->19. NULL
      // source_line (Dasam) never matches: strict alternation there. (STTM
      // compares lineNo alone - a ported-then-fixed upstream flaw.)
      if (cur.sourceLine != null &&
          cur.sourceLine == nxt.sourceLine &&
          cur.page == nxt.page) {
        _advanceTo(cand, resumeIndex: cand); // walk the couplet
      } else {
        _advanceTo(home); // snap home; the run pointer stays put
      }
    }
  }

  int _skipHeaders(int i) {
    var j = i;
    while (j < state.shabad.length - 1 && state.shabad[j].isHeader) {
      j++;
    }
    return j;
  }

  /// One emission for any line move: line + display + manual control
  /// (following off), plus the run pointer when a spacebar move sets one -
  /// never a show plus a second bookkeeping emit.
  void _advanceTo(int index, {int? resumeIndex}) => emit(
    state.copyWith(
      current: index,
      display: index < _displays.length
          ? _displays[index]
          : _db.displayFor(state.shabad[index].id),
      following: false,
      resumeIndex: resumeIndex,
    ),
  );

  /// Re-home the shabad to [index] (STTM's `changeHomeVerse` - a bare setter;
  /// the run bookkeeping is untouched).
  void setHome(int index) {
    if (index < 0 || index >= state.shabad.length) return;
    emit(state.copyWith(homeIndex: index));
  }

  /// Step to the next / previous shabad in reading order (Ang order), opening it
  /// at its first line. No-op past the ends of the corpus.
  void nextShabad() {
    if (state.shabad.isEmpty) return;
    final id = _db.nextShabadLine(state.shabad.last.seq);
    if (id != null) _showLineOf(id, following: false);
  }

  void prevShabad() {
    if (state.shabad.isEmpty) return;
    final id = _db.prevShabadLine(state.shabad.first.seq);
    if (id != null) _showLineOf(id, following: false);
  }

  /// The AI tracker found a line. Mirror it only while following is on, so the
  /// operator's manual choice is never yanked away mid-shabad.
  void showTrackerVerse(Verse verse) {
    if (!state.following || state.line?.id == verse.id) return;
    _showLineOf(verse.id, following: true);
  }

  /// Turn AI-follow on/off (the mic button). When turning on, the next tracker
  /// verse will drive the display.
  void setFollowing({required bool on}) => emit(state.copyWith(following: on));

  void setDisplayBg(DisplayBg bg) {
    _prefs.setInt(_kDisplayBg, bg.index);
    emit(state.copyWith(displayBg: bg));
  }

  void toggleLarivaar() {
    _prefs.setBool(_kLarivaar, value: !state.larivaar);
    emit(state.copyWith(larivaar: !state.larivaar));
  }

  void toggleVishraam() {
    _prefs.setBool(_kVishraam, value: !state.vishraam);
    emit(state.copyWith(vishraam: !state.vishraam));
  }

  void toggleIntelligentSpacebar() {
    _prefs.setBool(_kIntelligentSpacebar, value: !state.intelligentSpacebar);
    emit(state.copyWith(intelligentSpacebar: !state.intelligentSpacebar));
  }

  void toggleLeftAlign() {
    _prefs.setBool(_kLeftAlign, value: !state.leftAlign);
    emit(state.copyWith(leftAlign: !state.leftAlign));
  }

  void toggleSlideTransitions() {
    _prefs.setBool(_kSlideTransitions, value: !state.slideTransitions);
    emit(state.copyWith(slideTransitions: !state.slideTransitions));
  }

  /// Nudge the font scale within sensible bounds.
  void bumpFontScale(double by) => setFontScale(state.fontScale + by);

  /// Set the font scale directly (the settings slider), clamped.
  void setFontScale(double scale) {
    final v = scale.clamp(0.7, 1.5);
    _prefs.setDouble(_kFontScale, v);
    emit(state.copyWith(fontScale: v));
  }

  /// Re-open a shabad from the History pane, at the line it was shown on.
  void openHistory(HistoryEntry entry) =>
      _showLineOf(entry.lineId, following: false);

  /// Wipe the session history (STTM's Clear History), including the store.
  void clearHistory() {
    _save(_kHistory, const []);
    emit(state.copyWith(history: const []));
  }

  /// Star / unstar the current shabad line (STTM's Favorites). Only real corpus
  /// lines qualify - not quick-insert slides or bani lines.
  void toggleFavorite() {
    final line = state.line;
    if (line == null || !state.canFavorite) return;
    final favorites = state.isFavorite
        ? state.favorites.where((f) => f.lineId != line.id).toList()
        : [
            HistoryEntry(
              lineId: line.id,
              gurmukhi: line.gurmukhi,
              author: state.author,
              section: state.section,
              page: line.page,
            ),
            ...state.favorites,
          ];
    _save(_kFavorites, favorites);
    emit(state.copyWith(favorites: favorites));
  }

  /// Re-open a saved shabad from Favorites.
  void openFavorite(HistoryEntry entry) =>
      _showLineOf(entry.lineId, following: false);

  /// Remove a specific entry from Favorites (the unstar in the list).
  void removeFavorite(HistoryEntry entry) {
    final favorites = state.favorites
        .where((f) => f.lineId != entry.lineId)
        .toList();
    _save(_kFavorites, favorites);
    emit(state.copyWith(favorites: favorites));
  }

  /// Open a Sundar Gutka bani (Japji, Rehras, ...) at the current bani length.
  /// The lines come from the self-contained bani DB (own text + translations),
  /// so [_displays] drives the translations pane instead of a per-line lookup.
  /// Recorded in history so it's resumable.
  void showBani(Bani bani) {
    final baniLines = _db.sgBaniLines(bani.id, state.baniLength);
    if (baniLines.isEmpty) return;
    _currentBani = bani;
    _displays = [for (final b in baniLines) b.display];
    final lines = [for (final b in baniLines) b.verse];
    final first = lines.first;
    final name = state.englishBaniNames ? bani.english : bani.gurmukhi;
    final entry = HistoryEntry(
      lineId: first.id,
      gurmukhi: first.gurmukhi,
      author: name,
      section: 'Nitnem',
      page: first.page,
    );
    final history = [
      entry,
      ...state.history.where((e) => e.lineId != first.id),
    ];
    if (history.length > 50) history.removeRange(50, history.length);
    _save(_kHistory, history);
    emit(
      state.copyWith(
        shabad: lines,
        current: 0,
        author: name,
        section: 'Nitnem',
        display: _displays.first,
        following: false,
        history: history,
        homeIndex: -1, // banis have no home: space stays plain
        resumeIndex: -1,
      ),
    );
  }

  /// Toggle bani names between Gurmukhi (default) and English.
  void toggleBaniNames() {
    _prefs.setBool(_kEnglishNames, value: !state.englishBaniNames);
    emit(state.copyWith(englishBaniNames: !state.englishBaniNames));
  }

  /// Change the bani-length tier (STTM's Short/Medium/Long/Extra Long). It's a
  /// global setting (all banis), like STTM. Re-loads the current bani if one is
  /// showing.
  void setBaniLength(BaniLength length) {
    _prefs.setInt(_kBaniLength, length.index);
    emit(state.copyWith(baniLength: length));
    final bani = _currentBani;
    if (bani != null) showBani(bani);
  }

  /// Quick-insert slides (STTM's Waheguru / Mool Mantar / blank). Modelled as a
  /// one-line synthetic shabad so the display, overlay, and nav all just work -
  /// no display-override branch anywhere. Not recorded in history.
  void showWaheguru() => _showSpecial('ਵਾਹਿਗੁਰੂ');

  void showMoolMantar() => _showSpecial(
    'ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ ਨਿਰਭਉ ਨਿਰਵੈਰੁ ਅਕਾਲ ਮੂਰਤਿ ਅਜੂਨੀ ਸੈਭੰ ਗੁਰ ਪ੍ਰਸਾਦਿ ॥',
  );

  void showBlank() => _showSpecial('');

  /// Quick-insert Anand Sahib Bhog (the 6-pauris + salok bhog), matched by name
  /// so the cubit stays free of the bani DB's id scheme.
  void showAnandBhog() {
    final bhog = _db.banis().where((b) => b.english == 'Anand Sahib Bhog');
    if (bhog.isNotEmpty) showBani(bhog.first);
  }

  /// Show an operator announcement as a slide (STTM's announcement slide).
  void showAnnouncement(String text) => _showSpecial(text);

  void _showSpecial(String text) {
    _displays = const [];
    _currentBani = null;
    emit(
      state.copyWith(
        shabad: [
          Verse(id: 'special', seq: 0, gurmukhi: text, normalized: '', page: 0),
        ],
        current: 0,
        display: LineDisplay.empty,
        author: '',
        section: '',
        following: false,
        homeIndex: -1, // known punt: the slide replaces the shabad, so the
        resumeIndex: -1, // home is gone until it's reopened (backlog A15)
      ),
    );
  }

  void _showLineOf(String lineId, {required bool following}) {
    _displays = const [];
    _currentBani = null;
    final ctx = _db.shabadContextFor(lineId);
    if (ctx.lines.isEmpty) return;
    final idx = ctx.lines.indexWhere((v) => v.id == lineId);
    final shown = ctx.lines[idx < 0 ? 0 : idx];
    // Home initializes only on an actual shabad swap - a same-shabad call (the
    // tracker moving within the shabad, re-tapping a search hit) must not make
    // home chase the shown line. STTM likewise resets only when the shabad id
    // changes.
    final sameShabad =
        state.shabad.isNotEmpty && ctx.lines.first.id == state.shabad.first.id;
    final entry = HistoryEntry(
      lineId: lineId,
      gurmukhi: shown.gurmukhi,
      author: ctx.author,
      section: ctx.section,
      page: shown.page,
    );
    final history = [entry, ...state.history.where((e) => e.lineId != lineId)];
    if (history.length > 50) history.removeRange(50, history.length);
    _save(_kHistory, history);
    emit(
      state.copyWith(
        shabad: ctx.lines,
        current: idx < 0 ? 0 : idx,
        author: ctx.author,
        section: ctx.section,
        display: _db.displayFor(lineId),
        following: following,
        history: history,
        homeIndex: sameShabad ? state.homeIndex : (idx < 0 ? 0 : idx),
        resumeIndex: sameShabad ? state.resumeIndex : -1,
      ),
    );
  }
}
