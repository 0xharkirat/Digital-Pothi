import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

String _hintFor(SearchMode mode, {required bool english}) => switch (mode) {
  SearchMode.fullWordEnglish => 'Search English translations',
  SearchMode.fullWordGurmukhi => 'Full words in Gurmukhi',
  _ when english => 'Romanized first letters - mkjt',
  _ => 'First letters - sdvsd or ਸਦਵਸਦ',
};

/// Top-left pane, laid out like STTM's search header: a language + match-type
/// toggle row, the query box with a small Ang box beside it (no mode
/// dropdown), a weightless "Filter by" text row, the results, and a footer
/// legend (per-source colour + count). The five [SearchMode]s map onto
/// STTM's mental model: language radio x Full Word(s) / Anywhere checkboxes,
/// with Ang driven by its own box.
class SearchPane extends StatefulWidget {
  const SearchPane({super.key});

  @override
  State<SearchPane> createState() => _SearchPaneState();
}

/// The one-of match types (STTM's currentSearchType): radio semantics, so no
/// checkbox coupling rules.
enum _Match { start, anywhere, fullWord }

class _SearchPaneState extends State<SearchPane> {
  final _query = TextEditingController();
  final _ang = TextEditingController();

  // STTM's header state: language radio + match-type radio. The Ang box
  // overrides them while it holds a number (mode == ang); these keep the
  // header's look and give the mode to fall back to when the box clears.
  bool _english = false;
  _Match _match = _Match.anywhere;
  bool _keyboardOpen = false;

  @override
  void initState() {
    super.initState();
    // Adopt whatever the cubit holds (pane recreated across the layout
    // breakpoint, hot reload): seed the right box from the live query so an
    // active Ang search doesn't strand the cubit in ang mode with empty boxes.
    final state = context.read<PresenterCubit>().state;
    final mode = state.mode;
    if (mode == SearchMode.ang) {
      _ang.text = state.query;
    } else {
      _query.text = state.query;
    }
    _english = mode == SearchMode.fullWordEnglish;
    _match = switch (mode) {
      SearchMode.fullWordGurmukhi ||
      SearchMode.fullWordEnglish => _Match.fullWord,
      SearchMode.firstLetterStart => _Match.start,
      _ => _Match.anywhere,
    };
  }

  @override
  void dispose() {
    _query.dispose();
    _ang.dispose();
    super.dispose();
  }

  // STTM's model: the language picks the input script, the match radio picks
  // the mode. English + first letters = romanized first letters (the corpus
  // search auto-detects roman input); English + Full word = translations.
  SearchMode get _toggleMode => switch (_match) {
    _Match.fullWord =>
      _english ? SearchMode.fullWordEnglish : SearchMode.fullWordGurmukhi,
    _Match.anywhere => SearchMode.firstLetterAnywhere,
    _Match.start => SearchMode.firstLetterStart,
  };

  /// A toggle changed: leave Ang mode if its box is empty, else the box keeps
  /// ruling (STTM's side input wins while it has a number).
  void _applyToggles() {
    setState(() {});
    if (_ang.text.trim().isEmpty) {
      context.read<PresenterCubit>()
        ..setMode(_toggleMode)
        ..search(_query.text);
    }
  }

  void _onQueryChanged(String text) {
    final cubit = context.read<PresenterCubit>();
    if (_ang.text.isNotEmpty) {
      // Typing in the main box takes over from the Ang box.
      _ang.clear();
      cubit.setMode(_toggleMode);
    }
    cubit.search(text);
  }

  void _onAngChanged(String text) {
    final cubit = context.read<PresenterCubit>();
    if (text.trim().isEmpty) {
      cubit
        ..setMode(_toggleMode)
        ..search(_query.text);
    } else {
      if (cubit.state.mode != SearchMode.ang) cubit.setMode(SearchMode.ang);
      cubit.search(text);
    }
  }

  /// On-screen Gurmukhi keyboard edits: insert at the caret (or replace the
  /// selection) and run the search, exactly like typing.
  void _insert(String ch) {
    final v = _query.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    final text = v.text.replaceRange(sel.start, sel.end, ch);
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: sel.start + ch.length),
    );
    _onQueryChanged(text);
  }

  void _backspace() {
    final v = _query.value;
    final sel = v.selection.isValid
        ? v.selection
        : TextSelection.collapsed(offset: v.text.length);
    if (sel.start == 0 && sel.isCollapsed) return;
    final start = sel.isCollapsed ? sel.start - 1 : sel.start;
    final text = v.text.replaceRange(start, sel.end, '');
    _query.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start),
    );
    _onQueryChanged(text);
  }

  void _openFirst() {
    final cubit = context.read<PresenterCubit>();
    final results = cubit.state.results;
    if (results.isNotEmpty) cubit.selectResult(results.first);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PresenterCubit>();
    final db = context.read<GurbaniDatabase>();
    final theme = Theme.of(context);
    // Static reference data, read directly like BaniDrawer reads banis(); the
    // boundary holds at option lists - queries always run through the cubit.
    final writers = db.writers();
    final sections = db.sections();
    final sources = db.sources();
    final sourceNames = {for (final s in sources) s.id: s.name};

    return BlocBuilder<PresenterCubit, PresenterState>(
      buildWhen: (a, b) =>
          a.mode != b.mode ||
          a.writerFilter != b.writerFilter ||
          a.sectionFilter != b.sectionFilter ||
          a.sourceFilter != b.sourceFilter ||
          a.results != b.results ||
          a.query != b.query,
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // STTM's header row: language radios + match-type radios. A Wrap,
          // so a narrow pane stacks the two groups instead of overflowing.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniToggle(
                    key: const Key('lang_gr'),
                    label: 'ਗੁਰਮੁਖੀ',
                    gurmukhi: true,
                    radio: true,
                    on: !_english,
                    onTap: () {
                      _english = false; // script only - the match radio stays
                      _applyToggles();
                    },
                  ),
                  _MiniToggle(
                    key: const Key('lang_en'),
                    label: 'English',
                    radio: true,
                    on: _english,
                    onTap: () {
                      _english = true; // romanized letters or translations
                      // STTM's English options are Anywhere + Full word only.
                      if (_match == _Match.start) _match = _Match.anywhere;
                      _applyToggles();
                    },
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (key, label, match) in [
                    // STTM: English offers Anywhere + Full word only.
                    if (!_english)
                      ('match_start', 'First letters', _Match.start),
                    ('match_anywhere', 'Anywhere', _Match.anywhere),
                    ('match_full', 'Full word', _Match.fullWord),
                  ])
                    _MiniToggle(
                      key: Key(key),
                      label: label,
                      radio: true,
                      on: _match == match,
                      onTap: () {
                        _match = match;
                        _applyToggles();
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('search_field'),
                  controller: _query,
                  autofocus: true,
                  onChanged: _onQueryChanged,
                  // STTM: Enter opens the first result; the nav focus then
                  // takes the keyboard for line navigation.
                  onSubmitted: (_) => _openFirst(),
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _english
                        ? null
                        : IconButton(
                            key: const Key('kb_toggle'),
                            icon: Icon(
                              Icons.keyboard_outlined,
                              size: 18,
                              color: _keyboardOpen
                                  ? context.gurbani.accent
                                  : null,
                            ),
                            tooltip: 'Gurmukhi keyboard',
                            onPressed: () =>
                                setState(() => _keyboardOpen = !_keyboardOpen),
                          ),
                    hintText: _hintFor(_toggleMode, english: _english),
                    filled: true,
                    isDense: true,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // STTM's small side input: type an Ang number, it takes over.
              SizedBox(
                width: 76,
                child: TextField(
                  key: const Key('ang_field'),
                  controller: _ang,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onAngChanged,
                  onSubmitted: (_) => _openFirst(),
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Ang',
                    filled: true,
                    isDense: true,
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_keyboardOpen && !_english) ...[
            const SizedBox(height: 4),
            _GurmukhiKeyboard(onKey: _insert, onBackspace: _backspace),
          ],
          const SizedBox(height: 4),
          // Weightless text filters, right-aligned like STTM's "Filter by".
          // A Wrap, so a long selected name on a narrow pane flows to a second
          // row instead of overflowing.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Filter by',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              _TextFilter(
                key: const Key('filter_writer'),
                label: 'Writer',
                options: writers,
                value: state.writerFilter,
                enabled: state.mode != SearchMode.ang,
                onChanged: cubit.setWriterFilter,
              ),
              _TextFilter(
                key: const Key('filter_raag'),
                label: 'Raag',
                options: sections,
                value: state.sectionFilter,
                enabled: state.mode != SearchMode.ang,
                onChanged: cubit.setSectionFilter,
              ),
              _TextFilter(
                key: const Key('filter_source'),
                label: 'Source',
                options: sources,
                value: state.sourceFilter,
                onChanged: cubit.setSourceFilter,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.results.isEmpty
                ? Center(
                    child: Text(
                      state.emptyStateText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.results.length,
                    itemBuilder: (context, i) => _ResultTile(
                      result: state.results[i],
                      onTap: () => cubit.selectResult(state.results[i]),
                    ),
                  ),
          ),
          // STTM's footer: a per-source colour legend + the result count.
          if (state.results.isNotEmpty)
            _SourceLegend(
              results: state.results,
              names: sourceNames,
              // Ang search is uncapped (a page is a page); the others truncate
              // at the shared query limit.
              capped:
                  state.mode != SearchMode.ang &&
                  state.results.length >= kSearchLimit,
            ),
        ],
      ),
    );
  }
}

/// An STTM-style inline toggle: a radio dot or check glyph + a small label.
/// Weightless - no outline, no chip container.
class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.on,
    required this.onTap,
    this.radio = false,
    this.gurmukhi = false,
    super.key,
  });

  final String label;
  final bool on;
  final bool radio;
  final bool gurmukhi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.gurbani.accent;
    final color = on ? accent : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      mouseCursor: kClickCursor,
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              radio
                  ? (on
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                  : (on ? Icons.check_box : Icons.check_box_outline_blank),
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontFamily: gurmukhi ? kGurmukhiFont : null,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A weightless text-dropdown filter: `Writer ▾` (or the chosen name in
/// accent). All = 0 resets.
class _TextFilter extends StatelessWidget {
  const _TextFilter({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<FilterOption> options;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.gurbani.accent;
    final active = value != 0;
    final name = active
        ? options
              .firstWhere(
                (o) => o.id == value,
                orElse: () => FilterOption(id: value, name: label),
              )
              .name
        : label;
    final color = !enabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : active
        ? accent
        : theme.colorScheme.onSurfaceVariant;
    // Own InkWell + showMenu instead of PopupMenuButton: its internal anchor
    // InkWell ignores the theme's cursor, and the hand cursor is the point.
    return Tooltip(
      message: 'Filter by $label',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        mouseCursor: kClickCursor,
        borderRadius: BorderRadius.circular(4),
        onTap: enabled ? () => _openMenu(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final picked = await showMenu<int>(
      context: context,
      initialValue: value,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          box.localToGlobal(Offset.zero, ancestor: overlay),
          box.localToGlobal(
            box.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(value: 0, child: Text('All')),
        for (final option in options)
          PopupMenuItem(value: option.id, child: Text(option.name)),
      ],
    );
    if (picked != null) onChanged(picked);
  }
}

/// STTM's on-screen Gurmukhi keyboard, base page: the ਪੈਂਤੀ in order (10 per
/// row, exactly STTM's withoutMatra layout), space, backspace. First-letter
/// search only needs the base letters; the matra page can come with full-word
/// needs.
class _GurmukhiKeyboard extends StatelessWidget {
  const _GurmukhiKeyboard({required this.onKey, required this.onBackspace});

  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const _rows = [
    ['ੳ', 'ਅ', 'ੲ', 'ਸ', 'ਹ', 'ਕ', 'ਖ', 'ਗ', 'ਘ', 'ਙ'],
    ['ਚ', 'ਛ', 'ਜ', 'ਝ', 'ਞ', 'ਟ', 'ਠ', 'ਡ', 'ਢ', 'ਣ'],
    ['ਤ', 'ਥ', 'ਦ', 'ਧ', 'ਨ', 'ਪ', 'ਫ', 'ਬ', 'ਭ', 'ਮ'],
    ['ਯ', 'ਰ', 'ਲ', 'ਵ', 'ੜ'],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget key_(Widget child, VoidCallback onTap, {int flex = 1}) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          mouseCursor: kClickCursor,
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: Ink(
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );

    Widget letter(String ch) => key_(
      Text(
        ch,
        style: TextStyle(
          fontFamily: kGurmukhiFont,
          fontSize: 16,
          color: theme.colorScheme.onSurface,
        ),
      ),
      () => onKey(ch),
    );

    // STTM's keyboard sits on its own backdrop with an outer border, so it
    // reads as a surface, not letters floating on the pane.
    return Container(
      key: const Key('gurmukhi_keyboard'),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          for (final row in _rows)
            Row(
              children: [
                for (final ch in row) letter(ch),
                if (row.last == 'ੜ') ...[
                  key_(
                    Icon(
                      Icons.space_bar,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    () => onKey(' '),
                    flex: 3,
                  ),
                  key_(
                    Icon(
                      Icons.backspace_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onBackspace,
                    flex: 2,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});
  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.gurbani;
    final theme = Theme.of(context);
    // Ink, not Container: an opaque Container hides the InkWell's hover.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        mouseCursor: kClickCursor,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            // Accent keyed by source, like STTM's result bars.
            border: Border(
              left: BorderSide(
                color: AppColors.sourceColor(result.sourceId),
                width: 3,
              ),
            ),
            color: theme.colorScheme.surfaceContainerHigh,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Ang ${result.page}   ',
                      style: TextStyle(
                        color: g.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: strippedGurmukhi(result.gurmukhi),
                      style: g.gurmukhi.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              // Why an English hit matched - populated by English search only.
              if (result.translation.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  result.translation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 2),
              Text(
                [
                  result.author,
                  result.section,
                ].where((s) => s.isNotEmpty).join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// STTM's search footer: a colour legend for the sources present in the
/// results, and the count (with a "+" when the query limit truncated it).
class _SourceLegend extends StatelessWidget {
  const _SourceLegend({
    required this.results,
    required this.names,
    required this.capped,
  });
  final List<SearchResult> results;
  final Map<int, String> names;
  final bool capped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final present = <int>{for (final r in results) r.sourceId}..remove(0);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          for (final id in present.toList()..sort()) ...[
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: AppColors.sourceColor(id),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                names[id] ?? 'Source $id',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '${results.length}${capped ? '+' : ''} '
            'result${results.length == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
