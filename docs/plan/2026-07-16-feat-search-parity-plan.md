---
title: "feat: search parity - STTM search types + filters"
type: feat
date: 2026-07-16
---

## feat: search parity - STTM search types + filters (Epic A: A4 + A5)

## Overview

Bring the presenter's search to STTM-desktop parity in one chunk.
The two chips (First Letter / Full Word) become an STTM-style search-type dropdown with five types: First letter (start), First letter (anywhere), Full word (Gurmukhi), Full word (English), and Ang.
A "Filter by" row adds Writer, Raag, and Source dropdowns that combine with the active query, as on STTM's search pane.
Everything stays local and on-device.

Brainstorm (grilled): `docs/brainstorm/2026-07-16-search-parity-brainstorm-doc.md`.
STTM ground truth: `tmp/sttm-desktop/www/main/navigator/search/` and `www/main/common/constants/banidb.js` (SEARCH_TYPES).

## Problem Statement / Motivation

An operator coming from STTM expects to search by English words, jump to an Ang, and narrow by writer / raag / source.
We only offer Gurmukhi first-letter and full-word today, so those flows dead-end.

## Proposed Solution

Extend the existing search path end to end; no new layers.

### Data layer - `lib/data/gurbani_database.dart`

- Add filter parameters `{int writerId = 0, int sectionId = 0, int sourceId = 0}` (0 = All; corpus ids start at 1), applied through one shared private helper that builds the `AND` clauses + args once - the four search methods must not hand-copy the same SQL fragments.
- `searchFirstLetters` gains the filters; the existing `anywhere` flag maps to the two first-letter types.
- `searchFullText` (Gurmukhi FTS) gains the filters.
- New `searchEnglish(query, {filters, limit})`: split words, `AND` of `LIKE '%word%'` over `translations` where `lang='en'`, joined through `_searchCols`; ordered by `l.order_id`. Measured at 11-44ms over 60,555 rows, so no FTS index.
- New `searchAng(page, {sourceId, limit})` - **source-only signature, no writer/section params**, so a stale writer filter can never narrow a page listing: `l.source_page = ? AND sh.source_id = ?` where the source is the Source filter when set, else 1 (Sri Guru Granth Sahib) - STTM's `PageNo = N AND SourceID = 'G'`. Ordered by `l.order_id`.
- New option lists for the dropdowns: `writers()`, `sections()`, `sources()` returning `(id, englishName)` rows; the view reads them directly like `BaniDrawer` reads `banis()`. The boundary holds at static option lists only - query execution never happens from the view.

### State - `lib/presenter/cubit/presenter_state.dart`

- `SearchMode` becomes `{ firstLetterStart, firstLetterAnywhere, fullWordGurmukhi, fullWordEnglish, ang }`.
- New fields: `writerFilter`, `sectionFilter`, `sourceFilter` - three flat ints (0 = All), session-scoped (not persisted). Explicitly no `SearchFilters` value class; three ints do not need an abstraction.
- New getter: `emptyStateText` (per-mode prompt / "No results" / "No results with filters active").

### Cubit - `lib/presenter/cubit/presenter_cubit.dart`

- `search()` dispatches on the mode via an **exhaustive `switch` expression** over `SearchMode`, so a future sixth mode fails compilation instead of falling through; Ang parses the digits and returns empty results for non-numeric / zero / negative input.
- `setMode`, `setWriterFilter`, `setSectionFilter`, `setSourceFilter` each re-run the current query (existing `setMode` pattern).
- Naming note: `sectionFilter` sits behind the UI label "Raag" deliberately - it matches `PresenterState.section` and the DB's `section_id`; do not rename to `raagFilter` mid-implementation.

### View - `lib/presenter/view/search_pane.dart`

- The chip row becomes a compact `DropdownMenu<SearchMode>` with the five STTM labels.
- The hint text follows the mode (e.g. Ang: "Ang number", English: "Search English translations").
- A "Filter by" row of three `DropdownMenu`s (Writer / Raag / Source) with an "All" first entry; options loaded once from the DB in the view.
- Result tiles are unchanged; Ang results are that page's lines in page order and tap-to-open behaves exactly as today.

## Technical Considerations

- **Source-scoped Ang is a correctness requirement**: page 1 exists in 10 of 12 sources; without scoping, Ang results interleave granths.
- The 0-as-All sentinel avoids nullable `copyWith` clearing semantics; documented on the state fields.
- English search only covers lines that have an English translation (SGGS via the enrich step); lines without one simply do not match - same as STTM searching its `Translations` field.
- The FTS table indexes only Gurmukhi + first letters; English deliberately uses `LIKE` (measured fast enough).
- Digits typed in first-letter modes remain literal (no auto-switch to Ang) - STTM keeps types explicit, and the flow analysis flagged auto-switching as surprise behaviour.

## Flow decisions (from flow analysis, each resolved)

- **Filter change re-runs the active query** - `setWriterFilter` / `setSectionFilter` / `setSourceFilter` call `search(state.query)` exactly like `setMode` does today.
- **Mode switch keeps the query and re-runs it** (STTM behaviour); "123" searched as first letters just yields few/no results. No programmatic query clearing, so no `TextEditingController` is needed (YAGNI).
- **Ang + Source "All" means SGGS**: `searchAng` uses `sourceFilter == 0 ? 1 : sourceFilter`; the Ang hint says "Ang number (Sri Guru Granth Sahib - pick a Source to change)".
- **Writer and Raag dropdowns are disabled in Ang mode** - a page listing with filter holes is confusing; only Source applies to Ang.
- **Ang input validation**: non-numeric, zero, or negative input yields empty results; out-of-range pages return empty naturally. Never a parse crash.
- **English `LIKE` wildcards are escaped** (`%`, `_`, and the escape char) before building the query.
- **No debounce for now**: every mode already searches per keystroke and English measured 11-44ms; revisit only if typing feels janky on the target machine.
- **Distinct empty states**: a computed `emptyStateText` getter on `PresenterState` (testable one-liner over existing fields) - empty query shows the per-mode prompt; a non-empty query with zero results shows "No results", appending "with filters active" when any filter is set.
- **English results show why they matched**: `SearchResult` gains a `translation` field populated **only by `searchEnglish`** (its query joins translations anyway; the other modes leave it empty so they pay no extra join). The result tile shows the English line beneath the Gurmukhi when it is non-empty. Lines without an English translation cannot match; English mode plus a non-SGGS Source filter is therefore legitimately empty and the empty state covers it.
- **Filters survive mode switches** (session-scoped); each dropdown's "All" entry is the reset - no separate reset button for three dropdowns.
- **Enter opens the first result** (STTM's handleEnter): `onSubmitted` selects `results.first` when non-empty; the existing nav-focus listener then takes the keyboard back for line navigation.
- Single-character words remain dropped by the Gurmukhi full-text tokenizer (existing behaviour); the "No results" state now makes that visible instead of silent.

## Implementation Steps

1. **Fixture** - `test/helpers/test_corpus.dart`: add `source_id` to the fixture `shabads`, add a `sources` table (two sources), and a same-page line in a second source to prove Ang scoping.
2. **Data layer** - the shared filter helper + `searchEnglish` + `searchAng` + option lists in `gurbani_database.dart`, with DB tests (English match, **English query containing `%` and `_` stays literal**, Ang collision stays scoped, filters narrow, option lists).
3. **State + cubit** - the enum split, filter fields, `emptyStateText`, exhaustive dispatch + setters, with cubit tests (mode dispatch incl. invalid Ang input, filter re-run, empty-state text).
4. **View** - dropdown + per-mode hints + filter row (Writer/Raag disabled in Ang mode) + distinct empty states + English snippet on tiles + Enter-opens-first-result, all in `search_pane.dart`, **plus a widget test** (`test/presenter/search_pane_test.dart`) covering the per-mode hint, Ang-mode disabled dropdowns, both empty states, the English snippet, and Enter opening the first result.
5. **Verify** - analyze, full test suite, hot-restart the app; then the review loop (cross-review, ponytail-review) and a marionette UI test for: pick English mode, search a word, select a result; pick Ang mode, enter a number, see the page's lines.

## Success Criteria

```success-criteria
GOAL: The presenter searches by first letters (start/anywhere), full Gurmukhi words, full English words, and Ang (source-scoped), narrowed by writer/raag/source filters, matching STTM behaviour.

SUCCESS CRITERIA:
- All five search modes return correct results on the fixture, including the Ang source-collision case | verify: cd gurbani_live && flutter test test/data/gurbani_database_test.dart
- Mode dispatch, filter re-run, and invalid-Ang handling behave per plan | verify: cd gurbani_live && flutter test test/presenter/presenter_cubit_test.dart
- Static analysis is clean | verify: cd gurbani_live && flutter analyze
- The whole suite passes | verify: cd gurbani_live && flutter test
- The search pane shows the five-type dropdown + three filter dropdowns and drives results end to end | verify: manual 1) run the app 2) choose Full word (English), type "beloved", results appear, tap opens the shabad 3) choose Ang, type 917, the page's lines list in order 4) set Writer filter, results narrow, set back to All 5) type a query and press Enter - the first result's shabad opens

NON-GOALS:
- STTM's "Main letters" and "Romanized first letters" search types (deferred).
- Persisting search type or filters across restarts (session-scoped, like STTM).
- An FTS index for English (measured unnecessary: 11-44ms).
- The A7 home-verse / intelligent-spacebar work (chunk 2).

VERIFICATION COMMAND: cd gurbani_live && flutter analyze && flutter test
```

## Success Metrics

- Every STTM search flow an operator uses daily works locally with no behavioural surprises.
- English and Ang queries return in well under 100ms on the bundled corpus.

## Dependencies & Risks

- None external; all data is already bundled.
- Risk: the `SearchMode` enum rename touches existing tests and the settings-free chip UI; contained by doing state + view in one step with the tests updated alongside.

## References & Research

- STTM search types: `tmp/sttm-desktop/www/main/common/constants/banidb.js` (SEARCH_TYPES 0,1,2,3,4).
- STTM ang + english queries: `tmp/sttm-desktop/www/main/banidb/realm-search.js` (`query()` cases ANG / ENGLISH_WORD).
- STTM filter row: `tmp/sttm-desktop/www/main/navigator/search/components/SearchContent.jsx` (FilterDropdown Writer/Raag/Source).
- Existing patterns: `lib/data/gurbani_database.dart` (`_searchCols`, `searchFirstLetters`), `lib/presenter/view/bani_drawer.dart` (view reads DB option lists directly).
- English LIKE benchmark: 60,555 rows, 11-44ms (this plan, measured 2026-07-16).
