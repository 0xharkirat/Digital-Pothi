# Epic A - Presenter Parity

**GitHub:** [#1](https://github.com/0xharkirat/Digital-Pothi/issues/1) - sub-issues are linked on the parent.

**Goal:** reach feature parity with the SikhiToTheMax desktop app for the operator-driven presenter, so a user switching from STTM loses nothing.

**Reference:** the gap matrix in [UPDATES.md](../UPDATES.md); the STTM source inventory is captured in the parity memory.

**Done already (not open work):** search (first-letter + full-word), line + shabad navigation with edge-aware autoscroll, larivaar / vishraam / font-scale, solid backgrounds, settings drawer, history, favorites, quick insert (Waheguru / Mool Mantar / Anand Sahib Bhog / Announcement / blank), Sundar Gutka full bani list in STTM id order, bani length (Short / Medium / Long / Extra Long), Gurmukhi / English bani names, keyboard control.

Open sub-issues below.

## A1 - Ceremonies (Anand Karaj, Akhand Paath Bhog) 🔴 P1

**Area:** presenter/ceremonies · **Depends on:** D1 (ceremony data)

A ceremony is a pre-arranged, fixed sequence of shabads for an occasion, loaded as one unit and stepped through, not a single shabad.
STTM ships three (`ceremoniesFilter.visible: [1,3,5]`): Anand Karaj (the four Lavan plus Anand Sahib, with an English toggle), a Sukhmani / Sehaj Paath style bhog, and Akhand Paath Bhog (with a Raagmala on/off toggle).
The Lavan and the Raagmala / Mundavani banis are already on device; the missing piece is the curated flow.

**Acceptance:**
- [ ] A Ceremonies entry point (drawer or tab) listing the available ceremonies.
- [ ] Selecting a ceremony loads its sequence; line and shabad navigation work across it.
- [ ] Anand Karaj with the English-translation toggle.
- [ ] Akhand Paath Bhog with the Raagmala on/off toggle.

## A2 - Themes (Light / Dark / High-Contrast / Low-Light) 🔴 P2

**Area:** theme

STTM offers named themes; we have a dark operator theme plus the kesari design system.
Add the named set and a picker in Settings.

**Acceptance:**
- [ ] Four themes selectable in Settings, persisted.
- [ ] Operator surfaces and the projected display both respect the theme.

## A3 - Image and video backgrounds 🔴 P2

**Area:** display/background

Today the projected background is one of four solid presets.
STTM allows bundled images, a custom image, and mp4 video backgrounds.

**Acceptance:**
- [ ] A few bundled image backgrounds selectable.
- [ ] Custom image from the file system.
- [ ] mp4 video background, looped, behind the text.
- [ ] Works in the in-app display and the overlay / output window.

## A4 - English and Ang search ✅ DONE

**Area:** search · Shipped 2026-07-16 (search-parity chunk; see docs/plan/2026-07-16-feat-search-parity-plan.md)

STTM-style type dropdown: First letter (start/anywhere), Full word (Gurmukhi/English), Ang.
Ang is an explicit type (like STTM), source-scoped to SGGS by default because page numbers repeat across 10 of 12 sources.

**Acceptance:**
- [x] Full-word English search over the translations (matched line shown on the tile).
- [x] Ang type lists the page's lines; selecting opens the shabad at that line.

## A5 - Search filters (source / writer / raag) ✅ DONE

**Area:** search · Shipped 2026-07-16 (same chunk as A4)

**Acceptance:**
- [x] Writer / Raag / Source dropdowns on the search pane (All = reset; Writer/Raag disable in Ang mode).
- [x] Filters combine with the active query and re-run it on change.

## A6 - More translations and per-row source selection 🔴 P2

**Area:** display/content · **Related:** D4

STTM shows three configurable content rows with selectable sources (Punjabi teeka, English / Hindi / Spanish translation, English / Hindi transliteration).
We show a fixed English translation, Punjabi teeka, and roman transliteration.

**Acceptance:**
- [ ] Hindi and Spanish translations available.
- [ ] Per-row source selection in Settings.
- [ ] The overlay `?show=` params extend to the new rows.

## A7 - Home / Rahao (asthaai) marker and jump ✅ DONE

**Area:** presenter/navigation · **Related:** B6 · Shipped 2026-07-16 (PR #41; see docs/plan/2026-07-16-feat-home-verse-spacebar-plan.md)

Per-shabad home verse (opened-at line, re-homeable per row) + STTM's intelligent spacebar: space resumes the antara run, walks couplets sharing a physical ang line, snaps back home at line boundaries.
Setting-gated, on by default. ਰਹਾਉ line badged.

**Acceptance:**
- [x] The Rahao / home line is marked in the shabad view (badge + home icon).
- [x] Space drives the resume/walk/snap cycle; setting off = plain snap home.

## A8 - Autoplay and Akhand Paath continuous mode 🔴 P2

**Area:** presenter/navigation

Timed auto-advance, and a continuous-reading mode for Akhand Paath.

**Acceptance:**
- [ ] Autoplay advances lines on a configurable interval.
- [ ] A continuous mode reads straight through shabad boundaries.

## A9 - Left-align option and slide transitions 🔴 P3

**Area:** display

**Acceptance:**
- [ ] Left-align toggle for the projected text.
- [ ] Optional fade / slide transition between lines.

## A10 - Workspaces (Single-Display / Presentation / Multi-Pane) 🔴 P3

**Area:** presenter/layout

We have one responsive presentation layout; STTM offers switchable workspace presets.

**Acceptance:**
- [ ] Switchable layout presets, persisted.

## A11 - Focus-search hotkey and number shortcuts 🔴 P2

**Area:** presenter/keyboard

The keyboard nav is in; still missing STTM's focus-search hotkey (Ctrl+/) and Ctrl+1..6.

**Acceptance:**
- [ ] A hotkey focuses the search box.
- [ ] Ctrl+1..6 map to STTM's actions (define the mapping).

## A12 - Rich-text announcements and Dhan Guru slides 🔴 P3

**Area:** presenter/quick-insert

The Announcement slide is plain text today.
STTM supports rich-text announcements and Dhan Guru slides.

**Acceptance:**
- [ ] Basic formatting in the announcement editor.
- [ ] A Dhan Guru slide preset.

## A13 - Custom image quick-insert 🔴 P2

**Area:** presenter/quick-insert · **Depends on:** A3 (image display path)

The remaining STTM quick-insert item: pick an image and show it as a slide.

**Acceptance:**
- [ ] Pick an image and project it, with the overlay / output window in sync.

## A14 - Named collections 🔴 P2

**Area:** presenter/library

Favorites is a single starred list.
Collections group saved shabads into named lists, stored locally.

**Acceptance:**
- [ ] Create / rename / delete a collection.
- [ ] Add or remove a shabad to a collection from the shabad pane.
- [ ] Browse a collection and reopen from it.

## A15 - Operator console density pass (STTM-grade real estate) ✅ DONE

**Area:** presenter/layout · **GitHub:** [#42](https://github.com/0xharkirat/Digital-Pothi/issues/42) · Milestone M1 · Shipped 2026-07-16 (PR #43)

Side-by-side with STTM, the operator surface reads like a Material form, not a pro console.
Root cause: form components (floating-label dropdowns, outlined boxes, rounded inset cards) doing toolbar jobs, plus an AppBar that spends 64px on a title.

**Acceptance:**
- [x] AppBar replaced by a slim icon rail; search header = STTM's language radios + Full word / Anywhere checks + side Ang box; filters = one "Filter by" text row.
- [x] Full-bleed panes separated by luminance/1px seams; compact density.
- [x] Home icons hover-reveal; source-coloured result bars + STTM footer legend with count.
