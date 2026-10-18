# Plan: v1 Sunday autopilot

**Date:** 2026-10-19.
**Spec:** [docs/spec/2026-10-19-v1-sunday-autopilot.md](../spec/2026-10-19-v1-sunday-autopilot.md).
**Tracker:** GitHub Issues in `0xharkirat/Digital-Pothi`, under the epic "Epic V - v1 Sunday autopilot".
This file is the ordered index of those issues. The issues hold the acceptance criteria and the Verify commands.

## Overview

v1 measures first, then changes the follower.
The 1st go/no-go point is checkpoint A: a real score for today's follower on the tuning Sundays.
Every later change has to beat that score, and only the release check sees the test Sundays.

## Architecture decisions

- **1 live path.** The mic and the replay both use 6 s windows on a 1.5 s hop. The replay feeds cached window texts into the same mic-mode code, with no look-ahead.
- **Truth from the known text only.** 2 aligners from different model families must agree within 1.0 s. The overlay and the sevadar's lines are never truth.
- **A text-only hold gate in v1.** sherpa-onnx 1.13.4 returns no log-probabilities, so the runtime gate uses similarity over 2 windows. A runtime aligner is a later option.
- **3 display states.** A line, hold, or blank, from the tracker to the overlay, with a heartbeat so a dead app leaves no stale line.
- **Milestones set the build order.** The factory takes issues by milestone title, then by issue number, and it has no dependency links. The 4 v1 milestones (`M0.1` to `M0.4`) sort before the old `M1` to `M5`.

## Task list

The issue numbers are filled in when the issues exist.

### M0.1 - v1 foundations (no v1 dependency; can run in parallel)

- [ ] #V1 Score a Sunday against the v1 bar (`scorer`, P1)
- [ ] #V2 Fixed live window schedule, 6 s and 1.5 s (`pipeline`, P1)
- [ ] #V3 The tracker can show a line, hold, or blank (`display`, P1)
- [ ] #V4 Overlay: a true blank, and blank when the app goes silent (`display`, P1)
- [ ] #V5 Choose the audio input device (`pipeline`, P1)
- [ ] #V6 Fail closed when the mic cannot start (`pipeline`, P1)
- [ ] #V7 Replace the cached model copy when the model changes (`pipeline`, P2)
- [ ] #V8 Dev tool: harvest 1 Sunday's audio (`truth`, P1)
- [ ] #V9 Dev tool: cache the window transcripts of a Sunday (`replay`, P1)
- [ ] #V10 Dev tool: align a known bani to its audio (`truth`, P1)

### M0.2 - v1 replay and truth

- [ ] #V11 Command: score a Sunday from 2 files (`scorer`, P1)
- [ ] #V12 Live mic path: fixed windows decoded off the UI isolate (`pipeline`, P1)
- [ ] #V13 Replay a Sunday through the live follow path (`replay`, P1)
- [ ] #V14 Dev tool: merge 2 alignments into truth (`truth`, P1)
- [ ] #V15 Dev tool: the 100-span human check (`truth`, P2)
- [ ] #V16 Dev tool: the 2nd aligner (`truth`, P1, deferred until Hark chooses the model)

### Checkpoint A - the baseline

- [ ] Harvest the tuning Sundays, build their truth, and replay today's follower.
- [ ] Record the scorecards on the epic. This is the score every later change must beat.
- [ ] Hark reviews before M0.3 starts.

### M0.3 - v1 follower

- [ ] #V17 Program script and item detection (`follower`, P1)
- [ ] #V18 Known-bani follower with the hold gate (`follower`, P1)
- [ ] #V19 Katha hold and lost-track blank (`follower`, P1)
- [ ] #V20 Use the program follower in mic mode (`follower`, P1)
- [ ] #V21 A manual pick keeps autopilot on (`display`, P1)

### Checkpoint B - the release check

- [ ] The tuning scorecards beat checkpoint A.
- [ ] The test Sundays pass the bar, scored once.

### M0.4 - v1 operator

- [ ] #V22 Start the Sunday program with 1 control (`operator`, P2)
- [ ] #V23 A stable overlay address (`operator`, P3)

### Checkpoint C - live

- [ ] 1 live Sunday on the Mac mini passes, scored from its own recording. Then autopilot goes live for Sukhmani Sahib and Japji Sahib.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Today's follower scores far below 97% on the baseline. | High | That is the point of checkpoint A. The follower issues then work against a measured gap, not a guess. |
| The 2 aligners disagree on more than 5% of the time, so Sundays stay unscored. | High | Check coverage on 1 Sunday right after #V14, before harvesting all 25. |
| The 2nd aligner's license blocks later monetization. | Medium | #V16 stays deferred until Hark chooses the model. |
| YouTube audio differs from the live mixer feed. | Medium | Checkpoint C scores 1 live Sunday from the Mac mini's own recording. |
| Parallel M0.1 jobs touch the same files (`asr_service.dart`, `tracking_cubit.dart`, `controls_pane.dart`). | Low | Merge them in issue order. A later job rebases on the earlier one. |
| Decoding on a 1.5 s hop next to OBS is too slow on the Mac mini. | Medium | The `pipeline` budget (1 window within 1.0 s) is measured at checkpoint C. The int8 model is the fallback, if it passes the bar. |

## Open questions

These come from the spec:

- Build here, or contribute to STTM Voice-Follow?
- Which 2nd aligner (#V16)?
- May later training use the `surindersinghssj` v4 datasets?
