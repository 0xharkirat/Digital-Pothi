# Plan: wire the on-device Gurbani DB into the app (local-only)

## Context
Today the app loads one bani as a bundled JSON (`assets/corpus/japji_unicode.json`, ~385 lines)
into memory and O(N)-scans it per chunk (~8 s/chunk at full-GGS scale — unusable). We built
`gurbani-slim.sqlite` (46 MB, 141,264 lines, all sources, Unicode `gurmukhi_uni`, indexed
`first_letters_uni`, FTS5, `shabad`/`bani` structure). Wire it in, fully offline.

## Non-negotiable invariant (from review)
**The `VerseTracker` / `LineChecker` must never see more than one bani's or one shabad's lines.**
They O(N)-scan their input; handing them the 141k-line corpus resurrects the 8 s/chunk scan the DB
was meant to kill. The DB does the wide search (indexed); the followers only ever run over a small
loaded slice.

## Approach (decided calls)
- **Query lib: `sqlite3` + `sqlite3_flutter_libs`** (bundles SQLite *with FTS5*; platform SQLite is
  unreliable). Raw SQL, read-only. **Not `drift`** (codegen overkill).
- **`GurbaniDatabase`** (data-layer client — path in, rows out; named for what it is, not "repository"):
  - `baniLines(baniId)` → a bani's ordered lines (replaces the JSON load).
  - `shabadLines(shabadId)` → a shabad's ordered lines (Phase B anchor).
  - `locate(firstLetters)` → candidate `LocateHit(shabadId, lineText, orderId)` (Phase B locator).
  - Opened once, app-scoped, provided via `RepositoryProvider` at the app root; disposed there, **not**
    in `Cubit.close()`. `Verse` gains **no** DB fields — `shabadId` rides on `LocateHit`.
- **`Verse.normalized` stays produced by the Dart `normalize()`** over `gurmukhi_uni`. DB indexes
  (`first_letters_uni`, FTS5) are *locators only*, never the scorer's input.
- **Atomic DB provisioning**: copy asset → temp file → `rename()`; gate on a stored version string so a
  truncated/half-copied 46 MB file can't wedge it. Failures → a `TrackingStatus.corpusError` state,
  caught in the Cubit — never an uncaught throw.

## Implementation Phases (one plan, no PR split — single package, ~400 LOC, phases land together)

### Phase A: bani-from-DB (replaces the JSON corpus, same linear behavior)
- **Scope**: add the dep, bundle the DB, `GurbaniDatabase.open()` + `baniLines()`, inject app-scoped,
  swap `Corpus.loadAsset(json)` → `baniLines(japji)`. Delete the JSON asset + `Corpus.loadAsset` loader.
- **Concurrency**: none — `baniLines` is a one-shot load, not per-chunk.
- **Files**: `pubspec.yaml`, `lib/data/gurbani_database.dart`, `lib/tracking/view/tracking_page.dart`
  (RepositoryProvider), `lib/tracking/cubit/tracking_cubit.dart` (inject + load), `assets/corpus/gurbani.sqlite`
  (gitignored), delete `assets/corpus/japji_unicode.json` + JSON loader.
- **Tests**: `GurbaniDatabase` over an **in-memory** `sqlite3` fixture (CREATE/INSERT in `setUp`, not a
  binary) — `baniLines` returns the bani's lines in order; corpus-open failure surfaces an error.
- **Acceptance**: app still tracks Japji, now from the DB; `flutter analyze` clean, tests pass.

### Phase B: kirtan two-tier (locate → anchor → follower)
- **Scope**: `locate(firstLetters)` (first-letter prefix only; **FTS5 deferred** until 141k ambiguity is
  measured), `shabadLines()`; rewire the mic cold-start to `locate()` (replacing `VerseTracker._cold`),
  build the tracker/`LineChecker` over the fetched shabad's lines. File mode: locate per window (each
  window may be a different shabad).
- **Concurrency (required)**: `locate()` is async inside the sync `_onText` stream listener. Guard with a
  single in-flight flag + `if (isClosed) return;` after every await; drop overlapping locates. If it gets
  hairy, promote to a Bloc with a `droppable()` transformer.
- **Tests**: `blocTest` with a **fake** `GurbaniDatabase` — locate → lock shabad → anchor emits; assert the
  drop-overlapping behavior, not just the happy path.

## Deferred (follow-up tickets, not this work)
- Trim redundant ASCII columns (~46 → ~30 MB); note bundle + runtime copy ≈ double on-device storage.
- One-time download instead of bundling.
- FTS5 phrase search — add only if first-letter-only locate is measured too ambiguous at 141k.
