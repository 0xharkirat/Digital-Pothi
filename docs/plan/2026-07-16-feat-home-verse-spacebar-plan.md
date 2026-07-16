# feat: home verse + intelligent spacebar (A7)

**Date:** 2026-07-16 · **Type:** enhancement · **Epic:** A7 (backlog/epic-a-presenter-parity.md)
**Brainstorm:** docs/brainstorm/2026-07-16-home-verse-spacebar-brainstorm-doc.md (grill findings folded in)
**Ground truth:** STTM `www/main/navigator/shabad/utils/change-verse.js`, `change-home-verse.js`, `ShabadVerse.jsx`, `save-to-history.js`
**Plan review:** flow-analysis + simplicity + VGV agents ran 2026-07-16; all findings folded below. Scope is one PR (no split needed: one cubit, two views, tests).

## Summary

Per-shabad home verse (asthaai) with STTM's intelligent spacebar: space resumes the antara run from home, advances within a couplet, and snaps back home at each `source_line` boundary.
Home defaults to the opened-at line and is changeable from the shabad pane.
The ਰਹਾਉ line is badged.
Arrows stay plain.
Setting-gated, on by default, persisted.

## Locked decisions and documented deviations

1. STTM semantics, with three corpus/UX-verified deviations:
   - Header-skip uses `Verse.isHeader` (`type_id IN (1, 2)`) instead of STTM's text regexes (grill-verified strictly better).
   - Home index 0 is valid (STTM's `if (homeVerse)` falsy bug is not copied).
   - At-home is DERIVED (`current == homeIndex`), not a stored flag. STTM stores it and never updates it on manual nav, which produces two dead-press warts (arrow onto home → space visually no-ops; arrow away → space teleports to the stale resume pointer instead of advancing from the displayed line). Deriving kills both, drops a state field, and keeps the alternation algorithm identical when only space is used.
2. Setting OFF: space snaps straight to home (STTM). No home loaded (bani, quick-insert): space falls back to plain next line.
3. Manual nav (arrows, taps) never writes the spacebar bookkeeping - `advance()` and the shabad-load path are the only writers of `resumeIndex`/`homeIndex`.
4. Known punt: quick-inserts REPLACE `state.shabad` today (`_showSpecial`), so Esc/Waheguru mid-kirtan drops the shabad and space goes dead until the operator reopens via History. STTM keeps the shabad under its slides. Fixing that means making quick-inserts a display override - out of scope here, filed as a backlog follow-up at closeout. Pinned by a trace test so the behavior is a decision, not a surprise.

## The algorithm (port spec)

State: `homeIndex` (-1 = none, `current = -1` house convention), `resumeIndex` (-1 = none; STTM's `previousVerseIndex` - the antara-run resume pointer, NOT "the verse shown before"), `intelligentSpacebar` (persisted, default true).

`advance()` (STTM's intelligent spacebar; space maps to it):

```text
if homeIndex == -1            -> nextLine(), done          # banis / quick-inserts
if !intelligentSpacebar       -> show(homeIndex), done     # plain snap home
if current == homeIndex:                                   # at home (derived)
  next = resumeIndex == -1 ? 0 : resumeIndex + 1
  if next >= n: next = 0
  next = skipHeaders(next)
  if next == homeIndex: next = (next + 1) % n              # STTM steps past home, no header re-skip; we guard the overflow
  resumeIndex = next; show(next)
else:
  cand = current + 1
  if cand >= n: cand = 0                                   # STTM wraps via its undefined-index guard, WITHOUT header-skip
  else: cand = skipHeaders(cand)
  if sameSourceLine(shabad[current], shabad[cand]):
    resumeIndex = cand; show(cand)                         # walk the couplet
  else:
    show(homeIndex)                                        # snap home; resumeIndex untouched
```

`show(i)` here means ONE emission carrying `current: i`, the resolved display, `following: false` (space must disengage AI-follow exactly like `showLine` does today), and the bookkeeping - never `showLine` followed by a second bookkeeping emit.

`skipHeaders(i)`: `while (i < n - 1 && shabad[i].isHeader) i++`.
STTM caps at two skips (one ascription + one ੴ); the type-driven loop covers longer header runs (Dasam) and is clamped so it always lands on a real line.

`sameSourceLine(a, b)`: `a.sourceLine != null && a.sourceLine == b.sourceLine` - NULL never equals anything, so Dasam (unpopulated `source_line`) degrades to strict alternation.

Shabad load: `_showLineOf` has SIX callers (selectResult, openHistory, openFavorite, nextShabad, prevShabad, showTrackerVerse).
Init `homeIndex = opened index, resumeIndex = -1` ONLY on an actual shabad swap (compare the incoming shabad id to the loaded one); a same-shabad call (tracker moving within the shabad, re-tapping a search hit) preserves both - otherwise AI-follow makes home chase the sung line, and STTM likewise resets `previousIndex` only when `clickedShabad !== activeShabadId`.
`nextShabad`/`prevShabad` always swap, so they re-init naturally.
`showBani` / `_showSpecial`: `homeIndex = -1, resumeIndex = -1`.
`setHome(i)`: bounds-guarded (`showLine`-style no-op outside range), sets `homeIndex` only.

## Keyboard focus guard (pre-existing bug, fixed here)

The body-level `Focus` in `presenter_keyboard.dart` receives key events bubbling up from the focused search `TextField`, so space/arrows currently fire nav while typing (and a handled space never reaches the IME - the query loses its space).
This feature makes that fatal (space mid-query would yank the projector), so `_onKey` gains a first-line guard: if the primary focus sits inside an `EditableText` (`FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null`), return ignored.
Only text fields opt out; button focus keeps bubbling as today.

## Files (review order)

1. `lib/presenter/cubit/presenter_cubit.dart` - `advance()`, `setHome`, `_skipHeaders`, same-shabad-aware init in `_showLineOf`, `_kIntelligentSpacebar` pref (`getBool ?? true`, vishraam is the default-true analog), `toggleIntelligentSpacebar`.
2. `lib/presenter/cubit/presenter_state.dart` - `homeIndex`, `resumeIndex`, `intelligentSpacebar` + props/copyWith; doc comments carry the STTM name mapping.
3. `lib/engine/corpus.dart` - `Verse` gains `typeId` (default 4) + `sourceLine` (nullable) as optional named params, BOTH added to `props`, plus `bool get isHeader` (Sirlekh + Manglacharan) and `bool get isRahao` (gurmukhi contains ਰਹਾਉ) so corpus semantics live on the model, not in cubit/view.
4. `lib/data/gurbani_database.dart` - `_cols` selects `l.type_id, l.source_line`; `_toVerses` maps them (sg bani lines keep defaults).
5. `lib/presenter/view/presenter_keyboard.dart` - EditableText focus guard; space routes to `cubit.advance()`; arrows unchanged.
6. `lib/presenter/view/shabad_view.dart` - `buildWhen` gains `homeIndex`; `_LineRow`: trailing home IconButton (filled when home, faint otherwise, tooltip 'Set home line'), ਰਹਾਉ chip via `verse.isRahao`.
7. `lib/presenter/view/settings_drawer.dart` - `buildWhen` gains `intelligentSpacebar`; add a third `_Toggle` in the DISPLAY `Wrap` (house convention - no SwitchListTile).
8. `test/helpers/test_corpus.dart` - fixture lines gain `type_id` / `source_line`; add a kirtan-shaped shabad: [Sirlekh l1, Manglacharan l1, P l2, P l2, Rahao l3 (text contains ਰਹਾਉ), P l4, P l4].
9. `test/data/gurbani_database_test.dart` - verses carry exact typeId/sourceLine values per line.
10. `test/presenter/presenter_cubit_test.dart` - the trace replays below.
11. `test/presenter/presenter_keyboard_test.dart` - space reaches `advance()` (outcome distinguishable from `nextLine`: snap-home from a couplet boundary); space while search field focused types a space and leaves `current` alone.
12. `test/presenter/shabad_view_test.dart` (new; the view has no widget test today) - rahao badge renders; tapping a row's home icon repaints the filled icon onto that row (assert the ICON moved, not just cubit state).
13. `tools/ui_test_search.py` - append a spacebar section (open shabad, space twice, assert alternation) - space is a raw `Focus` key, so marionette `press_key` reaches it, unlike the TextField IME path.

## Test traces (cubit, on the kirtan fixture, home = rahao index 4)

Core alternation:

- Resume: space → skips headers to index 2, resumeIndex=2.
- Couplet walk: space → 3 (same source_line), resumeIndex=3.
- Snap: space → source_line changes → home (4), resumeIndex stays 3.
- Past-home collision: space → resume+1 = 4 == home → 5 (no header re-skip after the bump).
- Wrap: from 6, space → cand wraps to 0 (Sirlekh, l1 ≠ l4, no skip on wrap) → snap home.
- Index-0 home: open at line 0, space works (no falsy bug).
- Setting off: space → straight to home from anywhere.
- No home: `showBani` then space → plain next line; Esc (quick-insert) then space → no-op (decision 4 pinned).
- Single-line shabad: home is the only line → space no-ops (collision guard `% 1` lands home).

Interaction with manual nav / follow / load paths:

- Arrow away mid-run, space → advances from the DISPLAYED line (derived at-home), resumeIndex follows.
- Arrow ONTO home, space → resumes the run (no dead press).
- setHome on the displayed line, space → resume branch from resumeIndex.
- setHome while away → subsequent snap goes to the new home; out-of-range setHome no-ops.
- Space while following → following turns off (single emission).
- Tracker move within the same shabad preserves homeIndex/resumeIndex; tracker/pageDown crossing shabads re-inits home to the entry line.
- Persistence: `intelligentSpacebar` toggle survives a cubit rebuild.

## Success criteria

```success-criteria
- All cubit traces above pass.
  verify: cd gurbani_live && flutter test test/presenter/presenter_cubit_test.dart
- Keyboard: space routes to advance(); typing in search keeps its spaces.
  verify: cd gurbani_live && flutter test test/presenter/presenter_keyboard_test.dart
- Widget: rahao badge renders; home icon repaints on tap.
  verify: cd gurbani_live && flutter test test/presenter/shabad_view_test.dart
- Analyzer + full suite green.
  verify: cd gurbani_live && flutter analyze && flutter test
- Live UI: space alternates away/home on a real shabad.
  verify: manual - python3 tools/ui_test_search.py <vm-ws-uri> (spacebar section PASS)
```

## Out of scope

B6 tracker-suggests-home, ceremonies/banis intelligent space, versesRead checkmarks, copy-to-clipboard, output-window home indicator, quick-insert-as-display-override (decision 4 follow-up).
