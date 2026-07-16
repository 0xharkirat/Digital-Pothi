# Digital Pothi (Gurbani Live)

An open-source Gurbani presenter for the sangat - search, project, and present shabads and banis - with on-device AI that listens to kirtan or paath and follows the verse being recited, live.

Think SikhiToTheMax-desktop-class presenting, plus a differentiator STTM does not have: fully local, no-network AI auto-follow.
The operator searches and drives slides as usual; flip on Follow and the display tracks the raagi on its own.

Everything runs on-device.
The full corpus (Sri Guru Granth Sahib and the other sources, 141k lines), translations, transliterations, Sundar Gutka banis, and the speech models are local.
No network calls to BaniDB, STTM, or any transcription service.

## What works today

- Search: first-letter (start / anywhere), full-word Gurmukhi, full-word English, Ang - with writer / raag / source filters.
- Shabad presenting: line and shabad navigation, autoscroll, history, favorites, keyboard control.
- Home (asthaai) verse + STTM-style intelligent spacebar for kirtan flow.
- Sundar Gutka: the full bani list with Short / Medium / Long / Extra Long lengths.
- Quick inserts: Waheguru, Mool Mantar, Anand Sahib Bhog, announcements, blank.
- Display: larivaar, vishraam colouring, font scaling, background presets, Gurmukhi/English bani names, persisted settings.
- Outputs: native fullscreen output window plus a LAN overlay (OBS browser source / projector) with per-overlay content selection.
- AI auto-follow: mic or audio-file input → Silero VAD → IndicConformer-CTC (sherpa_onnx) → verse tracker.

The feature-by-feature parity ledger against STTM desktop lives in [UPDATES.md](UPDATES.md).
The roadmap is the epic files in [backlog/](backlog/) (mirrored as GitHub issues).

## Architecture

```
Flutter/Dart (macOS · Windows · Linux; mobile later)
  ├─ presenter: bloc cubits over a bundled SQLite corpus (FTS5)
  ├─ engine:    normalize → indexed retrieval → follower (pure Dart)
  ├─ asr:       sherpa_onnx (native onnxruntime) - mic → VAD → CTC → Gurmukhi
  └─ outputs:   native output window + Dart HTTP/WebSocket overlay server
```

No Python ships in the app.
Python under `tools/` is dev-only (corpus build, data fetch, eval, UI-test driver).

## Getting the data and models (not in git)

Two large assets are gitignored and needed at `assets/`:

1. `assets/corpus/gurbani.sqlite` (~100 MB) - built from the open [ShabadOS database](https://github.com/shabados/database) plus translations/transliterations by `tools/enrich_corpus.py`.
   `assets/corpus/sundar_gutka.sqlite` (small, checked in) is produced by `tools/fetch_bani_lengths.py` from the BaniDB API - a dev-time step, never a runtime call.
2. `assets/models/` - `indicconformer-pa-ctc.onnx` (finetuned `surindersinghssj/indicconformer-pa-v3-kirtan`, CTC head, sherpa metadata injected), `tokens.txt`, `silero_vad.onnx`.
   The published HF ONNX lacks sherpa's metadata (`vocab_size`, `normalize_type`, ...); inject `vocab_size=257, subsampling_factor=4, normalize_type=per_feature, model_type=EncDecCTCModel, feat_dim=80`, or re-export from the `.nemo` with sherpa-onnx's NeMo-CTC script.

A one-command fetch script is on the backlog (Epic D).

## Run

```bash
flutter pub get
flutter run -d macos
```

```bash
flutter analyze && flutter test
```

## Credits

- [SikhiToTheMax desktop](https://github.com/khalisfoundation/sttm-desktop) - the presenter feature bar this project measures itself against.
- [ShabadOS database](https://github.com/shabados/database) and [BaniDB](https://banidb.com) - the open Gurbani data this app bundles.
- `surindersinghssj/indicconformer-pa-v3-kirtan` - the finetuned Punjabi ASR model.
