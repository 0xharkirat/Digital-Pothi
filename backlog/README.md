# Gurbani Live - Backlog

The plan of record for what we build, in what order, and why.
It exists so we stop building things in random order.

This backlog is forward-looking: it tracks the work that is still open.
What is already built is recorded in [UPDATES.md](../UPDATES.md) (the STTM parity tracker) and in git history, so it is not repeated here as open work.
The data-sourcing background is in [DATA.md](../DATA.md).

## How this maps to GitHub

Each **epic** file is a parent issue.
Each `##` section inside an epic is a sub-issue of that parent.
Every sub-issue has a stable id (A1, B2, ...) so it can be referenced from commits and from other issues.
When we push (after 6pm), we create one GitHub issue per epic, then one sub-issue per section, and link them as parent/child.

## Status and priority

- ✅ done, 🟡 partial, 🔴 todo
- P0 blocks daily use · P1 high value · P2 normal · P3 nice-to-have · ⏭️ deferred

## Epics

| Epic | Theme | Open items |
|---|---|---|
| [A - Presenter Parity](epic-a-presenter-parity.md) | Reach STTM desktop feature parity | ceremonies, themes, backgrounds, search filters, workspaces, more hotkeys, collections |
| [B - AI Live Transcription](epic-b-ai-live-transcription.md) | The differentiator: auto-follow + the training loop | audio-source picker, correction capture, finetune pipeline, eval harness |
| [C - Projection & Outputs](epic-c-projection-outputs.md) | Projector / OBS / second screen | auto second-screen, true fullscreen, live-feed |
| [D - Corpus & Data](epic-d-corpus-data.md) | On-device data + how it stays current | ceremony data, one-time download, refresh workflow |
| [E - Foundation & Quality](epic-e-foundation-quality.md) | CI, packaging, tests, updates | CI, auto-update, packaging, coverage |

## Roadmap (build order)

We build by milestone, not by whim.
Each milestone is a coherent, shippable step.

### Milestone 1 - Usable for a real live program

The app already presents; this makes it hold up in an actual diwan.

- B1 Live audio-source picker (system audio / chosen mic)
- C1 Auto-place the output window on the extended display
- A4 English + Ang search
- A7 Home / Rahao (asthaai) marker and jump

### Milestone 2 - The AI moat

The reason this project exists.
Close the loop from live audio to a model that improves.

- B4 Livestream auto-eval harness (SGPC banner OCR as free ground truth)
- B2 Human-in-the-loop correction capture
- B3 Finetune pipeline (train on the GTX 1650, redeploy the ONNX)
- B6 AI next-line suggestion, human confirms

### Milestone 3 - Ceremonies and content depth

- D1 Ceremony sequence data (source it)
- A1 Ceremonies UI (Anand Karaj, Akhand Paath Bhog)
- A14 Named collections
- A13 Custom image slide, A12 rich-text announcements

### Milestone 4 - Visual parity and polish

- A2 Themes, A3 image and video backgrounds
- A6 More translations (Hindi, Spanish) with per-row source selection
- A9 Left-align and slide transitions, A10 workspaces, A11 more hotkeys

### Milestone 5 - Distribution and quality

- E1 CI, E4 wider test coverage
- D2 One-time on-device DB download (updates without an app release)
- E2 Auto-update, E3 packaging (macOS notarize, Windows, Linux)

## What is already built (summary)

Presenter: search (first-letter + full-word), shabad + line navigation, larivaar / vishraam / font / solid backgrounds, settings drawer, history, favorites, quick insert (Waheguru / Mool Mantar / Anand Sahib Bhog / Announcement / blank), full Sundar Gutka bani list in STTM order with the four length tiers, Gurmukhi / English names, keyboard control.
AI: on-device ASR (finetuned IndicConformer CTC + Silero VAD), mic auto-follow, file follow with transport.
Outputs: LAN overlay with per-overlay content control, native fullscreen output window.
Foundation: bundled ShabadOS corpus + BaniDB bani-length data, persisted settings / history / favorites, 77 tests.

See [UPDATES.md](../UPDATES.md) for the full done/partial/pending matrix.
