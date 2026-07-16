# Data Sources and Fidelity

Where the Gurbani data comes from, how it relates to what STTM ships, and how we keep it current.
Written because the bani-length work surfaced that the open data and STTM's data are not the same thing.

## The three upstream sources

There are three distinct things people mean by "the BaniDB database".

- **ShabadOS `@shabados/database`** - a normalized relational SQLite, open and GPL.
  Tables: `lines`, `shabads`, `banis`, `bani_lines` (`line_id`, `bani_id`, `line_group`), `sections`, `sources`, `writers`, `translations`, `transliterations`, `line_types`.
  This is the base of our corpus.
- **BaniDB API** (`https://api.banidb.com/v2`) - the same corpus served as JSON, per bani and per verse.
  Crucially it also carries the per-verse bani-length flags (`existsSGPC` / `existsMedium` / `existsTaksal` / `existsBuddhaDal`) that the open SQLite does not.
- **STTM's Realm build** (`sttmdesktop-evergreen-v2.realm`, downloaded from `banidb.blob.core.windows.net`) - a denormalized, search-optimized, curated binary.
  This is what the STTM desktop app actually reads at runtime.

## What we bundle

- `assets/corpus/gurbani.sqlite` - the ShabadOS SQLite (141,264 lines) plus our enrich step.
  `tools/enrich_corpus.py` copies English (Sant Singh Khalsa) and Punjabi (Sahib Singh) translations, roman + devnagri transliterations, and writers + sections into it.
  Read-only; copied to app-support on first run or version bump.
- `assets/corpus/sundar_gutka.sqlite` - built by `tools/fetch_bani_lengths.py` from the BaniDB API, plus one bani bridged from the corpus (Anand Sahib Bhog).
  Self-contained: each bani line carries its own text, translations, and the four length flags, so no cross-DB line-id mapping is needed.
  15 curated Sundar Gutka banis in Nitnem order.

## The diff: open ShabadOS DB vs STTM's Realm

STTM does not read the open SQLite.
It reads a pre-built Realm that Khalis Foundation compiles from BaniDB and then curates.
The differences that matter for parity:

| Concern | Open ShabadOS SQLite | STTM Realm |
|---|---|---|
| Shape | Normalized relational (separate `translations` / `transliterations` tables, `bani_lines` join) | Denormalized: one `Verse` object with Gurmukhi + concatenated `Translations` + `FirstLetterStr` + `MainLetters` + `FirstLetterEng` + `PageNo` + `Source` + `Shabads` inline |
| Bani lengths | Absent - `bani_lines.line_group` is section grouping, not length tiers | `Banis_Shabad` rows carry `short` / `medium` / `long` / `extralong` booleans per line |
| Ceremonies | Absent | `Ceremonies` + `Ceremonies_Shabad` (Anand Karaj, Anand Sahib Bhog, Akhand Paath Bhog) |
| Search columns | `first_letters` / `first_letters_uni` | Precomputed `FirstLetterStr`, `MainLetters`, `FirstLetterEng` for Realm string queries |
| Format | SQLite (any tool can read it) | Realm (needs the Realm SDK) |

In short: STTM's Realm is BaniDB plus curation (lengths, ceremonies) plus denormalization for fast Realm queries.
The length and ceremony data is the curated part that is not in the open SQLite - it is, however, in the BaniDB API as JSON, which is why we source lengths from there.

## Is it migrations applied?

Two different mechanisms, neither of which we run on-device.

- The open ShabadOS SQLite is a versioned relational database with its own SQL migrations inside the `@shabados/database` build pipeline.
  We consume a released build of it; we do not run its migrations.
- STTM's Realm is not migrated at runtime either - the app downloads a fully pre-built binary and checks its md5 against `banidb.blob`.
  All the curation (lengths, ceremonies, search indices) happens in Khalis's build pipeline, not on the user's machine.
- Our approach bakes the data into read-only SQLite assets at build time (`enrich_corpus.py` + `fetch_bani_lengths.py`) and copies them on a version-stamp bump.
  There is no on-device migration; a schema or data change just bumps `GurbaniDatabase._version` and re-copies.

## Keeping it current

Today, updates ship with an app release:

1. Corpus: pull a newer `@shabados/database`, re-run `tools/enrich_corpus.py`, bump `GurbaniDatabase._version`.
2. Sundar Gutka + lengths: re-run `tools/fetch_bani_lengths.py` (hits the BaniDB API), bump the version.
3. The app re-copies the bundled assets when the version stamp changes.

Later, without an app release (this is the "migrate to one-time download" task):

- Host the two SQLite files plus a small version / md5 manifest.
- On launch, compare the local stamp to the remote manifest and download only if it changed.
- This is exactly how STTM refreshes its Realm from `banidb.blob`, and it lets Gurbani corrections reach users without a store update.

## Verifying our data against upstream

- The BaniDB API is the source of truth for both text and lengths.
  A script can re-fetch and diff line counts plus normalized text per bani to catch drift between releases.
- Reading STTM's Realm directly needs the Realm SDK (a native dependency), and it would only tell us what Khalis curated.
  The BaniDB API exposes the same curated fields as JSON, so we prefer it as both the source and the diff baseline.
