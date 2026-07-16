# Home Verse + Intelligent Spacebar (Epic A7) - Brainstorm

**Date:** 2026-07-16
**Status:** decisions locked (carried from the 2026-07-16 search-parity brainstorm session)
**Ground truth:** STTM desktop source at `tmp/sttm-desktop`

## Problem

Kirtan alternates between the asthaai (the home line, usually the ਰਹਾਉ line) and the antras (the other verses).
The operator wants the display to snap back to home automatically instead of arrowing up and down.
STTM solves this with a per-shabad home-verse marker plus an "intelligent spacebar".
We only have plain space = next line today.
This is the manual counterpart of our AI auto-follow, and useful whenever the tracker is off.

## STTM ground truth

All from `tmp/sttm-desktop/www/main/navigator/shabad/`:

- Every verse row renders a trailing home icon (`ShabadVerse.jsx`): filled on the current home line, hover-revealed on the rest; clicking it calls `changeHomeVerse(lineNumber)` (`utils/change-home-verse.js`, a plain setter).
- `homeVerse` initializes to the opened-at verse index (`utils/save-to-history.js`: `homeVerse: firstVerseIndex`).
- Space fires the `homeVerse` shortcut which calls `intelligentNextVerse` (`utils/change-verse.js`):
  - `intelligentSpacebar` setting OFF: space snaps straight to the home verse.
  - ON and `atHome`: resume the verse run at `previousVerseIndex + 1` (null or overflow wraps to 0), apply `skipMangla`, and if that lands on home, step one past it; then `atHome = false`.
  - ON and not `atHome`: candidate = `skipMangla(current + 1)` (wrap to 0 at the end); if `candidate.lineNo != current.lineNo` (the next verse starts a new physical line) snap to home and set `atHome = true`; otherwise advance and record `previousVerseIndex = candidate`.
  - `skipMangla` skips ascription lines (ਮਹਲਾ / ਮਃ anywhere, ਸਲੋਕੁ at index 0) and then a non-first Ik Onkar (ੴ) line - STTM matches these against its ASCII-font text.
- `lineNo` is the physical line on the ang. Our corpus already has it: `lines.source_line`.
- Manual navigation (arrows, taps) does NOT touch `atHome` / `previousVerseIndex` in STTM - the not-at-home branch advances from the displayed line anyway, so manual nav composes without extra bookkeeping. Port exact: `spacebar()` is the only writer of those fields besides shabad load.
- STTM bug we will NOT copy: `if (homeVerse)` treats home index 0 as unset, so space goes dead when the first line is home. Ours: nullable int where 0 is valid.

## Grill findings (corpus-verified, 2026-07-16)

- `line_types` exists: 1 = Manglacharan, 2 = Sirlekh, 3 = Rahao, 4 = Pankti. **skipMangla ports as `type_id IN (1, 2)`** instead of STTM's regexes - verified strictly better: the regex would false-skip 9 genuine verse lines that merely mention ਮਹਲਾ/ਸਲੋਕੁ (they are type 4), and it misses Dasam chhand headers (ਭੁਜੰਗ ਪ੍ਰਯਾਤ ਛੰਦ ॥ etc., all type 2) that space should skip. Same intent as STTM (skip non-sung header lines), better data. Deliberate deviation, documented here.
- Rahao badge: badge lines whose `gurmukhi_uni` contains ਰਹਾਉ (2,700 lines - the actual pause lines, including ਰਹਾਉ ਦੂਜਾ). `type_id = 3` alone is too broad (5,406 rows - it marks the whole rahao couple, not just the marked line). No DB change needed for the badge: the view checks the verse text.
- NULL `source_line`: 66,974 rows, all but 17 in Dasam Granth (source 2); SGGS is fully populated. Rule: NULL is never equal to anything (including another NULL), so any transition involving NULL snaps home - Dasam shabads degrade to strict line-by-line alternation, which is the honest fallback.
- Anand Sahib confirms the lineNo semantics: antara couplets share a `source_line` (rows pair 2-2, 3-3, 4-4), so space walks the couplet then snaps home - the boundary rule IS the antara boundary, not an artifact.
- `Verse` (lib/engine/corpus.dart) needs `typeId` + `sourceLine` as optional fields; construction sites are few (2 in gurbani_database, 1 quick-insert, engine/test fixtures) and all compile unchanged with defaults.

## Locked decisions (user, chunk-1 brainstorm session)

1. STTM intelligent spacebar semantics, exact (including skipMangla and the lineNo snap-back rule).
2. Setting-gated, ON by default. Arrows stay plain next / prev line.
3. Home = the opened-at line, changeable by clicking the row's home icon.
4. The ਰਹਾਉ line gets a visible badge in the operator shabad pane.

## Scope

In:

- `PresenterState`: `homeIndex` (nullable, per loaded shabad), `atHome`, `previousVerseIndex`, `intelligentSpacebar` (persisted setting).
- `PresenterCubit`: `spacebar()` implementing the STTM algorithm; `setHome(index)`; home resets to the opened-at index on every shabad load; manual nav leaves the spacebar bookkeeping untouched (STTM-exact).
- `skipMangla` port as `type_id IN (1, 2)` (see grill findings).
- Shabad pane: per-row home icon (filled = home), ਰਹਾਉ badge on lines containing ਰਹਾਉ.
- Keyboard: space routes to `spacebar()`; arrows unchanged.
- Settings drawer: "Intelligent spacebar" toggle, persisted.
- Fallback: no home (quick-insert slides, Sundar Gutka banis) → space = plain next line, exactly today's behavior.
- Unit + widget tests porting the STTM traces; a marionette step driving space E2E (space is a raw key handled by `Focus`, so `press_key` reaches it - unlike the TextField IME path).

Out:

- B6 tracker-suggests-home integration (later, on top of this state).
- Intelligent space inside banis / ceremonies (home is a shabad concept; banis fall back to plain).
- STTM's versesRead checkmarks and copy-to-clipboard (separate backlog items).

## Approaches

**Extend PresenterCubit/PresenterState (chosen)** - home state lives and dies with the loaded shabad, which already lives in `PresenterState`; one `spacebar()` method, no new layers.

- Pros: smallest diff, state resets naturally on shabad load, testable with the existing harness.
- Cons: PresenterState grows three fields.

**Separate HomeCubit** - rejected: the state is per-shabad and would need to mirror shabad loads across cubits for no benefit.

## Edge cases

- Home index 0 must work (the STTM falsy bug).
- Resume landing on home steps past it; overflow wraps to 0 (STTM-exact).
- A shabad where consecutive rows share `source_line` advances through them before snapping (that is the point of the lineNo rule).
- `source_line` NULL rows (corpus has some): treat NULL as its own boundary - a NULL-to-anything transition snaps home.
- Changing home while away from it must not corrupt `previousVerseIndex`.
- Setting OFF: space = snap to home when a home exists, else plain next line.

## Success criteria sketch

- Unit tests replay the STTM alternation trace on a fixture shabad (home, antra run, snap-back, wrap, skipMangla, index-0 home).
- `flutter analyze` and `flutter test` green.
- Marionette: open a shabad, press space twice, assert the active line alternates away and back home.
