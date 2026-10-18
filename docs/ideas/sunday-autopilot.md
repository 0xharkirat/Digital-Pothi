# Sunday autopilot: the refined idea

This is the `idea-refine` summary page for the intent in [docs/intent/sunday-autopilot.md](../intent/sunday-autopilot.md).
It dates from 2026-10-19, after a search of the existing Gurbani datasets and a sample of the gurdwara's own streams.

## Problem statement

How might we run the Sunday program with no sevadar at the laptop and no wrong line, and learn from recordings without hand labels?

## What the search changed

3 facts from 2026-10-19 change the frame:

- **SikhiToTheMax (STTM) already ships an AI follow.**
  Khalis Foundation's "Gurbani Autopilot" (Voice-Follow) is in STTM Desktop 9.0.4.
  On its own benchmark, GAB v1.3, it finds the right kirtan shabad 92.6% of the time.
  It also shows a wrong shabad for 111 seconds per hour of kirtan, and it finds the right recited bani 95.7% of the time.
  So the R3 finding "nobody automates the follow" is out of date.
  The open gap is the strict bar: at most 1 wrong line visible for more than 3 seconds in a whole program.
- **The text is the only label source to trust.**
  Of 4 sampled Sunday streams, only the one from 2026-10-18 shows an overlay.
  Hark reports that the sevadar's lines are often wrong, so neither the overlay nor the STTM live feed is a label.
  GAB reaches 97% right pangti with forced alignment that 2 models must agree on, checked by a person on 20 of 20 random samples.
- **Ready-made data exists, with open license questions.**
  `surindersinghssj` publishes v4 sets on Hugging Face: about 1000 hours of kirtan, a bani set, and an SGPC set, with timed text.
  Most of them carry no license tag.
  Khalis publishes 6 `sttm_desktop_*` recordings (about 1 hour, Fremont) under CC-BY-4.0, with verse timestamps.
  GAB itself is private to Khalis Foundation members.

## Directions considered

This page compares 3 directions:

| Direction | What it is | Verdict |
|---|---|---|
| A. Text-anchored follower with a strict hold | Labels come from forced alignment against the known text. The live follower knows the program, tracks the position inside a known bani, and changes the line only when 2 signals agree. | Recommended. It attacks the wrong-line gap that STTM leaves open. |
| B. Contribute to STTM Voice-Follow | Join Khalis, get GAB, and bring the strict hold rule and the Sunday harvester to STTM. | A real option and a decision for Hark. It reaches every gurdwara that already runs STTM, but this app does not ship the result. |
| C. Data first, model later | Build only the harvester and the benchmark, and publish them. | Too slow alone: it proves nothing to the sangat. Its parts are the first slices of A. |

## Recommended direction

Direction A, built in slices from the measurement up.

1st, a replay harness scores the current app on recorded Sundays.
The truth comes from forced alignment of the known banis, audited by 2 models and a short human spot check.
2nd, the live follower gets a program script and a known-bani mode.
Inside Sukhmani Sahib or Japji Sahib, the question is "where in this text are we", not "what was said".

3rd, a hold gate: the screen changes the line only when the aligner position and the transcript match agree.
During katha, it holds the last line.
4th, the app reads the MG10XU's USB feed on the Mac mini M4, next to OBS.
Kirtan follows silently, gets a score, and goes live only when it passes the same replay test.

The parts the sangat never sees matter most here: the harness, the truth, and the hold gate.
They are also what direction B would need, so this work is not lost if Hark later chooses B.

## Stress test

The direction meets the 6 conditions from the brief like this:

| Condition | How direction A meets it | Risk left |
|---|---|---|
| Offline use | The follower, the model, and the corpus run on the Mac mini. Only the training machines use the network. | None for the app. |
| Slow hardware | The known-bani mode searches 1 bani, not 141k lines, so it costs less than today's discover mode. The int8 model is about 4 times smaller. | The int8 model must pass the replay test. Intel and low-memory machines come after Apple M1 to M5. |
| Volunteers with no training | 1 person starts the app, picks "Sunday program", and presses 1 control. | Correcting a wrong line must be 1 action. |
| A wrong line on the screen | The hold gate and the 2-number bar make wrong-line seconds the main measure. | The gate can hold too much and drop the right-minutes below 97%. Only the replay test shows the balance. |
| Several screens | 1 main screen in the hall (the Lenovo opens the overlay URL) and the OBS browser source, both fed by the existing LAN overlay. | None new. Per-screen content already works through `?show=`. |
| Many gurdwaras | Out of scope for v1. The harvester works on any gurdwara's public Sunday stream, so the model can hear their raagis first. | GAB says about half of gurdwaras use a room mic, and STTM scores 52.8% there. v1 covers the mixer feed only. |

## Key assumptions to validate

- [ ] **Forced alignment of a known bani is accurate on this hall's audio.**
  Test: align Sukhmani Sahib from 1 Sunday stream, and check 20 random lines by ear. Pass at 19 of 20 within 1 second.
- [ ] **The YouTube audio matches the live mixer feed.**
  Test: record 10 live minutes of the mixer feed, and compare the model output with the stream's same 10 minutes.
- [ ] **The Sunday order is stable enough for a program script.**
  Test: mark the part boundaries of 5 Sundays, and compare the orders.
- [ ] **The known-bani follower runs in real time next to OBS on the Mac mini M4.**
  Test: measure the real-time factor while OBS streams.
- [ ] **The hold gate keeps wrong-line seconds near 0 without dropping the right-minutes below 97%.**
  Test: the Sunday replay test, run with the gate on and off.
- [ ] **The v4 datasets may be used for training.**
  Test: ask `surindersinghssj` for the license of each v4 set before any training run uses it.

## MVP scope

The MVP tests the core assumption: that a text-anchored follower with a hold gate meets the bar on Sukhmani Sahib and Japji Sahib.

In scope:

- Download of the Sunday streams' audio, as 16 kHz mono files.
- Forced-alignment truth for Sukhmani Sahib and Japji Sahib, audited by 2 models, with a 20-line spot check per Sunday.
- A replay command that scores the app on the 2 numbers of the bar.
- The known-bani follower mode, the hold gate, and katha hold.
- An input-device choice for the mixer's USB feed.

Out of the MVP:

- Kirtan on autopilot. Kirtan runs in shadow mode and gets a score.
- Training a new model. The MVP measures the current model first, so a finetune has a baseline to beat.

## Not doing (and why)

- **Overlay OCR as labels:** most streams have no overlay, and its lines are often wrong.
- **The STTM live feed as labels:** it is the same sevadar's lines, so it has the same errors.
- **A confirm-each-line UI:** it keeps the sevadar tied to the laptop, which defeats the goal.
- **A new model backbone or a re-finetune in the MVP:** without the replay baseline, nobody can tell whether it helped.
- **Saturday's program, Intel machines, and other gurdwaras:** each comes after the Sunday bar passes.
- **Any cloud service:** no money goes out until the replay test shows success.

## Open questions

- **Build here or contribute to STTM (direction B)?**
  Khalis already ships a follow and holds the benchmark. This is Hark's decision, and it does not block the first slices.
- **May this project use GAB?**
  It is private to Khalis members. Hark can ask for access, but it cannot be the project's only benchmark.
- **How does the app detect the start of katha?**
  The hold rule needs a signal that speech is not Gurbani. Today's tracker has none.
