# Sunday autopilot: the v1 intent

Hark confirmed this intent on 2026-10-19, at the end of an interview-me session.
It records what v1 of the AI follow is for, so the spec and the issues build the right thing.
The spec in `docs/spec/` and the GitHub issues take their scope from this file.

## Why v1 exists

SikhiToTheMax (STTM) and similar apps are already in wide use, so presenter parity wins nobody.
The moat is accurate live AI that removes the sevadar who sits at the laptop every program, listens, and moves the line by hand.
UI polish and STTM parity are catch-up work that the project can build at any time.
The blocker is training data: there are many hours of recordings, and nobody wants to match lines to audio by hand.

## The intent

The confirmed intent has 8 parts:

| Part | Intent |
|---|---|
| Outcome | The gurdwara's Sunday program shows the right Gurbani line with no sevadar at the laptop. The sevadar stays nearby and fixes a wrong line on the rare occasions it happens. |
| Users | The sangat reads the screen. The sevadar is freed from pressing keys all program. The raagi and the paathi change nothing. |
| Why now | STTM-level presenting already works. Removing the operator is the moat, and training data is the blocker. |
| Success | Every recorded Sunday program, replayed through the app, shows the right line for at least 97% of the recitation minutes, with at most 1 wrong line visible for more than about 3 seconds. During katha, the screen holds or blanks. |
| Growth | 1 part of the program at a time. Sukhmani Sahib and Japji Sahib go on autopilot first. Kirtan follows silently, gets a score, and goes on autopilot only when it passes the same test. Each step is a small slice. |
| Data | The gurdwara's own recordings, labelled with no human matching. Fixed banis get labels from their known text, aligned to the audio. Kirtan gets labels from overlay OCR when the stream shows the overlay. Later recordings get labels from the sevadar's key presses in this app. |
| Constraints | The app runs on the Mac mini M4 from the mixer's USB feed, next to OBS, fully offline. The M5 does the labelling, replay, and scoring. The Nitro 5 does all-day training over Tailscale and holds the data on SMB. No money is spent until the replay test shows success. |
| Out of scope | Other gurdwaras and their committees, Intel and low-memory machines, Saturday's Rehras Sahib and Sukhasan, STTM parity and UI polish, monetization, and any cloud service. |

## The rule behind the success bar

A wrong line on the screen is worse than no line.
So when the AI is unsure, it holds the current line or blanks the screen.
It never guesses.
This is why the success bar has 2 numbers and not 1.
An AI that is right 97% of the time but flashes 20 wrong lines in a program fails.
An AI that is right 90% of the time and shows 0 wrong lines is closer to the goal.

## The room

The gurdwara already has the audio path that v1 needs:

```text
raagi mics, harmonium, tabla
        |
Yamaha MG10XU mixer
        | USB audio
Mac mini M4 ── OBS (livestream)
        |       ^
        |       | browser source: the line from the LAN overlay
        └── Digital Pothi (AI follow)
                |
                | LAN overlay URL
                v
        Lenovo workstation ── projector (full-screen browser)
```

The mixer feed is the same mix that goes to the livestream.
It carries little hall echo and no PA bleed, so it is close to the SGPC broadcast audio that the model learned from.

## The Sunday program

The Sunday morning program has 4 parts, and they make 3 different problems for the AI:

| Part | What the AI must do | Where its labels come from |
|---|---|---|
| Sukhmani Sahib, Japji Sahib | Follow a known text in a known order. | The bani text, aligned to the audio. |
| Kirtan | Find the shabad, then follow it through repeats. | Overlay OCR when the stream shows the overlay; otherwise only high-confidence matches. |
| Katha | Hold or blank. Katha is not recitation. | None. |

## What this changes

This intent replaces or narrows 5 earlier decisions:

- R3 said "human-confirm, never autopilot" for v1.
  v1 is autopilot with a fast override instead, because confirm-each-line keeps the sevadar tied to the laptop.
  R3's rule "never show the wrong line to the sangat" stays, as the hold-or-blank rule.
- T1 (v1 scope) resolves to the Sunday program, with fixed banis first and kirtan scored in the background.
- T2 (on-device or network) resolves to on-device for the app.
  Tailscale and SMB connect only the training machines, never the gurdwara.
- B1 (audio-source picker) narrows to choosing an input device such as the mixer's USB input.
  v1 does not need system loopback capture.
- The backlog's Milestone 2 (the AI moat) moves ahead of the parity milestones.

## Facts that bound v1

- The speech model is 482 MB in fp32.
  Its model page also publishes an int8 export, about 4 times smaller.
- R1 measured about 16% WER on paath and about 55% WER on kirtan with the current finetune.
- The M5 has 32 GB of memory and an Apple M5 chip, and its disk had 51 GB free on 2026-10-19.
  Recordings and checkpoints live on the Nitro 5's disk.
- The Nitro 5 has a GTX 1650 with 4 to 6 GB of GPU memory.
