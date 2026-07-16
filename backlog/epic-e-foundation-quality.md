# Epic E - Foundation and Quality

**Goal:** the app is easy to ship, safe to change, and correct.

**Done already:** VGV bloc conventions (single state class, Page / View split), persisted settings / history / favorites via shared_preferences, a growing test suite (77 tests: cubit behaviour, gurmukhi span logic, overlay page + payload, keyboard nav, persistence).

Open sub-issues below.

## E1 - CI (analyze, format, test, coverage) 🔴 P1

**Area:** ci

Every push should run static analysis, format check, and the full test suite, and report coverage.

**Acceptance:**
- [ ] CI runs `flutter analyze`, format check, and `flutter test` on push and PR.
- [ ] Coverage collected and reported.
- [ ] Green required before merge.

## E2 - Auto-update 🔴 P2

**Area:** distribution

Ship updates to installed apps without a manual reinstall.

**Acceptance:**
- [ ] An update mechanism for the desktop builds.
- [ ] A visible, non-blocking update prompt.

## E3 - Packaging and signing 🔴 P2

**Area:** distribution

Distributable builds for the target platforms.

**Acceptance:**
- [ ] macOS: notarized, hardened-runtime build.
- [ ] Windows build.
- [ ] Linux build (the dev's omarchy box is a target).

## E4 - Widget and integration test coverage for new UI 🔴 P2

**Area:** testing

The recent panes (favorites, bani drawer, settings drawer, quick insert) have cubit-level coverage but little widget-level coverage.

**Acceptance:**
- [ ] Widget tests for the bani drawer (grouped list, name toggle, length badge), favorites (star / list / remove), and quick insert (announcement dialog).
- [ ] An integration test that drives search then keyboard nav end to end.

## E5 - Accessibility pass 🔴 P3

**Area:** accessibility

**Acceptance:**
- [ ] Semantics labels on the operator controls.
- [ ] Contrast checked for operator surfaces and the projected display.
- [ ] Keyboard reachability of all primary actions.

## E6 - Error handling and reporting 🔴 P3

**Area:** reliability

**Acceptance:**
- [ ] User-visible, recoverable errors for corpus load, overlay bind, audio init, model load.
- [ ] Opt-in crash / error reporting.
