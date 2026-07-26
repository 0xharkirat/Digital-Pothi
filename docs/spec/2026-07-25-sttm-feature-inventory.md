# STTM Desktop - Complete Feature Inventory & Build Spec

**Date:** 2026-07-25
**Method:** exhaustive read-only census of the STTM desktop source (`tmp/sttm-desktop`) by 7 parallel subagents, one per subsystem. Every user-facing feature, setting, behaviour, and edge case is captured with its source location.
**Status legend:** ✅ done in Digital-Pothi · 🟡 partial · ⬜ not built · ⏭️ deferred/replaced (conflicts with our local-only / AI-follow / no-analytics design - listed with the reason, per user decision to include everything but tag the clashes).

This is the spec of record for reaching STTM parity. Build order is the milestone section at the end.

---

## 1. SEARCH

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| S1 | Language toggle Gurmukhi/English (radio) | SearchHeader.jsx:74-99 | ✅ | Our radio group. |
| S2 | Language auto-switches search type | SearchHeader.jsx:33-48 | ✅ | English→full-word/first-letter; gr→first-letter. |
| S3 | First Letter (Start) [type 0] | banidb.js:19 | ✅ | |
| S4 | First Letter (Anywhere) [type 1] | banidb.js:20 | ✅ | |
| S5 | Full Word Gurmukhi [type 2] | banidb.js:21 | ✅ | |
| S6 | Full Word English (translations only) [type 3] | realm-search.js:115 | ✅ | LIKE over en translations. |
| S7 | Romanized First Letters English [type 7] | realm-search.js:170 | ✅ | Our phonetic fold covers this. |
| S8 | **Main Letters search [type 6]** | realm-search.js:155 | ⬜ | Matra-stripped match. Needs a `main_letters` column (anvaad.mainLetters at bake). Not user-selectable in STTM header either. |
| S9 | Ang / page search [type 4] | realm-search.js:139 | ✅ | Ours is source-scoped. STTM's live path is GGS-only. |
| S10 | Source / Writer / Raag filters | SearchContent.jsx:580 | ✅ | |
| S11 | Filter "others" inverse entries | filters.js:1-49 | ⬜ | Writer/Raag lists have an "Others" that matches none-of-known. We only have All + explicit. |
| S12 | Bindi OR-expansion (ਗ↔ਗ਼ etc) | realm-search.js:92 | 🟡 | Our roman phonetic classes fold nuktas; Gurmukhi-input bindi variants not OR-expanded. |
| S13 | Short-query (<3) ordering by FirstLetterLen | realm-search.js:107 | ⬜ | Shorter lines first for 1-2 char queries. |
| S14 | Wildcard `*` in first-letter search | realm-search.js:80 | ⬜ | `*` switches to LIKE/GLOB. |
| S15 | On-screen Gurmukhi keyboard - base page | GurmukhiKeyboard.jsx | ✅ | |
| S16 | **Keyboard matra page (full-word)** | constants.js:1-14 | ⬜ | 5-row withMatra layout + matra-combine logic, shown only in Full-Word Gurmukhi. |
| S17 | Keyboard toggle (Gurmukhi only) | SearchContent.jsx:513 | ✅ | |
| S18 | **Search-term highlighting in results** | SearchResults.jsx:89-141 | ⬜ | Highlights matched words/first-letters per type. |
| S19 | **Transliteration line under result (English mode)** | SearchResults.jsx:156 | ⬜ | anvaad.translit under each hit when language=en. |
| S20 | Source colour-coded result bars + legend + count | SearchResults.jsx:26, SearchFooter.jsx | ✅ | |
| S21 | Enter opens first result | Launchpad.jsx:137 | ✅ | |
| S22 | **Ctrl+/ focus search** | Launchpad.jsx:101 | ⬜ | Hotkey to focus the box. |
| S23 | 50ms debounce + load-more pagination (20/page) | SearchContent.jsx:95-209 | 🟡 | We cap at 40, no infinite scroll. |
| S24 | DB-download progress bar / disabled-until-ready | SearchContent.jsx:518 | n/a | We bundle the DB; no runtime download yet (D2). |
| S25 | **Voice search (record → remote transcribe)** | SearchContent.jsx:344 | ⏭️ | REPLACED by on-device AI auto-follow (the whole point). Keep replaced. |

## 2. SHABAD NAVIGATION & VIEWER LOGIC

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| N1 | Next / prev line (arrows) | ShabadText.jsx:212 | ✅ | |
| N2 | Next / prev shabad | ArrowIcon.jsx:73 | ✅ | Ours steps by order_id (better than STTM's naive id±1). |
| N3 | Tap a line to show it | ShabadVerse.jsx:38 | ✅ | |
| N4 | Intelligent spacebar (home/resume/snap) | change-verse.js:166 | ✅ | Full algorithm ported, with our fixes. |
| N5 | Home/Rahao marker + set-home + jump | change-home-verse.js | ✅ | |
| N6 | Navigator + viewer autoscroll to active | scroll-to-verse.js | ✅ | |
| N7 | **Autoplay (timed advance) + delay 1-20s** | ShabadText.jsx:303, AutoPlayIcon.jsx | ⬜ | Interval nextLine; on-slide play/pause + speed. |
| N8 | **Akhand Paath continuous mode** | ShabadText.jsx:251, ShabadDeck.jsx | ⬜ | Rollover to next shabad at end; renders whole shabad stacked. |
| N9 | **Next-line preview** | Slide.jsx:200 | ⬜ | Dimmed upcoming line under current (mutually exclusive w/ akhand). |
| N10 | **Verses-read checkmarks** | ShabadVerse.jsx:33 | ⬜ | fa-check on read lines; versesRead tracking. |
| N11 | **Copy line to clipboard (Ctrl+C)** | copy-to-clipboard.js | ⬜ | Copies Unicode of active line + toast. |
| N12 | **Go to Ang (load whole page)** | load-ang.js | 🟡 | We have Ang *search*; STTM loads the page as a navigable unit. |
| N13 | **Daily Hukamnama** | daily-hukamnama.js | ⏭️ | Fetches api.banidb.com. Network - defer or make an explicit-fetch button (like model download). |
| N14 | **Random Shabad** | OtherPane.jsx:108 | ⬜ | Local, cheap - pick a random shabad. |
| N15 | **Multi-pane (3 independent panes)** | Navigator.jsx:45 | ⬜ | Big. Each pane own shabad/home/lock/content. Tied to Multi-Pane workspace. |
| N16 | Flower-verse (id 61) skip in nav/scroll | index.js:13 | ⏭️ N/A | Investigated 2026-07-26: our corpus has **no** decorative/separator lines (0 comma verses, min line length 4). STTM's own evergreen-v2 realm also has 0 comma verses, and its `FLOWER_VERSE_ID = 61` is actually Japji pauri 8 (ਸੁਣਿਐ ਸਿਧ ਪੀਰ...) - the skip is vestigial. Nothing in our nav can land on a flower line; no code needed. |
| N17 | Minimize controller (single-display) | singleDisplayHeader.jsx:51 | ⬜ | Part of workspaces. |

## 3. DISPLAY, THEMES & BACKGROUNDS

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| D1 | Larivaar toggle | user-settings.json:165 | ✅ | Larivaar-assist shading not done. |
| D2 | Vishraam - colored words | bakePanktee.js | ✅ | |
| D3 | **Vishraam - gradient background type** | user-settings.json:187 | ⬜ | Second vishraam-type. |
| D4 | **Vishraam source (sttm2/igurbani/sttm)** | user-settings.json:196 | ⬜ | Needs per-source visraam data (baked JSON - D4/A6 data work). |
| D5 | **Larivaar Assist (single/multi colour)** | theme-generator.scss:42 | ⬜ | Alternate-word shading; disables vishraam. |
| D6 | Left-Align | user-settings.json:161 | ✅ | |
| D7 | Slide Transitions (fade) | Slide.jsx:161 | ✅ | |
| D8 | Per-row font sizes (Bani/Trans/Teeka/Translit/Announce) | viewer.scss:306 | ✅ | Just shipped. |
| D9 | Content rows: translation, teeka, transliteration | Slide.jsx:89 | ✅ | Teeka row just added. |
| D10 | **Per-content-row visibility toggles** | user-settings.json:116 | ⬜ | Show/hide each row (content1/2/3-visibility). |
| D11 | **Per-content-row SOURCE selection** | user-settings.json:263 | ⬜ | teeka-source (bdb/ft/ms/ss), translation-english-source (bdb/ms/ssk), hindi, spanish. Needs baked sources (A6 data). |
| D12 | **Transliteration language (English/Devanagari/Shahmukhi)** | SlideTransliteration.jsx | 🟡 | We bundle roman+devnagri; no picker. |
| D13 | Light / Dark display colours | themes.json | ✅ | Just shipped (display + chrome). |
| D14 | **16 named themes** (Khalsa Gold, Baagi Blue, ...) | themes.json | ⬜ | Colour + image-backed themes. |
| D15 | **Image backgrounds** (10 bundled) | custom_backgrounds/ | ⬜ | A3. |
| D16 | **Video backgrounds** (ocean/clouds/melancholy) | themes.json:154 | ⬜ | A3; large assets. |
| D17 | **Custom image/background upload** | theme-bg-uploader.js | ⬜ | File picker → sharp re-encode → user_backgrounds. |
| D18 | **High-Contrast / Low-Light special themes** | themes.json:134 | ⬜ | |
| D19 | **only-gurbani auto layout** | Slide.jsx:41 | 🟡 | We center; STTM special-cases no-content slides. |
| D20 | **Custom English translation HTML** | Slide.jsx:196 | ⬜ | verse-level English rendered as HTML. |
| D21 | **Padding Tools (top/right/bottom/left)** | PaddingTools.jsx | ⬜ | In-viewer padding steppers (0-48). |
| D22 | **Quick Tools (in-viewer content reorder/size/visibility)** | QuickTools.jsx | 🟡 | We do per-overlay ?show; STTM has a live in-viewer panel. |
| D23 | Mangal position (current/above) | user-settings.json:244 | ⬜ | Vestigial in STTM (hardcoded to drop 'above'). |
| D24 | vh-scaled fonts on output | viewer.scss | ✅ | Overlay sizes in vh. |

## 4. SETTINGS (structure)

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| SE1 | Full-screen 3-tab settings + live preview | settings/ | ✅ | Slide Layout / Bani & Languages / App Settings. |
| SE2 | Colors + Backgrounds panel | ThemeContainer.jsx | 🟡 | Colors ✅, backgrounds = 4 solid (image/video = D14-17). |
| SE3 | Font-sizes section (5 rows + reset) | user-settings.json:82 | ✅ | |
| SE4 | Content-row visibility checkboxes (as font-size addons) | user-settings.json:116 | ⬜ | See D10. |
| SE5 | Content-source dropdowns | user-settings.json:263 | ⬜ | See D11. |
| SE6 | Bani length dropdown | user-settings.json:233 | ✅ | |
| SE7 | Intelligent spacebar toggle | user-settings.json:221 | ✅ | |
| SE8 | Live Feed toggle + directory | user-settings.json:314 | ⬜ | See O5. |
| SE9 | Limit changelog / Collect statistics | user-settings.json:319 | ⏭️ | No changelog window / no analytics by design. Dropped. |
| SE10 | Quick Tools / Shortcut Tray toggles | user-settings.json:306 | ⏭️ | STTM-internal panels; dropped (we show the panels always). |

## 5. BANIS, CEREMONIES & QUICK-INSERT

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| B1 | Sundar Gutka full bani list | realm-search.js:285 | ✅ | |
| B2 | Nitnem / Popular grouping + tag dots | SundarGutka.jsx:58 | ✅ | |
| B3 | Bani length tiers filter (SGPC/Medium/Taksal/BuddhaDal) | ShabadText.jsx:23 | ✅ | |
| B4 | English/Gurmukhi bani names | SundarGutka.jsx:160 | ✅ | |
| B5 | **Ceremonies (Anand Karaj, Sehaj/Sukhmani Bhog, Akhand Paath Bhog)** | CeremonyPane.jsx | ⬜ | 3 visible (ids 1,3,5). Data extractable from realm (D1 done conceptually). |
| B6 | **Anand Karaj English-explanations toggle** | CeremonyPane.jsx:163 | ⬜ | |
| B7 | **Akhand Paath Bhog Raagmala on/off** | CeremonyPane.jsx:172 | ⬜ | Off loads ceremony 6 variant. |
| B8 | **Ceremony custom HTML interludes + verse ranges** | load-ceremony.js | ⬜ | |
| B9 | **Per-ceremony theme chooser** | CeremonyPane.jsx:182 | ⬜ | |
| B10 | Quick insert: Waheguru / Mool Mantar / Blank | MiscSlides.jsx | ✅ | |
| B11 | Quick insert: Anand Sahib Bhog | MiscSlides.jsx:44 | ✅ | |
| B12 | Announcement slide | Announcement.jsx | ✅ | Plain text. |
| B13 | **Announcement rich-text HTML** | SlideAnnouncement.jsx:23 | ⬜ | b/i/u/ul/ol/... tags. |
| B14 | **Dhan Guru slides (11 gurus, EN/GR)** | DhanGuru.jsx | ⬜ | Grid + Ctrl+G modal. |
| B15 | **Custom image slide (quick-insert)** | MiscFooter.jsx | ⬜ | A13; depends on image display. |
| B16 | **Lock screen** | LockScreen.jsx | ⬜ | Blanks the display with a "locked" message. |
| B17 | **Auth / SSO login** | AuthDialog.jsx | ⏭️ | Gates cloud favourites + sync. Cloud account - defer; we do local favourites. |

## 6. OUTPUTS & SYNC

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| O1 | Second-screen viewer window | app.js:367 | ✅ | Native fullscreen output window. |
| O2 | **Auto-place viewer on external display** | app.js:338 | ⬜ | C1. Detect non-primary display, position there. |
| O3 | OBS browser-source overlay (LAN HTTP+WS) | app.js:540 | ✅ | Ours: Dart HTTP+WS; per-overlay ?show. |
| O4 | **Overlay style config (fonts/colours/layout/logo/green-screen)** | overlay.json | ⬜ | STTM has a full overlay settings window: 5 layouts, 10 presets, fit-text, date/time, logo, chroma-key. |
| O5 | **Live-feed text files (sttm-Gurbani.txt / -English.txt)** | app.js:452 | ⬜ | For lower-thirds; writes on each line. Cheap. |
| O6 | **Chromecast** | chromecast.js | ⏭️ | Cloud cast. Deferred (local-only ethos). |
| O7 | **Zoom closed-captions POST** | app.js:487 | ⏭️ | Posts each line to a Zoom CC endpoint. Deferred (network). |
| O8 | **Bani-controller sync (mobile/sangat remote control)** | bani-controller/ | ⏭️ | Cloud socket rooms + QR + admin PIN. Deferred; our AI-follow + LAN overlay is the differentiator. Could do a LOCAL-only variant later. |
| O9 | Per-output content selection (?show=) | (ours) | ✅ | Better than STTM. |

## 7. SHELL, TOOLBAR, WORKSPACES, KEYBOARD, HISTORY

| # | Feature | STTM source | Status | Notes |
|---|---|---|---|---|
| A1 | Icon rail (banis / settings) | Toolbar.jsx | ✅ | Ours is a slim rail. |
| A2 | **Workspaces: Single-Display / Presentation / Multi-Pane** | WorkspaceBar.jsx | ⬜ | Switchable layout presets. Multi-pane is the big one (N15). |
| A3 | **Quick Tools panel** | QuickTools.jsx | 🟡 | See D22. |
| A4 | **Padding Tools panel** | PaddingTools.jsx | ⬜ | See D21. |
| A5 | Shortcut tray / Quick Insert drawer | MiscFooter.jsx | ✅ | Ours = Quick Insert row. |
| A6 | History (dedup, resume, sort, delete item) | HistoryPane.jsx | 🟡 | We dedup + resume + clear-all; no per-item delete or sort order. |
| A7 | Clear history | MiscFooter.jsx:65 | ✅ | |
| A8 | Favourites (local star) | favoritePane.jsx | 🟡 | Ours local; STTM cloud. Named collections not done (A14). |
| A9 | **Keyboard: Ctrl+1..6 (quick inserts + windows)** | Launchpad.jsx:165 | 🟡 | We have arrows/space/pgup-dn/home/end/esc; not Ctrl+1..6, Ctrl+/, Ctrl+C, Ctrl+G. |
| A10 | Arrows/space/enter shortcuts | Launchpad.jsx | ✅ | |
| A11 | **Shortcut legend / Help window** | controller.js:199 | ⬜ | Reference windows. |
| A12 | **Changelog window + "what's new" notifications** | app.js:134 | ⏭️ | Analytics/notifications - dropped by design. A plain in-app changelog is optional. |
| A13 | **Auto-update** | app.js:213 | ⬜ | E2. Real (electron-updater analog for Flutter desktop). |
| A14 | Analytics / statistics | analytics.js | ⏭️ | Dropped by design (no telemetry). |
| A15 | Native app menu + window controls | controller.js:62 | 🟡 | We use OS window chrome; no custom native menu. |
| A16 | Random shabad / Daily hukamnama (Others pane) | OtherPane.jsx | 🟡 | See N13/N14. |

---

## Proposed milestone build order

Grouped so each milestone is a coherent, shippable step; every item runs the superpowers loop (grill → spec → subagents → test). ⏭️ items are excluded from build (design clashes) but stay in the inventory.

**M-α — Presenting depth (finish the operator's daily surface).** The cheap, high-value gaps a live operator hits first.
- N9 Next-line preview · N11 Copy line (Ctrl+C) · N14 Random shabad · N16 flower-verse skip
- A9 keyboard Ctrl+1..6 / Ctrl+/ / Ctrl+G · A6 history per-item delete + sort · S22 Ctrl+/ focus
- S18 result highlighting · S19 english translit line · S16 keyboard matra page

**M-β — Autoplay & continuous reading.**
- N7 Autoplay + delay (on-slide play/pause + speed) · N8 Akhand Paath continuous mode · N17 minimize
- D19 only-gurbani layout · D21 Padding Tools · D22 Quick Tools in-viewer panel

**M-γ — Themes & backgrounds (visual parity).**
- D14 named themes · D15 image backgrounds · D16 video backgrounds · D17 custom upload
- D18 high-contrast/low-light · D5 larivaar-assist · D3 vishraam gradient
- O4 overlay style config (layouts/presets/logo/green-screen) · O2 auto-place on external display

**M-δ — Content sources & data (needs the D-pipeline).** Blocked on baking more data (build_corpus.py Phase 1 done; this is the next data drop).
- D11 per-row content sources (teeka/translation) · D10 per-row visibility · D12 transliteration language · D4 vishraam source · D20 custom-english HTML · S8 main-letters search · O5 live-feed text files

**M-ε — Ceremonies (data D1 → UI A1).**
- B5-B9 ceremonies (extract from realm, our own interlude prose) · B13 rich-text announcements · B14 Dhan Guru slides · B16 lock screen · B15 custom image slide (after D15)

**M-ζ — Workspaces & multi-pane (structural).**
- A2 workspaces (Single/Presentation/Multi-Pane) · N15 multi-pane · A11 help/legend · A13 auto-update

**Deferred/replaced (not built):** S25 voice search (→AI follow), O6 Chromecast, O7 Zoom CC, O8 bani-controller cloud sync, A14 analytics, A12 changelog/notifications telemetry, B17 SSO, N13 daily hukamnama (network) - reconsider a local variant later.

---

## First feature to build

**M-α, starting with Next-line preview (N9)** - highest daily value, self-contained, and it composes with the display/overlay work just shipped. Runs the full superpowers loop next.
