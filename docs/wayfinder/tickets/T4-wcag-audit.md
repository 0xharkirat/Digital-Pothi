# T4 · WCAG AA audit + checklist

Labels: wayfinder:research
Status: closed
Blocked by: —
Assignee: (resolved by research agent)

## Question

The bar is decided (WCAG 2.2 AA on both surfaces). Turn it into a concrete
audit of the current app (operator console + projected output + LAN overlay)
and a checklist to hold future work to.

Output: findings in research/T4-wcag-audit.md — per-surface AA gaps against
WCAG 2.2 (contrast, focus visible, keyboard operability, name/role/value,
target size), ranked, with a reusable checklist.

## Resolution

Resolved 2026-08-01. Findings: [../research/T4-wcag-audit.md](../research/T4-wcag-audit.md)

Dark controller/display/overlay pass AA comfortably and keyboard operability is solid. Gaps: light-theme contrast (kesari doubles as text at 2.16-2.65:1), missing Semantics/name-role-value on custom controls, focus-steal on every tracker advance (presenter_keyboard.dart:119), and a real bug - overlay hardcodes the dark palette so light-theme vishraam is 1.04-1.58:1. Remediation is contrast + semantics, not a rebuild.
