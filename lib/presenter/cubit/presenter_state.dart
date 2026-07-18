part of 'presenter_cubit.dart';

/// STTM's search types (banidb SEARCH_TYPES), minus the deferred "Main
/// letters" and "Romanized first letters".
enum SearchMode {
  firstLetterStart,
  firstLetterAnywhere,
  fullWordGurmukhi,
  fullWordEnglish,
  ang,
}

/// Selectable projected background (STTM offers several); mapped to a colour in
/// the view so the cubit stays free of Flutter types.
enum DisplayBg { navy, black, graphite, midnight }

/// A recently shown line, for the History pane. Equality is on [lineId] so
/// re-showing a line moves it to the top instead of duplicating.
class HistoryEntry extends Equatable {
  const HistoryEntry({
    required this.lineId,
    required this.gurmukhi,
    required this.author,
    required this.section,
    required this.page,
  });

  final String lineId;
  final String gurmukhi;
  final String author;
  final String section;
  final int page;

  @override
  List<Object> get props => [lineId];
}

class PresenterState extends Equatable {
  const PresenterState({
    this.query = '',
    this.mode = SearchMode.firstLetterAnywhere,
    this.writerFilter = 0,
    this.sectionFilter = 0,
    this.sourceFilter = 0,
    this.results = const [],
    this.shabad = const [],
    this.current = -1,
    this.display = LineDisplay.empty,
    this.author = '',
    this.section = '',
    this.following = false,
    this.displayBg = DisplayBg.navy,
    this.larivaar = false,
    this.vishraam = true,
    this.fontScale = 1.0,
    this.history = const [],
    this.favorites = const [],
    this.baniLength = BaniLength.short,
    this.englishBaniNames = false,
    this.homeIndex = -1,
    this.resumeIndex = -1,
    this.intelligentSpacebar = true,
    this.leftAlign = false,
    this.slideTransitions = true,
  });

  final String query;
  final SearchMode mode;

  /// Search filters as flat writer / section / source ids; 0 = All. The
  /// sentinel avoids nullable-copyWith clearing semantics, and three ints do
  /// not need a value class. `sectionFilter` sits behind the UI label "Raag"
  /// deliberately - it matches [section] and the DB's `section_id`.
  final int writerFilter;
  final int sectionFilter;
  final int sourceFilter;

  final List<SearchResult> results;

  /// The lines of the shown shabad, and which one is on the display.
  final List<Verse> shabad;
  final int current;

  /// Translations + transliterations for the shown line.
  final LineDisplay display;
  final String author;
  final String section;

  /// True while the AI tracker is allowed to drive the shown line.
  final bool following;

  /// The chosen projected background preset.
  final DisplayBg displayBg;

  /// Display options that shape how the line is rendered.
  final bool larivaar; // run words together
  final bool vishraam; // colour the pause words
  final double fontScale; // 0.7 .. 1.5, multiplies the base sizes
  final bool leftAlign; // STTM left-align: line + rows flush-left, not centred
  final bool slideTransitions; // fade the projected line on change

  /// Recently shown lines, most recent first. Persisted across launches.
  final List<HistoryEntry> history;

  /// Saved shabads (STTM's Favorites), most recent first. Persisted, local.
  final List<HistoryEntry> favorites;

  /// The chosen bani-length tier for Sundar Gutka banis.
  final BaniLength baniLength;

  /// Show bani names in English rather than the default Gurmukhi.
  final bool englishBaniNames;

  /// The home (asthaai) line of the loaded shabad, STTM's `homeVerse`.
  /// -1 = none (banis, quick-inserts), following the [current] convention;
  /// 0 is a valid home (STTM's falsy-zero bug is deliberately not ported).
  final int homeIndex;

  /// STTM's `previousVerseIndex`: where the antara run resumes after a snap
  /// home - NOT "the verse shown before". Only [PresenterCubit.advance] and
  /// the shabad-load path write it. -1 = no run yet.
  final int resumeIndex;

  /// STTM's intelligent spacebar: space alternates run/home instead of
  /// snapping straight home. Persisted; on by default.
  final bool intelligentSpacebar;

  /// Space is "at home" when the shown line IS the home line - derived, not
  /// stored (deliberate deviation from STTM, which stores a flag that goes
  /// stale under manual navigation and dead-presses).
  bool get atHome => homeIndex != -1 && current == homeIndex;

  Verse? get line =>
      current >= 0 && current < shabad.length ? shabad[current] : null;

  bool get hasPrev => current > 0;
  bool get hasNext => current >= 0 && current < shabad.length - 1;

  /// The current line is a real corpus shabad line (favouritable) - not a
  /// synthetic quick-insert slide or a bani line.
  bool get canFavorite {
    final id = line?.id;
    return id != null && id != 'special' && !id.startsWith('sg:');
  }

  bool get isFavorite => favorites.any((f) => f.lineId == line?.id);

  /// What the empty results area says: a per-mode prompt before typing, and a
  /// real "no results" once a query is in - noting active filters, so
  /// filtered-out-everything is never mistaken for an empty corpus.
  String get emptyStateText {
    if (query.trim().isEmpty) {
      return switch (mode) {
        SearchMode.ang =>
          'Type an Ang number (Sri Guru Granth Sahib - pick a Source to change)',
        SearchMode.fullWordEnglish => 'Search the English translations',
        _ => 'Type to search the whole corpus',
      };
    }
    // In Ang mode only the Source filter applies (writer/raag are ignored and
    // disabled), so only it can be blamed for an empty page.
    final filtered = mode == SearchMode.ang
        ? sourceFilter > 0
        : writerFilter > 0 || sectionFilter > 0 || sourceFilter > 0;
    return filtered ? 'No results (filters active)' : 'No results';
  }

  PresenterState copyWith({
    String? query,
    SearchMode? mode,
    int? writerFilter,
    int? sectionFilter,
    int? sourceFilter,
    List<SearchResult>? results,
    List<Verse>? shabad,
    int? current,
    LineDisplay? display,
    String? author,
    String? section,
    bool? following,
    DisplayBg? displayBg,
    bool? larivaar,
    bool? vishraam,
    double? fontScale,
    List<HistoryEntry>? history,
    List<HistoryEntry>? favorites,
    BaniLength? baniLength,
    bool? englishBaniNames,
    int? homeIndex,
    int? resumeIndex,
    bool? intelligentSpacebar,
    bool? leftAlign,
    bool? slideTransitions,
  }) => PresenterState(
    query: query ?? this.query,
    mode: mode ?? this.mode,
    writerFilter: writerFilter ?? this.writerFilter,
    sectionFilter: sectionFilter ?? this.sectionFilter,
    sourceFilter: sourceFilter ?? this.sourceFilter,
    results: results ?? this.results,
    shabad: shabad ?? this.shabad,
    current: current ?? this.current,
    display: display ?? this.display,
    author: author ?? this.author,
    section: section ?? this.section,
    following: following ?? this.following,
    displayBg: displayBg ?? this.displayBg,
    larivaar: larivaar ?? this.larivaar,
    vishraam: vishraam ?? this.vishraam,
    fontScale: fontScale ?? this.fontScale,
    history: history ?? this.history,
    favorites: favorites ?? this.favorites,
    baniLength: baniLength ?? this.baniLength,
    englishBaniNames: englishBaniNames ?? this.englishBaniNames,
    homeIndex: homeIndex ?? this.homeIndex,
    resumeIndex: resumeIndex ?? this.resumeIndex,
    intelligentSpacebar: intelligentSpacebar ?? this.intelligentSpacebar,
    leftAlign: leftAlign ?? this.leftAlign,
    slideTransitions: slideTransitions ?? this.slideTransitions,
  );

  // `display` is derived from `current`, so it's left out - `current` already
  // distinguishes states, and LineDisplay isn't a value type.
  @override
  List<Object?> get props => [
    query,
    mode,
    writerFilter,
    sectionFilter,
    sourceFilter,
    results,
    shabad,
    current,
    author,
    section,
    following,
    displayBg,
    larivaar,
    vishraam,
    fontScale,
    history,
    favorites,
    baniLength,
    englishBaniNames,
    homeIndex,
    resumeIndex,
    intelligentSpacebar,
    leftAlign,
    slideTransitions,
  ];
}
