# DB Comparison: STTM's shipped Realm vs ShabadOS vs ours

Empirical comparison, run 2026-07-17 against the real artifacts - not the docs.
STTM side: `~/Library/Application Support/SikhiToTheMax/sttmdesktop-evergreen-v2.realm` (225 MB, schemaVersion 2) opened read-only with the repo's own realm binding; schema from `realm-schema-evergreen.json`.
Our side: `assets/corpus/gurbani.sqlite` (ShabadOS + our enrichment) and `assets/corpus/sundar_gutka.sqlite` (BaniDB API bake).
The dump scripts live at `tmp/sttm-desktop/dump_realm*.cjs` (workspace, not this repo).

## Schema inventory

| STTM Realm object (fields) | Ours | Notes |
|---|---|---|
| `Verse` (Gurmukhi ASCII, Translations JSON, Writer→, Raag→, PageNo, LineNo, Source→, FirstLetterStr, FirstLetterEng, MainLetters, Visraam JSON, FirstLetterLen, Shabads[]) | `lines` (gurmukhi ASCII + `gurmukhi_uni`, source_page, source_line, first_letters, `first_letters_uni`, type_id, order_id) + `translations` + `transliterations` tables | Ours adds Unicode text, a global `order_id` (their verses have no reading-order key - shabad membership orders them), `type_id` (Manglacharan/Sirlekh/Rahao/Pankti - **they have no line-type column**), and pre-baked transliterations (they transliterate at render time). |
| `Shabad` (just ShabadID) | `shabads` (id, source_id, writer_id, section_id) | Their writer/raag/source hang off Verse; ours off the shabad. |
| `Source`, `Writer`, `Raag` | `sources`, `writers`, `sections` | Taxonomy differs - see below. |
| `Banis`, `Banis_Shabad` (Seq, header, MangalPosition, exists{SGPC,Medium,Taksal,BuddhaDal}, **Paragraph**), `Banis_Custom`, `Banis_Bookmarks` | `sg_banis`, `sg_lines` (seq, texts, page, is_header, len_short/medium/long/extralong) | Same length-tier flags (we mapped them already). **We dropped: `Paragraph` (paragraph-mode grouping), `MangalPosition`, `Banis_Custom` (62 curated non-corpus lines), and `Banis_Bookmarks` (1,578 jump points inside long banis)**. |
| `Ceremonies` (6), `Ceremonies_Shabad` (487 rows: Seq, Verse→/Shabad→/**VerseRange[]**/Custom→), `Ceremonies_Custom` (17 rich-text HTML entries) | nothing | **D1's data source, found.** Six ceremonies: anandkaraj, death (Antim Sanskar), anand (Anand Sahib + Salok), janam (Naam Sanskar), akbhogrm / akbhog (Akhand Paath Bhog with/without Raagmala). Sequences reference verses/ranges plus curated English/Gurmukhi HTML interludes. |

## Row counts

| Thing | STTM realm | Ours | Delta / meaning |
|---|---|---|---|
| Verses | 142,578 | 141,264 | See per-source split below. |
| Shabads | 13,916 | 12,730 | Follows the verse delta + finer slicing. |
| Writers | 47 | 42 | Minor; their extra writers likely cover panthic sources. |
| Raags vs sections | 67 raags | 139 sections | **Different taxonomy.** Their `Raag` is a true raag list; ShabadOS `sections` are granth divisions (includes non-raag sections). Our "Raag" filter is actually a section filter - richer but not STTM-equal. |
| Sources | 7 (G, D, B, N, A, S, R) | 12 (SGGS, Dasam, BG Vaaran, BG Kabit, 4x Bhai Nand Lal, Ardaas, Rehitname, Sarabloh, Uggardanti) | Ours splits finer (B = our 3+4; N = our 5+6+7+8). |
| SGGS verses | 60,403 | 60,555 | We carry ~150 more SGGS rows (ShabadOS slicing). |
| Dasam verses | 68,096 | 67,758 | They carry ~340 more. |
| **Panthic (R) verses** | **929** | **17 (Ardaas) + 0 (Rehitname) + 0 (Uggardanti)** | **Biggest content gap: ~900 lines of Ardas / Rehitname / panthic texts are empty in ShabadOS.** This is the text the ceremonies and some banis (e.g. full Ardas) draw on. |
| Sundar Gutka banis | 112 (1..107 minus 20/37/54, + 1000 and 7 variant ids 10037..10082) | 106 (same 1..107 set + our bridged 1006/1007) | Near-parity; their extras are piecemeal variants of banis we already carry whole. |

## Semantic columns that already bit us (or will)

- `FirstLetterEng` - their romanized-first-letter search is a **precomputed, case-sensitive fold baked into the data** (`t`=ਤਥ, `T`=ਟਠ, `d`=ਦਧਡਢ, `i` includes ੴ, `o`=ਓ, `z`=ਜ਼, nuktas fold to base).
  We derived the full fold empirically from all 142k verses (every FirstLetterStr↔FirstLetterEng pair) and encoded it as GLOB classes in `GurbaniDatabase._romanClasses`, with two documented lenient supersets (t covers retroflex too, r covers ੜ) because we lowercase input.
  This is the bug the user hit (t/k/s/b/c/d missing aspirates); a data-level comparison would have caught it on day one.
- `Visraam` - per-verse JSON with **three pause sources** (`sttm`, `sttm2`, `igurbani`), each `{p: wordIndex, t: 'v'|'y'}` (vishraam / yamki).
  Ours: a single convention baked into the ShabadOS text as punctuation (`.` light, `;` heavy) - it renders, but STTM's "visraam source" setting (A6-adjacent) can't be matched without this data.
- `Translations` - per-verse JSON: `en.bdb`, `en.ms` (Manmohan Singh), `en.ssk` (Sant Singh Khalsa), `pu.ss` (Sahib Singh), `pu.ft` (**Faridkot Teeka**), `pu.bdb`, `pu.ms`, `puu.*` (Unicode Punjabi variants), `es.sn` (Spanish), `hi.ss`, `hi.sts` (Hindi).
  Ours: `en` (SSK) + `pa` (Sahib Singh) only.
  A6 (more translations, per-row source) needs this breadth; BaniDB API can supply the same sources.
- `MainLetters` - matra-stripped text powering their deferred-by-us "Main letters" search type; we could derive it from `gurmukhi_uni` with our normalizer if we ever build it.
- `LineNo` - equal to our `source_line` (A7 already uses ours, with the page-aware fix theirs lacks).

## What ours has that theirs does not

- Unicode Gurmukhi in the DB (theirs is ASCII-font only; they convert at runtime).
- A corpus-global `order_id` (their reading order exists only inside a shabad) - our tracker and next/prev-shabad depend on it.
- `type_id` line types (their rahao/header logic falls back to regex on ASCII text - we deliberately used types for the spacebar header-skip).
- Pre-baked roman + devnagri transliterations for all 141k lines.
- FTS5 index for full-word Gurmukhi (they scan Realm).
- A self-contained, versioned, offline data pipeline (they download the realm + schema at runtime).

## Actionable gaps (mapped to the backlog)

1. **D1 (ceremonies data): solved in principle.** The 6 ceremonies + 487 sequence rows + 17 rich-text customs are extractable from the realm with the dump scripts; converting them into our own curated tables (with credit to STTM/Khalis) unblocks A1 without inventing content.
2. **Panthic texts (~900 lines)**: Ardas + Rehitname are missing from ShabadOS - needed for ceremony fidelity; source them (BaniDB API has them) into the corpus or the SG DB.
3. **A6 translations**: fetch en.ms/en.bdb, pu.ft, es.sn, hi.* from BaniDB into `translations` (schema already supports source-per-row).
4. **Visraam sources**: if we want STTM's selectable visraam, we need per-source pause data (BaniDB API `visraam` field) instead of the baked single convention.
5. **Banis polish**: `Paragraph` grouping, `MangalPosition`, bani bookmarks (1,578) are available in the realm/BaniDB if we want STTM-exact bani rendering later.
6. **Raag filter fidelity**: consider a true raag list (their 67) vs our 139 sections, or keep sections and label honestly.

## How they update vs how we do

- STTM: downloads `sttmdesktop-evergreen-v2.realm` + schema JSON at runtime, md5-checked; an empty `new-db/` folder hints at a future engine swap.
- Ours: DBs are baked at build time (`tools/enrich_corpus.py`, `tools/fetch_bani_lengths.py`), versioned by `GurbaniDatabase._version`, copied once per version at startup. D2 (one-time download) stays the plan for post-install updates.
