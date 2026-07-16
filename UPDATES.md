# Gurbani Live - STTM Parity Tracker

This file tracks how close Gurbani Live is to [SikhiToTheMax](https://github.com/khalisfoundation/sttm-desktop) (STTM) desktop, feature by feature.
It is derived from a full read of the STTM source (Electron + React/easy-peasy, content in a local Realm DB), so each row maps a real STTM behaviour to our status.
It is a living document: update the relevant row in the same change that ships the feature.

Two things are deliberately different from STTM, by design:

- STTM's projector renders from its own copy of the DB and receives only state deltas; our line data is small, so the overlay receives the resolved display data instead (simpler, same result on screen).
- STTM's voice search calls a remote transcription endpoint; we replace that entirely with on-device ASR auto-follow, which is the whole point of this app.

The corpus and all APIs are on-device and local-only. No network calls to BaniDB or STTM services.

## Legend

- ✅ Done
- 🟡 Partial (works, but narrower than STTM)
- ⬜ Not started
- ⏭️ Deferred or intentionally skipped (with reason)

## Search

| STTM feature | Status | Notes |
|---|---|---|
| First-letter search (start / anywhere) | ✅ | FTS5 + bm25 over `first_letters_uni`. |
| Full-word Gurmukhi search | ✅ | |
| Full-word English search | ✅ | LIKE over the bundled translations (11-44ms), matched line shown on the tile. |
| Ang (page) search | ✅ | Explicit Ang type like STTM, source-scoped (SGGS default, Source filter overrides). |
| Source / writer / raag filters | ✅ | Filter row on the search pane; Writer/Raag disable in Ang mode. |
| Scroll shabad to the searched line | ✅ | Better than STTM: jumps to the exact tapped line. |
| Voice search (remote endpoint) | ⏭️ | Replaced by on-device AI auto-follow. |

## Shabad navigation

| STTM feature | Status | Notes |
|---|---|---|
| Prev / next line, tap a line | ✅ | Nav toolbar on the shabad pane. |
| Prev / next shabad (Ang order) | ✅ | Steps to the adjacent shabad, not just the next line. |
| Autoscroll to the active line | ✅ | Skips a single-line shabad and lines already on screen. |
| Home / Rahao marker + snap-back | 🟡 | AI auto-follow drives the active line; an explicit Rahao marker + manual snap is not surfaced. |
| Next-line preview | ⬜ | |
| Autoplay (timed advance) | ⬜ | |
| Akhand Paatt continuous mode | ⬜ | |

## Display and rendering

| STTM feature | Status | Notes |
|---|---|---|
| Larivaar toggle | ✅ | Larivaar-assist shading not done. |
| Vishraam toggle | ✅ | Colours the pause word; source selection not done. |
| Left-align option | ⬜ | Centred only. |
| Slide transitions | ⬜ | |
| Per-slide font sizing | 🟡 | Global font-scale stepper; not per content row. |
| vh-scaled slide fonts on the output | ✅ | Overlay text sized in vh, scales to display height. |

## Content rows (teeka / translation / transliteration)

| STTM feature | Status | Notes |
|---|---|---|
| Punjabi teeka row | ✅ | Sahib Singh. |
| English translation row | ✅ | Sant Singh Khalsa. |
| Transliteration row | ✅ | Roman; Devnagri bundled but not shown. |
| Hindi / Spanish translations | ⬜ | |
| Per-row selectable source | ⬜ | Fixed source per row for now. |
| Per-overlay content selection | ✅ | Better than STTM: each output picks its rows via `?show=` on the overlay URL. |

## Themes and backgrounds

| STTM feature | Status | Notes |
|---|---|---|
| Solid background presets | ✅ | Navy / Midnight / Graphite / Black. |
| Light / Dark / High-Contrast / Low-Light themes | 🟡 | Dark operator theme + kesari design system; the named theme set is not built. |
| Bundled image backgrounds | ⬜ | |
| Custom image background | ⬜ | |
| Video (mp4) background | ⬜ | |

## Banis, ceremonies, slides

| STTM feature | Status | Notes |
|---|---|---|
| Sundar Gutka (Nitnem banis) | ✅ | Bani drawer, all BaniDB banis in STTM's id order; incl. Anand Sahib Bhog (pauris then salok) + standalone Salok (Pavan Guru), bridged from the corpus. |
| Bani length (Short/Medium/Long/Extra Long) | ✅ | STTM's exact 4 tiers; length data fetched once from BaniDB and baked into a local `sundar_gutka.sqlite`. Settings picker re-loads the bani at the chosen length. |
| Bani names Gurmukhi / English | ✅ | Gurmukhi by default, ਪੰ/EN toggle in the bani drawer. |
| Data sources + update strategy | ✅ | Documented in DATA.md (open ShabadOS DB vs STTM Realm, what's curated, how to refresh). |
| Ceremonies (Anand Karaj / Bhog / Akhand Paath) | ⬜ | |
| Rich-text announcements | ⬜ | |
| Dhan Guru slides | ⬜ | |

## History, favourites, quick insert

| STTM feature | Status | Notes |
|---|---|---|
| History (dedup, resume) | ✅ | Deduped; persists across launches (shared_preferences). |
| Favourites | ✅ | Local (no account): star from the shabad pane, Favorites tab, persisted. Named collections still to come. |
| Quick Insert: Waheguru / Mool Mantar / blank | ✅ | Modelled as one-line synthetic shabads. |
| Quick Insert: Anand Sahib Bhog / announcement | ✅ | Bhog = one tap to the bani; announcement = typed text slide. |
| Quick Insert: custom image | ⬜ | Needs image display in the projected pane. |

## Workspaces and hotkeys

| STTM feature | Status | Notes |
|---|---|---|
| Workspaces (Single / Presentation / Multi-Pane) | 🟡 | One responsive presentation layout; not switchable presets. |
| Settings screen | ✅ | An end-drawer (app-bar gear) holding display + background + projector/overlay controls. |
| Keyboard shortcuts | ✅ | Arrows / space = line, PageUp/Dn = shabad, Home/End, Esc = blank. Focus-search hotkey + ctrl+1..6 not yet. |

## Outputs

| STTM feature | Status | Notes |
|---|---|---|
| Second-screen projector | 🟡 | Native fullscreen output window (webview, no 2nd Flutter engine) done; auto-placement on the extended display pending. |
| OBS browser-source overlay | ✅ | Dart HTTP + WebSocket overlay; adds per-overlay `?show=` content control. |
| Chromecast | ⏭️ | Deferred. |
| Zoom closed-captions | ⏭️ | Deferred. |
| Live-feed text files | ⬜ | |

## AI auto-follow (our differentiator, not in STTM)

| Feature | Status | Notes |
|---|---|---|
| Mic auto-follow (on-device ASR) | ✅ | sherpa-onnx CTC + VAD in a Dart isolate. |
| Follow an audio / video file (karaoke sync) | ✅ | Transcribing % + play / pause / seek. |
| Audio-source picker (system audio / mic) | ⬜ | OBS-style input selection. |
| Human-in-the-loop training capture | ⬜ | Phase 4: log corrections as training pairs. |
| Finetune pipeline | ⬜ | Phase 5. |

## Infrastructure

| Item | Status | Notes |
|---|---|---|
| On-device, local-only corpus | ✅ | ShabadOS SQLite (141k lines), FTS5; no network APIs. |
| Persisted settings + history | ✅ | shared_preferences: bani length (global), name language, display options, history survive a restart. |
| Maximize-on-open (frameless-ish) | ✅ | `window_manager`. |
| macOS sandbox entitlements for overlay + output window | ✅ | `network.server` + `network.client`. |
| Auto-update | ⬜ | |
| Analytics | ⏭️ | Not planned. |
