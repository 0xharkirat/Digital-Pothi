# Epic D - Corpus and Data

**GitHub:** [#29](https://github.com/0xharkirat/Digital-Pothi/issues/29) - sub-issues are linked on the parent.

**Goal:** the right Gurbani data on device, local-only at runtime, and a clear path to keep it current.

**Reference:** [DATA.md](../DATA.md) has the full analysis of the three data sources (open ShabadOS SQLite, the BaniDB API, STTM's curated Realm) and why we source what we source.

**Done already:** the bundled ShabadOS corpus (141k lines) enriched with translations and transliterations; the self-contained `sundar_gutka.sqlite` built from the BaniDB API (all banis, the four length tiers, Gurmukhi / English names); Anand Sahib Bhog ordered correctly (pauris then salok) plus a standalone Salok, bridged from the corpus.

Open sub-issues below.

## D1 - Ceremony sequence data 🔴 P1

**Area:** data · **Blocks:** A1

The ceremony flows (which shabads, in what order) live in STTM's Realm `Ceremonies_Shabad`, and unlike bani lengths they are not in the BaniDB public API (the `/ceremonies` endpoint 404s).
Source them once and bake them into the bundled data.

**Options to evaluate:**
- Extract from STTM's Realm build (needs the Realm SDK).
- Hand-define the sequences from known references (the Lavan and Raagmala / Mundavani banis are already on device).

**Acceptance:**
- [ ] Ceremony sequences (Anand Karaj, Akhand Paath Bhog) available as local data.
- [ ] Each line resolves to a corpus line for display, with the English / Raagmala toggles' data present.
- [ ] Provenance documented in DATA.md.

## D2 - One-time on-device DB download 🔴 P2

**Area:** data/infra · **Was:** part of task #14

Today the DBs ship inside the app and re-copy on a version bump, so a corpus correction needs an app release.
Move to a one-time download against a remote version / md5 manifest, exactly how STTM refreshes its Realm from blob storage.

**Acceptance:**
- [ ] Host the corpus and bani DBs plus a version / md5 manifest.
- [ ] On launch, compare local vs remote and download only when changed.
- [ ] First-run experience handles the initial download gracefully (progress, offline fallback to a bundled seed).

## D3 - Corpus refresh and drift check 🔴 P2

**Area:** data/tooling

A repeatable way to pull newer ShabadOS / BaniDB data and see what changed before shipping it.

**Acceptance:**
- [ ] Re-run `enrich_corpus.py` and `fetch_bani_lengths.py` against the latest upstream.
- [ ] A diff report of per-bani line counts and normalized text vs the current bundle.
- [ ] Flag any line that fails to resolve.

## D4 - Additional translation and transliteration sources 🔴 P2

**Area:** data · **Serves:** A6

Bundle and surface the extra sources STTM offers (Hindi and Spanish translation, Hindi transliteration, Devnagri).
Devnagri is already copied by the enrich step but not shown.

**Acceptance:**
- [ ] The extra sources are present in the corpus.
- [ ] The presenter and overlay can select and show them (ties into A6).
