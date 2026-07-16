import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

String _hintFor(SearchMode mode) => switch (mode) {
  SearchMode.fullWordEnglish => 'Search English translations',
  SearchMode.fullWordGurmukhi => 'Full words in Gurmukhi',
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

class _SearchPaneState extends State<SearchPane> {
  final _query = TextEditingController();
  final _ang = TextEditingController();

  // STTM's header state: language + two checkboxes. The Ang box overrides
  // them while it holds a number (mode == ang); these keep the toggles' look
  // and give the mode to fall back to when the box clears.
  bool _english = false;
  bool _fullWord = false;
  bool _anywhere = true;

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
    _fullWord =
        mode == SearchMode.fullWordGurmukhi ||
        mode == SearchMode.fullWordEnglish;
    _anywhere = mode != SearchMode.firstLetterStart;
  }

  @override
  void dispose() {
    _query.dispose();
    _ang.dispose();
    super.dispose();
  }

  SearchMode get _toggleMode {
    if (_english) return SearchMode.fullWordEnglish;
    if (_fullWord) return SearchMode.fullWordGurmukhi;
    return _anywhere
        ? SearchMode.firstLetterAnywhere
        : SearchMode.firstLetterStart;
  }

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
          // STTM's header row: language radios + match-type checkboxes.
          Row(
            children: [
              _MiniToggle(
                key: const Key('lang_gr'),
                label: 'ਗੁਰਮੁਖੀ',
                gurmukhi: true,
                radio: true,
                on: !_english,
                onTap: () {
                  _english = false;
                  _fullWord = false;
                  _applyToggles();
                },
              ),
              _MiniToggle(
                key: const Key('lang_en'),
                label: 'English',
                radio: true,
                on: _english,
                onTap: () {
                  _english = true;
                  _fullWord = true; // English search is full-word only
                  _applyToggles();
                },
              ),
              const Spacer(),
              _MiniToggle(
                key: const Key('opt_full_word'),
                label: 'Full word',
                on: _fullWord,
                enabled: !_english, // implied + locked for English
                onTap: () {
                  _fullWord = !_fullWord;
                  _applyToggles();
                },
              ),
              const SizedBox(width: 2),
              _MiniToggle(
                key: const Key('opt_anywhere'),
                label: 'Anywhere',
                on: _anywhere,
                enabled: !_english && !_fullWord, // first-letter option only
                onTap: () {
                  _anywhere = !_anywhere;
                  _applyToggles();
                },
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
                    hintText: _hintFor(_toggleMode),
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
              capped: state.mode != SearchMode.ang &&
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
    this.enabled = true,
    this.gurmukhi = false,
    super.key,
  });

  final String label;
  final bool on;
  final bool radio;
  final bool enabled;
  final bool gurmukhi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.gurbani.accent;
    final color = !enabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : on
        ? accent
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: enabled ? onTap : null,
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
    return PopupMenuButton<int>(
      enabled: enabled,
      tooltip: 'Filter by $label',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => [
        const PopupMenuItem(value: 0, child: Text('All')),
        for (final option in options)
          PopupMenuItem(value: option.id, child: Text(option.name)),
      ],
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
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
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
