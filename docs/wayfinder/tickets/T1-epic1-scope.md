# T1 · Epic 1 v1 scope & sequence

Labels: wayfinder:grilling
Status: closed
Blocked by: —
Assignee: —

## Question

What is in the v1 live-transcription follow, and in what order do we build it —
paath, kirtan, and/or ceremonies?

Grounding (measured): paath tracks well (~16% WER regime), kirtan is far harder
(~55%), ceremonies are unmeasured and need their own audio+text. This is the
root ticket: the accuracy bar, the training loop, and the ceremonies-data
question all wait on it. Resolve via /grilling + /domain-modeling. Decide the
v1 target, the explicit non-goals, and the sequence.

## Resolution

Resolved 2026-10-19 by Hark's interview. Detail: [../../intent/sunday-autopilot.md](../../intent/sunday-autopilot.md) and [../../spec/2026-10-19-v1-sunday-autopilot.md](../../spec/2026-10-19-v1-sunday-autopilot.md).

v1 is the gurdwara's Sunday program on autopilot, 1 part at a time: Sukhmani Sahib and Japji Sahib first, kirtan in shadow mode until it passes the same bar. The bar is at least 97% right share and at most 1 wrong episode longer than 3 s per Sunday, on a held-out set of recorded Sundays. Ceremonies and the Saturday program are out of v1.
