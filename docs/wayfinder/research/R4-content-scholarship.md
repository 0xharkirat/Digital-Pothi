# R4 · Content correctness / scholarship

`wayfinder:research` · resolved 2026-08-01 · READ-ONLY survey (no corpus or code changed)

## What this answers

Survey the scholarship the AI trains on and the projection displays, per the R4 ticket.
Grounded on [docs/DB-COMPARISON.md](../../DB-COMPARISON.md), the `sttm-realm-empirical` memory note, the shipped build tooling, and the concordance adjudication data, cross-checked against public Sikh scholarship and the ShabadOS licensing.

## What we actually ship (verified against the build, not the docs)

The projection and any AI training draw on a narrow slice of what ShabadOS/BaniDB carries.
`tools/build_corpus.py` bakes exactly two exegetical sources into `assets/corpus/gurbani.sqlite`:

```
_TRANSLATIONS = [("en", "Dr. Sant Singh Khalsa", 1), ("pa", "Prof. Sahib Singh", 6)]
```

So per line we ship: the Gurmukhi text (ShabadOS), one English translation (Sant Singh Khalsa), one Punjabi teeka (Prof. Sahib Singh's Darpan), and algorithmic transliterations (anvaad-js 1.5.0, per `tools/pins.json`).
We do not ship Manmohan Singh, BDB, Faridkot, the Spanish, or the Hindi sources.
Those only matter if backlog item A6 (more translations) pulls them from the BaniDB API later, at which point their licensing and quality become live concerns.
The upstream data is pinned to `@shabados/database@4.8.7` (sha256 in `tools/pins.json`); the standing rule is that corrections flow only via pinned upstream releases, never hand-edits.

## Source-by-source state

### Gurmukhi text (the thing that must be right)

- **Provenance.**
  ShabadOS follows **Shabdaarth (SGPC, 2009-2012)** for the SGGS Gurmukhi, with **Damdami Taksaal** sources for pauses/vishraam, and states it uses physical sources to determine the digital representation where possible ([shabados/database README](https://github.com/shabados/database)).
  That anchors our SGGS text to the SGPC-standard printing, which is the panthically mainstream 1430-ang Damdami Bir lineage.
- **Authority.**
  This is the strongest possible anchor for a Sikh presenter: the SGPC printing is the text the Akal Takht recognizes, and the 1998 Akal Takht edict reserves saroop printing to the SGPC ([sgpc.net](https://sgpc.net/sri-guru-granth-sahib/), [freeakaltakht.org](https://www.freeakaltakht.org/akaltakht_sgpc)).
- **Measured accuracy.**
  `tools/concordance.py` (run 2026-07-17) compared all 60,555 shipped SGGS lines against BaniDB: **99.03% exact** after normalization, 453 slicing-policy splits, and 135 residual "true deltas" (0.22%).
  See the deltas section below for what those 135 actually are.
- **License.**
  ShabadOS marks the `data` folder as Public Domain (Creative Commons Public Domain Mark 1.0), framed as a factual compilation, with a "no derogatory/distorting treatment" clause; the code is MIT ([README](https://github.com/shabados/database)).
  Scripture text itself is not copyrightable, so this is clean for the Gurmukhi.

### English translation - Dr. Sant Singh Khalsa (shipped as `en`)

- **What it is.**
  The "Khalsa Consensus Translation," built primarily on Bhai Manmohan Singh's translation, the de-facto standard English online ([SikhiWiki: SGGS translations](https://www.sikhiwiki.org/index.php/SGGS_translations)).
- **Authority.**
  Widely regarded as among the most usable English translations and carried by SGPC.net, SikhNet, and SikhiToTheMax; good enough for routine reference.
- **Known issues.**
  Criticized for flaws that begin at the Mool Mantar, occasional doctrinal flattening, and (separately) erroneous transliterations ([Sikh Philosophy Network](https://www.sikhphilosophy.net/threads/singh-sahib-sant-singh-khalsa-jis-translation-of-sri-guru-granth-sahib.8896/), [SikhiWiki](https://www.sikhiwiki.org/index.php/SGGS_translations)).
  Note the transliteration criticism does not reach us: we generate transliterations with anvaad-js, not from his romanization.
  Critical scholarly analysis of this translation is thin because few reviewers are fluent in both registers, so "widely used" is not the same as "peer-reviewed."
- **License.**
  Dr. Sant Singh gave open permission to publish and redistribute; it is treated as free-to-use across the ecosystem ([Internet Archive](https://archive.org/details/AadGuruGranthSahibEnglish)).
  It is a granted permission, not a formal CC/PD dedication, so the licence is "effectively open" rather than provably irrevocable.

### Punjabi teeka - Prof. Sahib Singh, Sri Guru Granth Darpan (shipped as `pa`)

- **What it is.**
  A 10-volume word-by-word exegesis (1962-64), the most widely used teeka today, resting on his foundational **Gurbani Viakaran** (1932), the grammar that fixed how vowel-ending inflections are read ([SikhiWiki: Professor Sahib Singh](https://www.sikhiwiki.org/index.php/Professor_Sahib_Singh)).
- **Authority.**
  The highest-authority, most grammatically disciplined choice available, honoured by Punjabi University (D.Litt., 1971).
  For an app that will train an AI on meaning, this is the right teeka to have picked.
- **Known issues.**
  A single-scholar Nirmala-influenced reading; his grammar-first method is occasionally contested by sampardai (traditional) exegetes, so it is authoritative but not the only panthic voice.
- **License.**
  Ships under ShabadOS's PDM mark, but Prof. Sahib Singh died in 1977, so under Indian copyright (life + 60 years) the Darpan text is arguably still in copyright until ~2037.
  It is reproduced freely everywhere (searchgurbani, gurbanifiles), and ShabadOS asserts factual-compilation PDM, but this is the one shipped source whose "public domain" status rests on an assertion rather than an author dedication or expiry.

### Sources we do NOT ship but A6 might pull (flagged, not yet a risk)

- **Bhai Manmohan Singh (`en.ms`, `pu.ms`).**
  The SGPC-printed 8-volume "standard English," begun 1948, completed 1960 ([SikhiWiki](https://www.sikhiwiki.org/index.php/SGGS_translations)).
  High authority, but printed and copyrighted by SGPC (2006-2009 editions), so pulling it is a genuine third-party copyright question, not a PD freebie.
- **Faridkot Wala Teeka (`pu.ft`).**
  The first complete traditional teeka, Giani Badan Singh, Nirmala sect, Braj Bhasha, completed 1883 and published 1906/1928 ([SikhiWiki: Faridkot Wala Teeka](https://www.sikhiwiki.org/index.php/Faridkot_Wala_Teeka), [The Sikh Encyclopedia](https://www.thesikhencyclopedia.com/faridkot-tika/)).
  Historically foundational and the prototype for all later teekas, but archaic idiom and a sampardai reading that differs from Sahib Singh's grammar-first method; old enough to be clearly public domain.
- **`en.bdb` / Spanish `es.sn` / Hindi `hi.*`.**
  BDB is a BaniDB-lineage English gloss; the Spanish and Hindi are largely single-translator works with far less review than the primary English/Punjabi.
  Lower reliability, treat as secondary display only, never as training ground truth.

## The 135 deltas: smaller than the headline

The ticket calls these ~135 deltas; my re-analysis of the adjudication file (`tools/data/concordance/sggs-true-deltas-2026-07-17.json`, character-level edit distance) shows the real disagreement surface is much smaller:

| Bucket | Count | What it is | Textual risk |
|---|---|---|---|
| Line-boundary / grouping | 84 | One side's text is an exact substring or concatenation of the other. Identical Gurmukhi characters, split across pankti boundaries differently. | **None** - not a text disagreement. |
| Sub-word matra/spelling | 50 | Edit distance <=3: presence/absence of a single aunkar, sihari, or kanna (e.g. `sqgur`↔`siqgur`, `swD`↔`swDu`, `gurupUrw`↔`gurpUrw`). | Low - orthographic variants between printings, no meaning change. |
| Header wording | 1 | Ang 870 sirlekh: `...bwxIBgqwkIkbIrjIGru` vs `...bwxIkbIrjIaukIGru` (a raag-header phrasing, not a verse). | Low - metadata line, not scripture body. |

So the genuine orthographic disagreement is ~50 lines out of 60,555, roughly **0.08%**, every one a single-matra variant of the kind that legitimately differs between the SGPC Shabdaarth and other printings.
These are exactly the differences that distinguish paath traditions (SGPC vs Taksal gutkas), documented as real and contested but sub-semantic ([Damdami Taksal code of conduct](https://www.damdamitaksal.com/code-of-conduct/gurbani-da-adab)).
**Do they matter?**
Not for meaning or for AI training targets.
They matter only for pixel-level projection fidelity if a reviewer compares our ang against a specific physical gutka.
The right disposition is the one already in the memory note: file each adjudicated matra upstream to ShabadOS, do not hand-patch, and let the pinned release carry the fix back.

## The ~900 missing panthic lines

Per DB-COMPARISON.md and the realm study, the STTM realm carries **929 panthic ("R" source) verses** (Ardas, Rehitname, and related panthic texts) that are **empty in ShabadOS**; our corpus has 17 Ardaas lines and nothing for Rehitname/Uggardanti.
These are not SGGS or Dasam Granth scripture, so their absence does not touch the 141,264-line corpus accuracy.
They matter for one thing only: **ceremony and full-bani fidelity** (a complete Ardas, Antim Sanskar and Anand Karaj sequences).
The risk is different in kind from the deltas: it is not "wrong text" but "no text," and panthic texts like Ardas and the Rehitname are precisely the ones with genuine, live inter-jatha wording disputes, so whatever we source needs explicit provenance.
BaniDB's API has this content; the actionable path (already in DB-COMPARISON.md item 2) is to source them from BaniDB with attribution rather than transcribe by hand.

## Where correctness risk actually concentrates

Ranked, highest first:

1. **Panthic ceremony/bani text we would author or import (the ~900 lines).**
   Highest risk because it is missing, contested between jathas, and headed for live projection during rites.
   Nothing here should ship without a named human reviewer and a cited physical source.
2. **AI training on translations as ground truth.**
   The Gurmukhi is a safe training target; the Sant Singh Khalsa English is not authoritative enough to be a truth label, and Sahib Singh's Punjabi is authoritative but single-voice.
   Train meaning-models on these as *a* reading, never as *the* reading, or the model will launder one scholar's interpretation into projected "fact."
3. **Licensing on the Punjabi teeka and any future A6 imports.**
   Sahib Singh's Darpan and Manmohan Singh's translation are the two shipped-or-nearby sources whose "public domain" footing is an assertion, not an author grant or a clear expiry.
   This is a legal risk, not a correctness one, but it lands on the same content.
4. **Algorithmic transliteration (anvaad-js).**
   Systematic romanization rules can be uniformly slightly wrong (nasalization, gemination) in ways a matra-level corpus diff never catches, and it is the layer most sangat members can actually read.
5. **The 50 real matra deltas.**
   Lowest correctness risk, non-zero projection-fidelity risk, already have a clean upstream disposition.

## What needs panthic / scholarly review before training or projecting

- **Stand up a named review authority.**
  "Panthically correct" here means the text a Sikh reviewer can trace to the SGPC Shabdaarth / Akal-Takht-recognized saroop.
  Assign at least one gursikh reviewer fluent in Gurmukhi and Punjabi to sign off before content is projected to sangat; the app has no standing to self-certify.
- **Gate the ~900 panthic lines behind that review.**
  Every Ardas / Rehitname / ceremony line needs a cited physical or SGPC-digital source and a reviewer sign-off before it is projected or trained on, because these are the contested texts.
- **Label translations as interpretation in both the UI and the training pipeline.**
  Attribute Sant Singh Khalsa and Prof. Sahib Singh by name on the projection, and tag them as "reading, not label" in any training manifest.
- **Adjudicate the 50 matra deltas upstream, don't patch.**
  Walk `sggs-true-deltas-2026-07-17.json`, file the genuine orthographic variants to ShabadOS with citations, and pin the corrected release.
- **Resolve the teeka/translation licence before wide distribution.**
  Confirm redistribution footing for Prof. Sahib Singh's Darpan (still arguably in copyright to ~2037) and get written terms before any A6 import of Manmohan Singh or other SGPC-copyright sources.
- **Spot-check the anvaad-js transliteration** against a reviewer for a sample of high-frequency lines, since a systematic romanization error is invisible to the corpus concordance.

## Sources

Repo:
- [docs/DB-COMPARISON.md](../../DB-COMPARISON.md) - realm vs ShabadOS vs ours, the 929-panthic-line gap, translation-source inventory.
- `tools/build_corpus.py` - `_TRANSLATIONS` proves we ship SSK (en) + Prof. Sahib Singh (pa) only.
- `tools/pins.json` - pinned `@shabados/database@4.8.7`, anvaad-js 1.5.0, baseline counts.
- `tools/data/concordance/sggs-true-deltas-2026-07-17.json` - the 135-delta adjudication list re-analyzed here.
- `tools/concordance.py` - the 99.03%-exact measurement.
- `sttm-realm-empirical` memory note - licensing correction (ShabadOS data = PDM + CC BY-SA; code GPL/MIT), STTM ceremony HTML = Khalis copyright.

Web:
- ShabadOS database README + license: https://github.com/shabados/database
- ShabadOS source bibliography (Sahib Singh Darpan, Faridkot/Badan Singh, Manmohan Singh, vishraam = Damdami Taksaal): https://cdn.jsdelivr.net/npm/@shabados/database@5.0.0-next.0/README.md
- SGGS translations overview (SSK, Manmohan Singh, standard-English lineage): https://www.sikhiwiki.org/index.php/SGGS_translations
- Sant Singh Khalsa translation, permission and criticism: https://www.sikhphilosophy.net/threads/singh-sahib-sant-singh-khalsa-jis-translation-of-sri-guru-granth-sahib.8896/ , https://archive.org/details/AadGuruGranthSahibEnglish
- Prof. Sahib Singh (Darpan, Gurbani Viakaran, authority): https://www.sikhiwiki.org/index.php/Professor_Sahib_Singh
- Faridkot Wala Teeka (Badan Singh, Nirmala, 1883/1906): https://www.sikhiwiki.org/index.php/Faridkot_Wala_Teeka , https://www.thesikhencyclopedia.com/faridkot-tika/
- SGPC / Akal Takht text authority and saroop-printing edict: https://sgpc.net/sri-guru-granth-sahib/ , https://www.freeakaltakht.org/akaltakht_sgpc
- SGPC vs Taksal spelling-variant context: https://www.damdamitaksal.com/code-of-conduct/gurbani-da-adab , https://www.sikhawareness.com/topic/12013-taksal-and-sgpc-gutkey/
