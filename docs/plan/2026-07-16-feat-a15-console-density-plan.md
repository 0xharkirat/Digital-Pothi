# feat: A15 operator console density pass

**Date:** 2026-07-16 · **Issue:** #42 · **PR branch:** feat/a15-console-density
**Ground truth:** the two side-by-side screenshots + STTM source (`SearchHeader.jsx`, `SearchFooter.jsx`, `_header.scss` rail `width: 40px`, `_search.scss` input `height: 40px` / ang `input[type=number] max-width: 80px`).
**User directive:** "as close to sttm".

## Diagnosis (from #42)

Form components doing toolbar jobs + an AppBar title row + outline noise + margin-stacked cards.
STTM verified: 40px icon rail, one toggles row (language radios + contextual type checkboxes), a bare input with a small side Ang number box, weightless text filters, full-bleed panes split by luminance, and a footer that is a per-source colour legend + result count (static spans, not buttons).

## Changes

1. `lib/presenter/view/presenter_view.dart`
   - AppBar deleted. New `_IconRail` (40px, `surfaceContainerLowest`): book icon → openDrawer, gear pinned bottom → openEndDrawer. Rail + content in a Row; works in both wide and narrow layouts.
   - `_Pane` loses margin/radius/card colour → plain padding; panes separated by 1px dividers; `_DisplayPaneHost` full-bleed (no margin/radius).
2. `lib/presenter/view/search_pane.dart` (rewrite, becomes Stateful for the two text controllers)
   - Row 1: language chips [ਗੁਰਮੁਖੀ|English] + type chips (gr: First letter start / anywhere, Full word; en: Full word only) - one ~32px row, STTM's header.
   - Row 2: dense search field (40px, filled, no outline) + 80px Ang number box (STTM's side input). Ang box non-empty → mode=ang + that query; cleared → back to the chip mode + main query. The mode dropdown is deleted.
   - Row 3: right-aligned "Filter by  Writer ▾ Raag ▾ Source ▾" text-button popups (accent + name when active, Writer/Raag disabled while ang). FormField filters deleted.
   - Results: tile accent bar coloured per source; margins 6→4, padding 10→8.
   - Footer strip: per-source colour legend for sources present + "N results" ("100+" at the query LIMIT).
   - Keys: `search_field` kept; new `ang_field`, `lang_gr`, `lang_en`, `type_first_start`, `type_first_anywhere`, `type_full_word`; `filter_*` kept.
3. `lib/data/gurbani_database.dart` + model: `SearchResult.sourceId` (default 0), `sh.source_id AS src` in `_searchSelect`, mapped in `_toResults`.
4. `lib/theme/app_theme.dart`: `visualDensity: VisualDensity.compact` on the ThemeData; source-colour map (SGGS kesari, Dasam blue, Amrit Keertan teal, other gray) exposed for tiles + legend.
5. `lib/presenter/view/shabad_view.dart`: `_LineRow` → Stateful with MouseRegion; home IconButton visible on hover or when home (STTM hover-reveal); row vertical padding 12→8.
6. Narrow layout keeps the rail; stacked sections unchanged otherwise.

## Behavior invariants (must not change)

Mode dispatch and filter re-run semantics in the cubit; Enter opens first result; keyboard nav + spacebar; ang ignores Writer/Raag; empty-state texts; persistence.
Cubit is untouched except nothing - this is a view-layer pass.

## Tests

- `test/presenter/search_pane_test.dart`: pickMode rewritten to chip taps + ang via `ang_field`; assertions otherwise identical (hints, disabled filters in ang, empty states, English snippet, Enter).
- `test/presenter/shabad_view_test.dart`: home-icon tests hover first (mouse gesture); badge test unchanged.
- New: footer count renders; source legend shows only present sources.
- `tools/ui_test_search.py`: pick_mode → chip taps; ang step uses `ang_field`; spacebar section unchanged.

```success-criteria
- flutter analyze && flutter test green (107+).
  verify: cd gurbani_live && flutter analyze && flutter test
- Marionette suite passes end-to-end on the rebuilt UI.
  verify: manual - python3 tools/ui_test_search.py <vm-ws-uri>
- Visual: first result lands ≤190px from the window top (was ~290); zero outlined boxes above the results except the search input.
  verify: manual - screenshot compare vs the #42 screenshots
```

## Out of scope

Workspaces tabs (A10), themes (A2), voice-search mic button, Gurmukhi on-screen keyboard, per-source result counts in the footer (legend + total only - counting facets needs an extra GROUP BY query; add with A10 if wanted).
