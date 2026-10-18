# Spec: v1 Sunday autopilot

**Date:** 2026-10-19.
**Status:** draft for Hark's review. The GitHub issues come from this file after he approves it.
**Sources:** the confirmed intent ([docs/intent/sunday-autopilot.md](../intent/sunday-autopilot.md)), the refined idea ([docs/ideas/sunday-autopilot.md](../ideas/sunday-autopilot.md)), and a doubt review by 3 models (Claude, Codex, agy) on 2026-10-19.

This spec is the plan of record for the AI follow.
The STTM feature inventory ([2026-07-25-sttm-feature-inventory.md](2026-07-25-sttm-feature-inventory.md)) stays the plan of record for presenter parity, but parity work waits until v1 passes its bar.

## Objective

The gurdwara's Sunday morning program shows the right Gurbani line with no sevadar at the laptop.
1 person starts the app at the start of the program and stays nearby to fix a wrong line.
v1 puts Sukhmani Sahib and Japji Sahib on autopilot first.
Kirtan follows in shadow mode: the app follows it and scores it, but does not show it.

The users:

- The sangat reads the main screen and the livestream overlay.
- The sevadar starts the program once and fixes a wrong line with 1 action.
- The raagi and the paathi change nothing.

## The bar

v1 passes when every Sunday in the test set passes these rules.
The rules are exact, so that 2 scorers always give the same verdict.

### Time and truth

- The scorer works on a 0.1 s grid over the whole recording.
- Truth is a list of spans: `start`, `end`, and `line_id` (a main-corpus line id), or `none` for speech that is not recitation (katha, ardaas, announcements), or `unknown` where truth is not sure.
- A recitation span is a span with a `line_id`.

### What each grid point scores

The grid point is scored by what the main screen shows at that time:

| Truth at the point | Screen shows | Score |
|---|---|---|
| line L | L | right |
| line L, which started less than 1.5 s ago | the line before L | right (lag allowance) |
| line L | any other line | wrong |
| line L | blank, or a held line other than L | missed |
| `none` or silence | a held line, or blank | neutral |
| `none` or silence | a line that changed during this span | wrong |
| `unknown` | anything | not scored |

### The 2 numbers

- **Right share:** right time divided by recitation time, over the parts on autopilot. It must be at least 97.0%.
- **Wrong episodes:** an episode is a run of wrong grid points. 2 runs less than 1.0 s apart count as 1. At most 1 episode longer than 3.0 s is allowed per Sunday.

### Coverage and the test set

- A Sunday counts as scored only when `unknown` covers less than 5% of the autopilot parts' recitation time. An unscored Sunday does not pass.
- The date splits the Sundays. The newest 8 recorded Sundays are the test set. Nobody tunes a threshold, a constant, or a model choice on them. The older Sundays are the tuning set.
- Before autopilot goes live in the hall, 1 live Sunday on the Mac mini must also pass, scored from its own recording.
- The scorer scores kirtan the same way but separately. Kirtan is not part of the v1 denominator until it graduates.

## Capability map

v1 has 7 modules. Each issue belongs to exactly 1 module, by its id.

| Module id | Responsibility | Depends on |
|---|---|---|
| `scorer` | The truth file format and the scorer for the bar above. | none |
| `replay` | Feeds a recorded Sunday through the live follow path in simulated time, and writes what the screen showed. | `scorer`, `pipeline` |
| `truth` | Dev tools: download the Sunday audio, align the known banis with 2 aligners, mark `unknown` spans, sample spans for the human check. | `scorer` |
| `pipeline` | The live audio path: input device, fixed windows decoded in a background isolate, fail-closed errors, model version stamp. | none |
| `follower` | The program script, item detection, known-bani following, the hold gate, katha hold, and lost-track blanking. | `pipeline` |
| `display` | Line, hold, and blank states from the tracker to the screen and the overlay; overlay heartbeat; manual correction that keeps autopilot on. | `follower` |
| `operator` | 1-action Sunday start, the persisted input device, and a stable overlay address. | `pipeline`, `display` |

Build order: `scorer` → `truth` and `pipeline` (in parallel) → `replay` → `follower` → `display` → `operator`.
The 1st go/no-go point comes after `replay`: the current follower gets a real baseline score before any follower change.

## Module requirements

### `scorer`

- The truth file is JSON Lines, 1 span per line: `{"start": 12.3, "end": 15.1, "line_id": "...", "source": "aligned-2model"}`. `line_id` may also be `"none"` or `"unknown"`.
- The screen log has the same shape, with `state` set to `line`, `hold`, or `blank`.
- The scorer is pure Dart under `lib/eval/`, with no Flutter imports, so `flutter test` runs it in every factory worktree.
- It prints the right share, the wrong episodes with their times, the coverage, and a 1-line verdict: `PASS`, `FAIL`, or `UNSCORED`.

### `truth`

- `tools/harvest_sunday.py` downloads 1 stream's audio with `yt-dlp` and writes 16 kHz mono FLAC.
  The files live on the Nitro 5's SMB share, never in git.
- The program parts of each Sunday come from a small hand-written file per Sunday, for example `sukhmani 00:12:40-01:31:10`.
  Marking 4 to 6 part boundaries per Sunday is not line matching, and it takes about 2 minutes.
- 2 aligners from different model families align each known bani to its part.
  The 1st is the current IndicConformer CTC. The 2nd is another family, such as MMS-FA or Omnilingual 300M CTC.
  A line is `aligned-2model` when both start times agree within 1.0 s. Otherwise it is `unknown`.
- Alignment runs in chunks of at most 10 minutes, so it fits in the GTX 1650's memory.
- The human check: a tool picks 100 random 10-second spans across the test Sundays, plays each one, and shows the truth line. The person answers yes or no.
  The truth passes at 99 or more yes answers.
  The person only checks a line and never searches for one, so this is not line matching.

### `pipeline`

- 1 live path for the mic and for replay: fixed 6 s windows on a 1.5 s hop, decoded in a background isolate.
  VAD only marks silence. It no longer cuts the windows.
- The operator chooses the input device from the system's input list, and the app keeps that choice.
- Any start or device error stops the follow, shows the error, and sends the screen to hold. It never leaves "following" on with no audio.
- `macos/Runner/Info.plist` gets `NSMicrophoneUsageDescription`. This is a risky path, so Hark reviews it.
- The bundled model copy carries a version stamp, like the corpus, so a new model replaces the old copy.
- Budget: on the Mac mini M4 with OBS streaming, 1 window decodes within 1.0 s.
  The screen changes within 1.5 s of the window's end.

### `follower`

- The program script is a list of allowed items: banis by main-corpus bani id, plus `kirtan` and `katha`. The order is not fixed.
- Item detection: when no item is active, the follower matches the windows against the opening lines of each allowed bani. It starts an item only on a match that clears the anchor threshold over the joined locate window.
- Known-bani following: inside a bani, the position moves forward only. It may repeat the current line and step back at most 1 line. It ends the item after the bani's last line.
- The hold gate: the line changes only when the next line's similarity beats the current line's by a margin, in 2 consecutive windows. A jump outside the forward horizon also needs the escape threshold.
- Katha hold: when windows stop matching the current bani's horizon for 6 s while speech goes on, the screen holds the last line. It never shows a quoted line from outside that horizon.
- Lost track: the windows match strongly somewhere else in the bani, but the gate confirms no position for 4 s.
  Then the screen blanks, because a wrong held line is worse than a blank screen.
- Tracker lines always resolve through the main corpus (`baniLines`, where Japji Sahib is bani 1). They never use the Sundar Gutka database ids (`sg:` lines, where Japji Sahib is 2).

### `display`

- The tracker state can express 3 states: a line, hold, and blank. `copyWith` must be able to clear the verse.
- The presenter, the native output window, and the overlay all show blank as a true blank, not the faded `ੴ`.
- The overlay server sends a heartbeat every 2 s. The overlay page blanks itself when it gets no heartbeat for 10 s, so a crashed app leaves no stale line.
- A manual line pick during autopilot re-anchors the follower at that line, and autopilot goes on. Only the explicit stop control turns autopilot off.

### `operator`

- 1 control starts the Sunday program: it loads the program script, turns the overlay on, opens the persisted input device, and starts the follow.
- The overlay address stays the same each week: the app shows a `.local` host name or a chosen interface, never the first interface it finds.

### Later, not in v1: kirtan graduation

- Kirtan truth needs the shabad first. The planned method is offline locate over the whole kirtan span, then 2-aligner alignment with repeats allowed, then the same 100-span human check.
- This becomes its own spec after v1 passes on the fixed banis.

## Tech stack

- Flutter 3.47.4 and Dart 3.12, desktop macOS first (Apple M1 to M5).
- `sherpa_onnx` 1.13.4 with the finetuned IndicConformer CTC ONNX model (482 MB fp32; the int8 export only after it passes the bar).
- `record` 7.1.1 for audio, `flutter_bloc` 9 for state, `bloc_test` and `mocktail` for tests.
- Python 3.11 or later for dev tools only, run as `uv run` scripts with inline dependencies. No Python ships in the app.

## Commands

The factory's gates, as `factory/factory.json` defines them:

```bash
flutter analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
flutter test
flutter build macos --debug
```

The v1 tools, once their modules exist:

```bash
# Score 1 Sunday from its truth and screen log (scorer)
dart run tool/score_sunday.dart --truth <truth.jsonl> --screen <screen.jsonl>

# Replay 1 Sunday through the live follow path (replay); skips when the data folder is missing
GURBANI_REPLAY_DIR=<folder> flutter test test/replay/sunday_replay_test.dart

# Harvest and align 1 Sunday (truth)
uv run tools/harvest_sunday.py --video <id> --out <folder>
```

## Project structure

```text
lib/eval/          scorer: pure Dart, no Flutter imports
lib/engine/        follower logic: program script, known-bani follow, hold gate
lib/tracking/      TrackingCubit and state: line, hold, blank
lib/asr_service.dart, lib/engine/transcribe_isolate.dart   pipeline
lib/overlay/       overlay server and page: heartbeat, true blank
test/eval/         scorer tests with small hand-made truth files
test/replay/       the replay test, driven by GURBANI_REPLAY_DIR
test/fixtures/     small cached window transcripts and truth spans, checked in
tool/              Dart command-line entry points
tools/             Python dev tools (harvest, align, span check)
```

## Code style

Follow the existing code.
Name each calibration knob, and say in its doc comment what it trades off and how it was measured:

```dart
/// Minimum score, over the joined [locateWindow], before we anchor on a hit.
/// A real shabad's asthaai accumulates past ~0.5 across a dozen chunks; the
/// garble an instrumental passage transcribes to tops out near 0.4, so the bar
/// sits between them. (File mode has no VAD, so it transcribes the music too.)
final double anchorThreshold;
```

The repo also follows the VGV bloc conventions: 1 state class per cubit, and a Page and View split.

## Testing strategy

- Every follower rule gets a unit test on small, hand-made window sequences: forward step, repeat, back 1, item start, item end, katha hold, lost-track blank.
- The scorer gets a test for every row of the scoring table, and for episode merging.
- Each factory job runs on the checked-in fixtures only. The 77 hours of audio never enter a worktree.
- The full replay runs on a developer machine with `GURBANI_REPLAY_DIR`, and its scorecard goes into the PR.
- A change to a calibration knob must show the tuning-set scorecard before and after. It never shows the test set until the release check.

## Boundaries

- **Always:**
  - Keep every displayed line a canonical main-corpus line.
  - Run the gates before a commit.
  - Keep the test Sundays out of tuning.
- **Ask first:**
  - Add a dependency, such as an aligner package or an ONNX runtime binding.
  - Change `Info.plist` or the entitlements.
  - Change the model file or its version stamp.
  - Use the network at runtime.
- **Never:**
  - Use the stream overlay or the sevadar's STTM lines as truth.
  - Commit audio or model files.
  - Tune on the test Sundays.
  - Publish recordings of the sangat.

## Changes to earlier decisions

This spec changes 9 earlier decisions:

| Earlier decision | Where it lives | Change |
|---|---|---|
| Human-confirm, never autopilot | R3 (`docs/wayfinder/research/R3-deployment-reality.md`) | Autopilot with a hold gate and a 1-action fix. The rule "never show a wrong line" stays as the bar's wrong-episode limit. |
| T1: v1 scope is open | `docs/wayfinder/tickets/T1-epic1-scope.md` | Resolved: the Sunday program; fixed banis first, kirtan in shadow mode. |
| T2: on-device or network | `docs/wayfinder/tickets/T2-ondevice-vs-network.md` | Resolved: on-device at runtime. Only the dev machines use the network. |
| B4: banner OCR as ground truth | `backlog/epic-b-ai-live-transcription.md` | Replaced: 2-aligner truth from the known text. Banner OCR is never truth. |
| R1: livestream OCR as the data flywheel | R1, section E | Replaced for this gurdwara: the overlay is mostly absent and often wrong. |
| B1: system loopback capture | backlog B1 (#17) | Narrowed: choose an input device. Loopback is out of v1. |
| B2: operator corrections as training pairs | backlog B2 | Deferred: the sevadar's lines are not truth. Corrections re-anchor the follower only. |
| Roadmap: Milestone 2 after Milestone 1 | `backlog/README.md` | The AI follow comes first. Parity milestones wait until v1 passes. |
| The idea page's runtime aligner signal | `docs/ideas/sunday-autopilot.md` | Dropped from v1: sherpa-onnx 1.13.4 returns no log-probabilities, so the gate uses text signals over 2 windows. A runtime aligner is a later option. |

The rest stays as decided: on-device only, the canonical-line rule, WCAG 2.2 AA (T4), and the STTM inventory for parity.

## Assumptions to confirm

These defaults are Claude's choices. Hark confirms or changes each one when he reviews this spec:

1. The lag allowance is 1.5 s. GAB uses 1.0 s.
2. The test set is the newest 8 Sundays.
3. The human check is 100 spans of 10 s, with a pass at 99 or more.
4. The hop is 1.5 s, because Japji Sahib runs at about 2.8 s per line.
5. Katha hold starts after 6 s of no match, and lost-track blank after 4 s.
6. A part-boundary file per Sunday, written by hand in about 2 minutes, does not count as line matching.

## Open questions

- **Build here, or contribute to STTM Voice-Follow?** Khalis already ships a follow (9.0.4) and owns the GAB benchmark. The `scorer`, `truth`, and `replay` modules are useful either way.
- **Which second aligner?** The MMS-FA weights are CC-BY-NC-4.0, which conflicts with later monetization. Omnilingual 300M CTC needs a license check, a Punjabi check, and an export check.
- **May v1 use the `surindersinghssj` v4 datasets for training later?** Most of them carry no license tag. Ask the author first.
- **GAB access.** It is private to Khalis members. Hark can ask, but v1 cannot depend on it.
