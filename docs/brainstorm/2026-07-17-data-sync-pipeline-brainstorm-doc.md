# Data Sync Pipeline (D2 + D3) - Brainstorm

**Date:** 2026-07-17
**Problem:** keep our DB's advantages (Unicode, global order_id, type_id, baked transliterations, FTS5, offline versioned pipeline) while staying in sync with upstreams, and guarantee upstream updates can never break the app or the user's saved data.
**Ground truth:** docs/DB-COMPARISON.md (empirical realm/ShabadOS/ours matrix), tools/enrich_corpus.py, tools/fetch_bani_lengths.py, tmp/shabados-db/ artifacts.

## The upstreams (verified)

| Upstream | What we take | Versioning | Change risk |
|---|---|---|---|
| `@shabados/database` (npm, GPL-3.0) | base corpus: lines/shabads/writers/sections/sources, translations (en.ssk, pu.ss), transliterations (roman, devnagri) | semver; we hold `4.8.7.tgz` AND `5.0.0-next.0.tgz` in tmp/shabados-db | **A major bump is already published as -next.** Text corrections, visraam edits, possible schema changes on 5.x. Their 4-char line/shabad IDs are designed permanent (enrich header verified 141,264/141,264 ID overlap). |
| BaniDB API (v2) | bani lengths + bani lines (sundar_gutka.sqlite); future: panthic texts (~900 lines), extra translations (en.ms/bdb, pu.ft, es.sn, hi.*), per-source visraam JSON | unversioned REST | Silent drift; needs snapshotting at bake time. |
| STTM realm (local snapshot) | reference only: derived fold map, ceremony sequences (D1), verification oracle | blob re-published ad hoc | Not a sync target; re-dump manually when their app updates. |

## Grill findings (things that are broken or unreproducible TODAY)

1. **The base-corpus build is not scripted.** `enrich_corpus.py` (translations) and `fetch_bani_lengths.py` (SG) exist, but the step that turns ShabadOS `master.sqlite` into our `gurbani.sqlite` (slimming, `gurmukhi_uni`, `first_letters_uni`, FTS5, indexes) was done ad hoc and lives nowhere. Today we cannot rebuild our own DB from upstream. This is the root risk - everything else layers on it.
2. **Custom SG bani ids collide with BaniDB's id space.** We minted 1006 (Anand Bhog) and 1007 (Salok) assuming BaniDB stops at ~107; the realm shows BaniDB bani ids 1000 and 10037..10082 in live use. A future `fetch_bani_lengths.py` run against a grown BaniDB can silently collide. Customs must move to a reserved range (negative ids) at next bake.
3. **User data embeds corpus identity.** shared_preferences history/favorites store `lineId` (ShabadOS 4-char ids, plus synthetic `sg:<baniId>:<seq>` for banis). ID permanence upstream is a promise, not a contract - an update that drops/renames an id orphans saved entries silently.
4. **The app↔DB contract is implicit.** `GurbaniDatabase._version = '6'` gates the asset copy, but the DB carries no metadata (schema version, upstream tags, build date, content hash) and the app asserts nothing about what it opens.
5. **The fold map is now derived data with no fixture.** `_romanClasses` came from a realm dump; nothing re-checks it if the realm updates or someone edits the map.
6. **License coupling (feeds the pending LICENSE decision):** bundling GPL-3.0 ShabadOS data means the shipped app is effectively GPL-3.0 (enrich_corpus.py header already says so). STTM itself is GPL. Repo license should be GPL-3.0 outright - simplest honest option - unless the data moves to download-only.

## Approaches

**A. Canonical-schema ETL with pinned inputs (chosen)**

Our schema is the product; upstreams are inputs to a deterministic bake.
One `tools/build_corpus.py` pipeline: ingest (pinned tgz + BaniDB snapshot dir) → transform (our DDL, versioned) → derive (uni first letters, FTS, customs in reserved id range) → validate (golden gate) → stamp (`db_meta` table).
A `tools/diff_corpus.py` gates upgrades: id churn, text deltas, count drift - reviewed before any new DB ships.
The app reads `db_meta` and refuses schema majors it doesn't know; a tiny fingerprint remap heals user data if an id ever vanishes.

- Pros: keeps every advantage we have; upgrades become a reviewed diff, not a surprise; reproducible from a clean checkout; CI-able (E1).
- Cons: one honest chunk of work now (the unscripted base build must be written).
- Best when: the schema is the app's contract - which it already is.

**B. Track ShabadOS schema directly** - rejected.
Their 5.x schema changes would ripple into app queries; we'd inherit their slicing and lose order_id/type_id/FTS control.
**C. Adopt STTM's realm as the source** - rejected.
Closed pipeline, ASCII-only, no reading order, undocumented publishing; useful as an oracle, unusable as a base.

## Sync cadence (how "keeping in sync" actually works)

- ShabadOS: watch releases; on a new tag, drop the tgz into `tmp/shabados-db/`, run bake + diff, read the report, bump `db_meta.content` + app `_version`, ship. Majors (5.x) additionally run the schema-mapping layer of `build_corpus.py` and the golden gate proves the app contract held.
- BaniDB: bake-time snapshots (`tools/data/banidb-snapshot-<date>/*.json`, committed) make SG rebuilds reproducible and diffable; refresh the snapshot deliberately, never implicitly.
- STTM realm: manual re-dump when their app updates; the fold-map fixture test fails loudly if their fold ever changes.

## Update distribution (D2) - decision needed

1. **Bundled-only:** every data refresh is an app release. Purest local-only; slowest to users.
2. **Manual in-app update check:** a Settings button fetches a signed manifest (version, sha256, minSchema) and downloads the DB - network touched only on explicit user action, like the model download.
3. Auto-check on launch - rejected: violates the local-only principle.

## Ceremony content source (D1 follow-on) - decision needed

1. **Extract from the STTM realm** (sequences + their 17 curated HTML interludes), shipped with credit - fastest, exact parity; carries their English editorial text (GPL, credited).
2. **Rebuild from BaniDB**: same verse sequences via BaniDB ceremonies endpoints, write our own interlude text - more work, fully ours.

## Success criteria sketch

- `build_corpus.py` from a clean checkout reproduces byte-stable logical content (same content hash) from the pinned inputs.
- `diff_corpus.py` on 4.8.7 → 5.0.0-next produces a human-readable report; the golden gate passes or fails loudly.
- App refuses a DB with an unknown schema major; history/favorites survive a simulated id removal via the fingerprint remap.
- Fold-map fixture test pins `_romanClasses` to the committed realm-derived pairs.
