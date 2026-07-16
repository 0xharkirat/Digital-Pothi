---
date: 2026-07-16
topic: search-parity
---

# Search Parity (Epic A: A4 + A5)

## What We're Building

STTM-grade search for the presenter, as one chunk, because in STTM these live on a single pane (`SearchContent.jsx`).
A search-type dropdown replaces the current two chips: First letter (start), First letter (anywhere), Full word (Gurmukhi), Full word (English), Ang.
Below the box, three filter dropdowns narrow results by Writer, Raag, and Source, combining with the active query, exactly as STTM's "Filter by" row does.
Typing a number in Ang mode lists that page's lines; selecting one opens its shabad at that line.

The next chunk (planned separately) is A7: the home verse + STTM's intelligent spacebar, whose behaviour we confirmed from `change-verse.js`.

## Why This Approach

Three options were considered.

**Extend the existing search path** (chosen).
`GurbaniDatabase.search*` gains English, Ang, and filter parameters; `SearchMode` grows; the SearchPane swaps chips for a dropdown and adds filter dropdowns.
Pros: consistent with every existing pattern in the app, smallest diff, all local.
Cons: the search SQL gets more branches.

**A dedicated search repository layer** (rejected).
A `SearchRepository` wrapping the DB with a query-builder.
Rejected as speculative structure: one consumer, no reuse today (YAGNI).

**FTS-first for English** (deferred, not rejected).
Indexing translations in FTS5 before shipping.
English full-word search will start as a SQL `LIKE` over the ~90k English translation rows; we measure, and only add an FTS index if it is actually slow.

## Key Decisions

- Chunk 1 = A4 + A5 together; A7 is chunk 2: they share STTM's pane, and the home-verse work touches a different surface (shabad pane + keyboard).
- Search-type UI is an STTM-style dropdown, not more chips: STTM grounds the UI, and five types outgrow a chip row.
- Defer STTM's "Main letters" and "Romanized first letters" types: each needs its own query/index work and neither is core to daily use.
- Spacebar (chunk 2) adopts STTM's intelligent behaviour, gated by a setting that defaults on; arrows stay plain next/prev.
- Home line (chunk 2) is the opened-at line, re-pinnable per line, with a visual badge on the ਰਹਾਉ line - STTM-exact.
- Filters populate from the corpus (writers, sections, sources tables) and combine with the query as SQL WHERE clauses.
- **Ang search is source-scoped** (must-address from the grill): page numbers repeat across 10 of the 12 sources (SGGS Ang 1, Dasam Panna 1, Vaaran Bhai Gurdas Vaar 1, ...), so Ang mode defaults to Sri Guru Granth Sahib and respects the Source filter when set - exactly STTM's `PageNo = N AND Source.SourceID = 'G'`.
- Ang results are the page's lines as normal result tiles, in page order; selecting one opens its shabad at that line (STTM `loadAng` behaviour).
- Search type and filters are session-scoped, not persisted (matches STTM; nothing to migrate later if we change our minds).

## Verified facts (so the plan does not rediscover them)

- Join path for filters: `lines → shabads (writer_id, section_id, source_id) → writers / sections / sources`; the existing `_searchCols` already joins writers + sections, so source is one more join.
- Option counts: 42 writers, 139 sections, 12 sources - all fine as plain dropdowns with an "All" default.
- English translations exist for the SGGS corpus via our enrich step (source: Sant Singh Khalsa); English search runs over that set.

## Open Questions

- English `LIKE` performance over ~90k translation rows: assumed fine; measure during build and add an FTS index only if actually slow.
