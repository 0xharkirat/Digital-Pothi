# Epic B - AI Live Transcription and Auto-Follow

**GitHub:** [#16](https://github.com/0xharkirat/Digital-Pothi/issues/16) - sub-issues are linked on the parent.

**Goal:** the app follows a live recitation on its own and gets better over time.
This is the differentiator; STTM has no equivalent (its voice search is a remote endpoint we replace with on-device ASR).

**Done already:** on-device ASR (finetuned IndicConformer CTC + Silero VAD in a Dart isolate), mic auto-follow, file follow with play / pause / seek transport, the discover-mode tracker (locate then anchor window then follower, with a rolling buffer for kirtan fragments).
Measured: kirtan tracking proven; a Golden Temple livestream eval hit ~93% correct ang.

Open sub-issues below.

## B1 - Live audio-source picker (system audio / mic) 🔴 P1

**Area:** tracking/audio

Live use needs to choose the input like OBS does: a specific microphone, or system / loopback audio (following a YouTube livestream or a house feed), not only the default mic or a file.

**Acceptance:**
- [ ] Enumerate input devices and pick one.
- [ ] Capture system / loopback audio where the platform allows.
- [ ] The chosen source feeds the existing VAD then CTC pipeline unchanged.
- [ ] The choice is persisted.

## B2 - Human-in-the-loop correction capture 🔴 P1

**Area:** training/data · **Was:** task #19

When the operator corrects the AI (taps the right line after a wrong follow), log that as a labelled training pair: the audio window plus the confirmed line.
This turns real use into training data.

**Acceptance:**
- [ ] On a manual correction during follow, capture the audio segment and the confirmed line id.
- [ ] Store pairs locally in a stable, exportable format.
- [ ] A visible, revocable consent / on-off for capture.
- [ ] An export command produces a training-ready dataset.

## B3 - Finetune pipeline 🔴 P1

**Area:** training/pipeline · **Was:** task #20

Take captured (and livestream-eval) pairs, finetune the CTC model, and redeploy the ONNX into the app.
Training runs on the Acer Nitro (i5, GTX 1650 4-6 GB) locally or over SSH.

**Acceptance:**
- [ ] A script that builds a training set from B2 pairs plus the livestream ground truth.
- [ ] A finetune run that fits the GTX 1650 (batch / precision tuned).
- [ ] Export to ONNX and validate via sherpa-onnx against the eval set.
- [ ] A measured WER / ang-accuracy improvement over the current model before shipping.

## B4 - Livestream auto-eval harness 🔴 P2

**Area:** training/eval

The SGPC Golden Temple livestream shows an on-screen banner of the current shabad.
OCR that banner (tesseract `pan`), snap it to the corpus with `locate`, and you get free, automatic ground truth for eval and training, with no manual timestamping.

**Acceptance:**
- [ ] Pull a livestream, OCR the banner per interval, snap to a line id.
- [ ] Align to the ASR track to produce (audio window, line id) pairs.
- [ ] A repeatable eval report (ang accuracy, line accuracy, catch-up lag).

## B5 - Follow robustness and catch-up feedback 🔴 P2

**Area:** tracking

Real recitation drifts, repeats, and pauses.
Tighten the follower and show the operator when the AI is confident vs catching up.

**Acceptance:**
- [ ] A confidence signal surfaced in the UI (following vs catching up).
- [ ] Tuned hysteresis / lead so paath and kirtan both hold.
- [ ] Graceful re-locate when the follower loses the thread.

## B6 - AI next-line suggestion, human confirms 🔴 P2

**Area:** tracking/ux · **Related:** A7

Instead of the AI always driving, offer a suggested next line the operator can accept with one key.
Lower-risk mode for high-stakes diwans, and it feeds B2.

**Acceptance:**
- [ ] A suggestion appears ahead of the live line.
- [ ] One key accepts it (and logs a positive pair).
- [ ] A setting chooses auto-drive vs suggest-only.
