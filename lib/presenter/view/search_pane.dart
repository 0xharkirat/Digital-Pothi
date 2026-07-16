import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/gurbani_database.dart';
import '../../theme/app_theme.dart';
import '../cubit/presenter_cubit.dart';
import '../gurmukhi_text.dart';

/// STTM's search-type labels (banidb SEARCH_TYPES, minus the deferred two).
const _modeLabels = {
  SearchMode.firstLetterStart: 'First letter (start)',
  SearchMode.firstLetterAnywhere: 'First letter (anywhere)',
  SearchMode.fullWordGurmukhi: 'Full word (Gurmukhi)',
  SearchMode.fullWordEnglish: 'Full word (English)',
  SearchMode.ang: 'Ang',
};

String _hintFor(SearchMode mode) => switch (mode) {
  SearchMode.ang => 'Ang number (Sri Guru Granth Sahib by default)',
  SearchMode.fullWordEnglish => 'Search English translations',
  SearchMode.fullWordGurmukhi => 'Full words in Gurmukhi',
  _ => 'First letters - sdvsd or ਸਦਵਸਦ',
};

/// Top-left pane: STTM-style search. A type dropdown (first letter, full word
/// Gurmukhi/English, Ang), the query box, and a Writer / Raag / Source filter
/// row. Writer and Raag are disabled in Ang mode - a page listing with filter
/// holes is confusing; only Source scopes an Ang.
class SearchPane extends StatelessWidget {
  const SearchPane({super.key});

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
          DropdownButtonFormField<SearchMode>(
            key: const Key('search_type'),
            initialValue: state.mode,
            isDense: true,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final mode in SearchMode.values)
                DropdownMenuItem(value: mode, child: Text(_modeLabels[mode]!)),
            ],
            onChanged: (mode) {
              if (mode != null) cubit.setMode(mode);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('search_field'),
            autofocus: true,
            onChanged: cubit.search,
            onSubmitted: (_) {
              // STTM: Enter opens the first result; the nav focus then takes
              // the keyboard for line navigation.
              final results = cubit.state.results;
              if (results.isNotEmpty) cubit.selectResult(results.first);
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _hintFor(state.mode),
              filled: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  key: const Key('filter_writer'),
                  label: 'Writer',
                  options: writers,
                  value: state.writerFilter,
                  enabled: state.mode != SearchMode.ang,
                  onChanged: cubit.setWriterFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  key: const Key('filter_raag'),
                  label: 'Raag',
                  options: sections,
                  value: state.sectionFilter,
                  enabled: state.mode != SearchMode.ang,
                  onChanged: cubit.setSectionFilter,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  key: const Key('filter_source'),
                  label: 'Source',
                  options: sources,
                  value: state.sourceFilter,
                  onChanged: cubit.setSourceFilter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}

/// One filter dropdown with an "All" first entry (value 0 = no filter).
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
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
    return DropdownButtonFormField<int>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('All')),
        for (final option in options)
          DropdownMenuItem(
            value: option.id,
            child: Text(option.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled
          ? (id) {
              if (id != null) onChanged(id);
            }
          : null,
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
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: g.accent, width: 3)),
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
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
                    style: g.gurmukhi,
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
