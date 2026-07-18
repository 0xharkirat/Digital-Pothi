# feat: reproducible data pipeline + safe upstream sync (D2 + D3)

**Date:** 2026-07-17 · **Issues:** #31 (D2), #32 (D3), feeds #30 (D1) · **Brainstorm:** docs/brainstorm/2026-07-17-data-sync-pipeline-brainstorm-doc.md
**Locked decisions (user, 2026-07-17):** manual in-app update check (network only on explicit click); ceremonies extracted from the STTM realm with credit; repo license **GPL-3.0** (closes the pending LICENSE question - bundled ShabadOS data is GPL).

## Why now

The base-corpus build is unreproducible (no script), ShabadOS has `5.0.0-next` published (a breaking major is coming), our custom SG ids sit inside BaniDB's real id space (realm shows 1000 and 10037+ in use), and saved history/favorites embed corpus ids with no healing path.
Everything below turns "we hope upstream doesn't move" into "upstream moves through a reviewed gate".

## Phase 1 - make the bake reproducible (D3 core)

`tools/build_corpus.py` - one deterministic pipeline, replacing the ad hoc base build and absorbing `enrich_corpus.py`:

1. **Ingest (pinned):** reads `tools/pins.json` - `{shabados_tgz, shabados_sha256, banidb_snapshot_dir}`. The 4.8.7 tgz moves from tmp/ into a documented fetch step (`tools/fetch_upstreams.py` downloads + sha-checks it; the tgz itself stays out of git, the pin + hash live in git).
2. **Transform:** our DDL from `tools/schema/corpus.sql` (single source of truth, `schema_semver` constant): lines (id, shabad_id, gurmukhi + gurmukhi_uni, source_page, source_line, first_letters, first_letters_uni, type_id, order_id), shabads, writers, sections, sources, line_types, translations, transliterations.
3. **Derive:** first_letters_uni, FTS5 + indexes; SG bake folds in here too (`fetch_bani_lengths.py` gains `--snapshot` mode reading the committed BaniDB JSON snapshot instead of the network; **customs move from 1006/1007 to reserved negative ids (-1, -2)** with a one-line app mapping migration).
4. **Validate (golden gate),** fails the build loudly:
   - counts within ±0.5% of the pinned baseline (lines, shabads, per-source);
   - anchor content: ang 1 mool mantar text, Japji line-1 first letters (uni + font), one rahao's type_id, Anand Sahib source_line pairs (the A7 fixture shape);
   - every SG bani non-empty at every declared length; no bani id collisions incl. reserved range;
   - fold-map fixture: `tools/data/fold_pairs.json` (committed, realm-derived) round-trips through `_romanClasses` - fails if either side drifts;
   - FTS returns the known hit for a smoke query.
5. **Stamp:** `db_meta` table - `schema_semver`, `shabados_version`, `banidb_snapshot_date`, `built_at`, `content_sha256` (logical dump hash, byte-stable).

`tools/diff_corpus.py old.sqlite new.sqlite` → markdown report: ids added/removed (**id removal is a red flag gate**), text-changed lines (sampled), count deltas per source, translation coverage deltas.
Run it 4.8.7 → 5.0.0-next as the acceptance proof.

## Phase 2 - app-side contract + user-data healing

- `GurbaniDatabase.open()` reads `db_meta`; unknown `schema_semver` major → corpus-error screen (same path as a missing DB). `_version` copy-gate stays but is derived from `content_sha256` prefix instead of a hand-bumped string.
- **Fingerprint remap:** history/favorites entries already carry (gurmukhi, page). On first open after a content change (`content_sha256` differs from the stamp in prefs), any stored lineId missing from `lines` is remapped by `(source_page, exact gurmukhi)` lookup; unresolvable entries are dropped with a one-line log, never a crash. Synthetic `sg:` ids remap through the -1/-2 custom migration.
- Tests: simulated id removal heals; unknown major refuses; sg custom migration preserves reopened history.

## Phase 3 - manual update check (D2)

- Settings drawer gains "Check for data updates" (explicit click = the only network moment, mirroring the model-download exception to local-only).
- Fetch `manifest.json` from the repo's GitHub releases: `{content_sha256, schema_semver, url, size, sha256}`.
- Compatible major + new hash → download to temp, sha-verify, atomic-rename into the app-support dir (the `_ensure` path already renames atomically), prompt to restart.
- Incompatible major → "update the app to get this data".
- Publishing a data release = CI job (Phase 4) uploading the baked DB + manifest to a GitHub release tagged `data-vX`.

## Phase 3.5 - accuracy program (the reason all of this exists)

The AI work (tracker matching, Phase-4/5 training labels, the livestream eval ground truth) inherits corpus errors as label noise, so accuracy is measured, not assumed:

- **Cross-corpus concordance** (`tools/concordance.py`, shipped now): our ShabadOS text vs BaniDB's (via the realm dump). Baseline measured 2026-07-17 on all 60,555 SGGS lines: **99.03% exact after normalization, 453 slicing-only differences (line-split policy, not text), 135 true text deltas (0.22%)** - almost all single matras (e.g. ang 26 `sqgur` vs `siqgur`). Report: `tools/data/concordance/sggs-true-deltas-2026-07-17.json`.
- **Adjudication workflow:** each true delta gets checked against a physical saroop scan; whichever ecosystem is wrong gets an upstream issue (ShabadOS has a public correction logbook; BaniDB a proofreading team). We never hand-edit our corpus - corrections only arrive through pinned upstream releases, so our AI labels never fork from the ecosystem.
- **Golden gate additions** (Phase 1's validator): concordance true-delta count must not GROW between bakes; first_letters_uni must equal derivation-from-gurmukhi_uni for every line; type-3 lines cross-checked against ਰਹਾਉ text.
- **Search accuracy harness:** a committed golden-query set (first-letter start/anywhere incl. every fold class letter, ang lookups, English words) with expected line ids, run at bake time and in `flutter test` - search regressions become failing tests, not user reports.
- **Tracker note:** the engine normalizer keeps matras, so the 135 deltas do reach matching - the fuzzy scorer absorbs a one-matra difference, but training-label fidelity (Phase 5) is the real reason to adjudicate them.

## Phase 4 - CI guard (E1 slice)

GitHub Actions job on PRs touching `tools/**` or `pubspec` assets: run `build_corpus.py` against pins, golden gate must pass, `flutter test` runs against the fresh bake (fixture stays in-memory; one integration test opens the real bake).

## Phase 5 - ceremonies extraction (D1, unblocked by this plan)

`tools/extract_ceremonies.py` (node dump → JSON in `tools/data/ceremonies/`, committed) → bake emits `ceremonies` + `ceremony_items` (verse refs by ShabadOS id via PageNo+ASCII-text match, ranges expanded, HTML interludes as `custom_html` with STTM/Khalis credit line rendered in the ceremonies UI).
The realm→ShabadOS verse-id bridge reuses the fingerprint logic from Phase 2.
A1 (ceremonies UI) then consumes plain tables, no realm at runtime.

## File map (review order when built)

1. `tools/schema/corpus.sql` + `tools/pins.json` - the contract and the pins.
2. `tools/build_corpus.py` - the pipeline (absorbs enrich_corpus.py; that file gets deleted).
3. `tools/diff_corpus.py` - the upgrade gate.
4. `tools/data/fold_pairs.json`, `tools/data/banidb-snapshot-*/`, `tools/data/ceremonies/` - committed derived inputs.
5. `lib/data/gurbani_database.dart` - db_meta read, schema assert, remap-on-content-change, sg custom-id migration.
6. `lib/presenter/view/settings_drawer.dart` + a small `UpdateCubit` - the manual check (Phase 3).
7. `.github/workflows/data.yml` - Phase 4.
8. `LICENSE` (GPL-3.0) + README/DATA.md license + credit updates - lands first, it is independent.

## Success criteria

```success-criteria
- Clean checkout + pinned inputs -> build_corpus.py reproduces the same content_sha256 twice.
  verify: cd gurbani_live && python3 tools/build_corpus.py --out /tmp/a.sqlite && python3 tools/build_corpus.py --out /tmp/b.sqlite && cmp <(sqlite3 /tmp/a.sqlite "SELECT value FROM db_meta WHERE key='content_sha256'") <(sqlite3 /tmp/b.sqlite "SELECT value FROM db_meta WHERE key='content_sha256'")
- The golden gate fails on a corrupted input (mutate one anchor line -> non-zero exit).
  verify: cd gurbani_live && python3 tools/build_corpus.py --self-test-gate
- diff_corpus.py on 4.8.7 vs 5.0.0-next emits the report and flags id churn.
  verify: manual - read tools/out/diff-4.8.7-5.0.0-next.md
- App refuses an unknown schema major; heals a removed lineId; migrates sg customs.
  verify: cd gurbani_live && flutter test test/data/
- Update check: manifest fetch happens only on click; bad sha aborts; atomic swap survives kill mid-download.
  verify: cd gurbani_live && flutter test test/update/
```

## Out of scope

Auto-update on launch (rejected), BaniDB extra translations + panthic texts (follow their own bake PR once this pipeline exists - they're D4/A6 content drops into the same tables), STTM realm auto-watching.
