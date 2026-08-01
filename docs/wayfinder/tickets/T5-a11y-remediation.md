# T5 · A11y remediation plan (from the T4 audit)

Labels: wayfinder:grilling
Status: open
Blocked by: T4 (closed)
Assignee: —

## Question

The T4 audit found the concrete WCAG 2.2 AA gaps. Decide how and when to close
them: what lands now, what waits, and what the standing rule is so new UI does
not reopen the same holes.

Graduated from fog by [T4](T4-wcag-audit.md). Findings:
[../research/T4-wcag-audit.md](../research/T4-wcag-audit.md).

Decide at least:
- The overlay light-theme palette bug (vishraam at 1.04-1.58:1 on parchment,
  `overlay_server.dart:182-183`) — a real defect from the light-theme work, not
  just a ratio miss. Fix now, or fold into the batch?
- Light-theme contrast: kesari doubles as text colour at 2.16-2.65:1
  (`app_theme.dart:210`). Retune the token, or add a separate on-light accent?
- Semantics: no `Semantics` widgets exist on the custom radios/dropdowns/rows.
  How far do we go, and is it a per-widget rule from now on?
- Focus-steal on every tracker advance (`presenter_keyboard.dart:119`).
- Whether AA becomes a CI gate or a review checklist.
