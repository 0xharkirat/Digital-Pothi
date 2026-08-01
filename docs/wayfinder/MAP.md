# 🗺️ Digital-Pothi — road from M-α to a coherent 3-epic product

`wayfinder:map` · local-markdown tracker · charted 2026-08-01

## Destination

A charted route for Digital-Pothi across three epics, with the fog in **Epic 1
(live transcription)** and **Epic 3 (accessibility / UX / research)** resolved
into decisions ready to hand to per-feature planning.
**Epic 2 (STTM parity)** is a *referenced* backlog — the census
([docs/spec/2026-07-25-sttm-feature-inventory.md](../spec/2026-07-25-sttm-feature-inventory.md))
and milestones M-α (done) → M-ζ — not re-charted here.

Done when every frontier ticket is closed and no fog remains toward the
destination: the open decisions in Epics 1 and 3 are all made.

## Notes

- Domain: on-device Flutter Gurbani presenter plus AI live-follow of Gurbani
  audio. Local-first is the standing constraint; whether the AI follow may reach
  a server is itself an open decision (see T2).
- Decided up front: WCAG 2.2 AA on both surfaces (operator console and projected
  output).
- Epic 2 (STTM parity) is referenced, not charted. Its plan is the census plus
  milestones; building it is a separate effort.
- Per-session skills: grilling, domain-modeling, design-foundations, prototype,
  research. This is planning — produce decisions, not built features.
- Tracker: local-markdown (no wayfinder tracker doc in this repo). Tickets are
  files under `tickets/`; blocking is a `Blocked by:` body field; the frontier
  is the open, unblocked, unassigned tickets. A ticket resolves by appending
  `## Resolution` and setting `Status: closed`.

## Decisions so far

<!-- one line per closed ticket; the ticket holds the detail -->

- (none yet — this charting session creates the map; tickets resolve one per
  session, research excepted)

## Not yet specified

<!-- in-scope fog; graduates into tickets as the roots resolve -->

- Accuracy / correction bar for the v1 follow — waits on **T1** (scope).
- Training-data pipeline + human-in-loop correction UX — waits on **T1**, **T2**.
- Model delivery: bundle vs on-demand download — waits on **T2**.
- Ceremonies data sourcing for live-following — waits on **T1** (only if
  ceremonies are in the v1 scope).

## Out of scope

- Epic 2 STTM parity feature-building — referenced backlog (census + milestones),
  built as a separate effort, not on this map's route.

---

## Ticket index

| Ticket | Type | Status | Blocked by |
|---|---|---|---|
| [T1 · Epic 1 v1 scope & sequence](tickets/T1-epic1-scope.md) | grilling | open | — |
| [T2 · AI-follow: on-device vs network](tickets/T2-ondevice-vs-network.md) | grilling | open | — |
| [T3 · UX north-star](tickets/T3-ux-north-star.md) | prototype | open | — |
| [T4 · WCAG AA audit + checklist](tickets/T4-wcag-audit.md) | research | in-progress | — |
| [R1 · Better ASR approaches](tickets/R1-asr-approaches.md) | research | in-progress | — |
| [R2 · Sangat-facing features](tickets/R2-sangat-features.md) | research | in-progress | — |
| [R3 · Gurdwara deployment reality](tickets/R3-deployment-reality.md) | research | in-progress | — |
| [R4 · Content correctness / scholarship](tickets/R4-content-scholarship.md) | research | in-progress | — |
