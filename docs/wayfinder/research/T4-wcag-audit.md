# T4 - WCAG 2.2 AA audit: Gurbani Live

Read-only audit of the operator console, the projected display pane, and the LAN overlay against WCAG 2.2 Level AA.
The bar (AA on both surfaces) is a given for this ticket; this document only records gaps and a reusable checklist.
Nothing here is fixed.

## Method and scope

Files read in `lib/`: `theme/app_theme.dart`, `presenter/view/{search_pane,shabad_view,history_pane,favorites_pane,controls_pane,settings_screen,presenter_view,presenter_keyboard,bani_drawer,display_pane,overlay_control}.dart`, `presenter/gurmukhi_text.dart`, `overlay/overlay_server.dart`.
Contrast ratios were computed with the WCAG relative-luminance formula, including alpha compositing over the real background for every `withValues(alpha:)` and CSS `opacity`/`rgba` case.
Generated Material 3 light surfaces (`ColorScheme.fromSeed(kesari, light)`) were bracketed between white and a warm near-white; the kesari-as-text failures hold across that whole range, so they do not depend on the exact generated tone.

## Headline

The design was tuned for dark, and dark mostly passes.
The dark controller text (14.8:1), the dark projected display (cream on navy 15:1, amber 8.9:1), and the default dark overlay all clear AA comfortably.
The failures cluster in three places: the **light theme** (the kesari accent doubles as a text/selection colour and only ever clears contrast on dark), **custom-drawn controls** (radio/checkbox toggles, filter dropdowns, list rows carry no semantic role or state), and a **focus-steal** in the keyboard layer that yanks focus to an invisible node on every line change.

Legend: severity H = blocks a user group / systemic, M = real gap with a workaround, L = marginal or decorative.

---

## Surface 1 - Operator console

### Contrast (1.4.3 text, 1.4.11 UI components)

| Rule | Location | Issue | Sev |
|---|---|---|---|
| 1.4.3 | `theme/app_theme.dart:210` (accent=kesari); rendered at `shabad_view.dart:219` (selected line), `:233` (rahao badge), `:132` (active star); `search_pane.dart:443` (`_MiniToggle` on), `:513` (`_TextFilter` active), `:776` (Ang label); `settings_screen.dart:137` (nav active), `:394` (`_Heading`); `controls_pane.dart:72` (hint); `overlay_control.dart:107` (URL) | Kesari `#E8871E` is used as a **foreground/text** colour in many controls. On light-theme surfaces it measures **2.16-2.65:1** (fails 4.5:1, and fails 3:1 even as large text). Dark theme is fine (6.4-6.8:1). Systemic light-mode failure. | H |
| 1.4.11 | `search_pane.dart:761` (result accent bar), `:860` (legend swatch); tokens `app_theme.dart:42-48` | Per-source bars/swatches (dasam blue `#4C9EEB`, vaaran teal `#3CB8A4`) are graphical UI objects needing 3:1. On light surfaces: blue **2.31-2.84:1**, teal **1.99-2.45:1** (fail). Dark: 6.0 / 7.0 (pass). | M |
| 1.4.3 | `app_theme.dart:221` (`transliteration` = `amberOnLight`) | `amberOnLight #A85D00` normal text on light tile bg is **~4.04:1** (below 4.5:1); on white 4.96:1. Borderline, light theme only. | M |
| 1.4.11 | `shabad_view.dart:253-257` | Hover "set home" icon at `onSurfaceVariant` @0.55 composites to **2.91:1** on the dark pane (below 3:1 for a meaningful icon). | L |
| 1.4.3 | `controls_pane.dart:98` (FollowButton active bg=accent) | When following, the filled button sets `backgroundColor: accent` (kesari) but keeps the theme's `onPrimary` label colour; in light mode that is white on kesari (**~2.3:1**). | M |

Not a failure (noted so it is not re-flagged): disabled `_Soon*` controls and the 0.5-alpha "Soon" labels (`settings_screen.dart:455,482`) are exempt under the 1.4.3 inactive-control exception.
The dark-mode search dim-word style (`search_pane.dart:747`, `ctrlText` @0.5 = 4.12:1) passes because it is applied to large 26px Gurmukhi.

### Keyboard, focus, name/role/value

| Rule | Location | Issue | Sev |
|---|---|---|---|
| 2.4.7 / 2.4.3 | `presenter_keyboard.dart:28` (`skipTraversal` node), `:119` (`_focus.requestFocus()` on every `current`/`shabad` change), `:120-122` | The body-level nav `Focus` re-grabs focus whenever the shown line changes. It is a non-widget node with **no visible focus indicator**, so after any line change (including every autonomous AI-tracker advance) focus is pulled off whatever control a keyboard user was on and nothing shows a ring. Also implicates 3.2.x. Headline keyboard gap. | H |
| 4.1.2 | `search_pane.dart:423-477` (`_MiniToggle`), `:481-547` (`_TextFilter`); `shabad_view.dart:196` (`_LineRow`); result/history/favorite tiles | Custom `InkWell` controls expose **no role and no state**. The language/match radios render `radio_button_checked` as an icon but are not `role=radio` and do not announce selected; the Writer/Raag/Source dropdowns are not a combobox and do not announce expanded/value; selected/current list rows convey state by colour + border only. Zero `Semantics` widgets exist in any console file (grep-confirmed). | H |
| 4.1.2 | `controls_pane.dart:145-148` | Audio-file **play/pause `IconButton` has no `tooltip`** (only icon-only button in the console lacking one), so it has no accessible name. | M |
| 4.1.2 | `search_pane.dart:678-695` | On-screen Gurmukhi keyboard **space and backspace keys** are icon-only `InkWell`s with no tooltip/label. The letter keys carry their glyph as text (acceptable); these two do not. | M |
| 3.3.2 / 4.1.2 | `search_pane.dart:264` (search), `:306` (Ang), `history_pane.dart:180` (announcement) | Text fields use `hintText` only, with no persistent visible `labelText`/`Semantics`. The hint disappears on input and is not a robust programmatic label. | M |
| 1.3.1 / 3.3.2 | `settings_screen.dart:437` (`Switch`), `:536` (`Slider`) | The row label is an adjacent `Text`, not programmatically tied to the control. Screen readers announce label and control as separate nodes; the Slider announces its value but not "Bani/Translation/etc". | L |
| 4.1.2 | `settings_screen.dart:122-145` (nav item), `history_pane.dart:69-91` (Quick Insert disclosure) | Active/expanded state conveyed by colour/arrow only; no selected/expanded semantics. | L |

Keyboard operability itself is otherwise good: arrows / space / page / home / end / esc drive the line, `Ctrl+1..4`, `Ctrl+/`, `Ctrl+C` fire as chords, the search box has a correct guard so plain keys are not stolen while typing (`presenter_keyboard.dart:70-73`), and every `InkWell`/button is Flutter-focusable and Enter/Space-activatable.
All console `IconButton`s except the play/pause one carry tooltips (which Flutter maps to the semantic label), so most icon-only buttons are named.

### Target size (2.5.8, 24x24 min)

| Rule | Location | Issue | Sev |
|---|---|---|---|
| 2.5.8 | `search_pane.dart:524` (`_TextFilter` padding h4/v2) | Writer/Raag/Source filter targets are ~20px tall (12px text + 4px padding), below the 24px minimum. | M |
| 2.5.8 | `search_pane.dart:448` (`_MiniToggle` padding h6/v4) | Language/match radios land at ~24px tall, right at the limit; verify on device. | L |

Passing sizes worth recording: home-hover icon and history delete are boxed to 28x28 (`shabad_view.dart:251`, `history_pane.dart:272`), the order toggle 30x30 (`history_pane.dart:106`), quick chips min-height 30 (`history_pane.dart:302`); all clear 24.

---

## Surface 2 - Projected display pane (`display_pane.dart`)

Dark projection is the design target and passes: cream Gurmukhi 15:1, english `#D9D5CB` 11.4:1, teeka 9.5:1, amber roman 8.9:1, next-line `@0.5` on navy 4.66:1 (large).

| Rule | Location | Issue | Sev |
|---|---|---|---|
| 1.4.3 | `display_pane.dart:120-130` (roman uses `displayAccent`); token `app_theme.dart:239` | In **light** theme the roman row is `amberOnLight #A85D00` at 18px regular (normal text) on parchment = **4.22:1**, below 4.5:1. Scales below 1.0 make it worse. Dark theme fine. | M |
| 1.4.3 | `presenter_view.dart:342-344` (empty-state ੴ) | The placeholder Ik Onkar is `displayText` @0.35: **2.98:1** dark, **2.13:1** light (below 3:1 large). Informational glyph acting as an empty state. | L |

Not failures: heavy-vishraam words use `displayAccent` and medium use `displayText`@0.55, but both are applied inside the 46px Gurmukhi line (large text), so they clear 3:1 in both themes (dark 8.9 / 5.4, light 4.2 / 3.6).
The next-line `@0.5` on parchment is 3.16:1 but large, so it passes with little margin.

---

## Surface 3 - LAN overlay HTML (`overlay/overlay_server.dart`, `overlayPageHtml`)

The default dark palette (cream on navy, amber roman) passes.
The gaps are the light-theme push and missing document semantics.

| Rule | Location | Issue | Sev |
|---|---|---|---|
| 1.4.3 | `overlay_server.dart:182-183` (`bake()`) | Vishraam word colours are **hardcoded to the dark palette** (`#F0B429` heavy, `rgba(251,243,227,.55)` medium) and ignore the pushed `fg`/`ac`. When the app pushes the light theme (parchment bg), heavy words are **1.58:1** and medium words **1.04:1** (effectively invisible). Real bug plus AA failure. | H |
| 3.1.1 | `overlay_server.dart:145` | `<html>` has **no `lang`** attribute, and the Gurmukhi/Punjabi paragraphs have no `lang="pa"`. | M |
| 2.4.2 | `overlay_server.dart:145-146` (`<head>`) | The page has **no `<title>`**. | M |
| 4.1.2 / 1.3.1 | `overlay_server.dart:163` (static `<p>`s), `:196` (`render()`) | Line content is swapped via JS with **no `aria-live`** region, so assistive tech is never notified of the current verse. Lower impact for signage, but the bar is AA. | M |
| 1.4.3 | `overlay_server.dart:161` (`.empty #g{opacity:.35}`) | Same empty-state glyph dimming as the pane; ~2-3:1 depending on bg. Decorative placeholder. | L |

Good practice already present: `<meta viewport>` is set without `user-scalable=no`, so zoom is not blocked; there is no flashing content (2.3.1 fine); content selection is exposed through the `?show=` param, not hidden.

---

## Quick totals

- High: 4 (light-mode kesari-as-text; custom controls missing role/state; focus-steal with no visible focus; overlay light-theme vishraam invisible).
- Medium: 9 (source-colour UI bars/swatches light; amberOnLight roman/translit light; FollowButton active label; play/pause + keyboard space/backspace unlabeled; text-field labels; `_TextFilter` target size; overlay lang/title/aria-live).
- Low: 6 (hover-home icon; empty glyph both surfaces; switch/slider label association; nav/disclosure state; `_MiniToggle` size).

Root cause behind most High/Medium contrast gaps is one decision: `accent = kesari` is reused as a text and selection colour (`app_theme.dart:210`), and kesari was only ever contrast-checked against navy (see the token comment at `app_theme.dart:14-16`), never against light surfaces.

---

## Reusable WCAG 2.2 AA checklist for this app

Use this on every UI change. It is written to the two-surface bar (console + projected/overlay).

### Colour and contrast
- [ ] Normal text >= 4.5:1, large text (>=24px regular or >=18.66px bold) >= 3:1, against the **composited** background (account for alpha and any `Ink`/`ColoredBox` fill beneath).
- [ ] Every colour pair checked in **both** light and dark themes. Never assume a token that passes on dark passes on light.
- [ ] `accent`/kesari is a marker, selection-fill, and border colour only. If it must be text, use a tone that clears 4.5:1 on the actual surface (a dark-amber variant on light, like `amberOnLight`).
- [ ] UI components and meaningful graphics (borders, focus rings, source bars, legend swatches, toggle icons, slider tracks) >= 3:1 against adjacent colours (1.4.11), both themes.
- [ ] Selection/active/current state carries a non-colour signal too (weight, border, icon), and the text still meets its own contrast ratio.
- [ ] Projected/overlay presets (navy, black, graphite, midnight, parchment) each checked against text, roman, and vishraam colours. Overlay colours must follow the pushed `fg`/`ac`, not hardcode one palette.
- [ ] Disabled controls are exempt, but confirm the control is genuinely disabled, not just dimmed live text.

### Keyboard and focus
- [ ] Everything actionable is reachable and operable by keyboard (2.1.1); custom `InkWell`s keep `canRequestFocus` and an `onTap`.
- [ ] No keyboard trap (2.1.2); focus can always move on with Tab/Shift-Tab.
- [ ] A visible focus indicator is present on every focusable control (2.4.7); do not remove default Material focus highlights.
- [ ] Programmatic `requestFocus` never fires on background state changes (line advance, tracker, timer). Move focus only in response to the user's own action, and only to a real, visibly-focusable control.
- [ ] Focus order follows reading/use order (2.4.3); `skipTraversal` nodes never hold visible-less focus while the user is working elsewhere.

### Name, role, value, labels
- [ ] Icon-only buttons have a `tooltip` or `Semantics(label:)` (4.1.2). Grep new code for `IconButton(` and `InkWell(` wrapping an `Icon` with no text.
- [ ] Custom radios/checkboxes/switches wrap in `Semantics(inMutuallyExclusiveGroup/checked/toggled/label:)` or use the Material widget; state (selected/checked/expanded) is exposed, not colour-only.
- [ ] Custom dropdowns expose combobox semantics and the current value, associated with their label.
- [ ] List rows that can be "current/selected" expose `Semantics(selected:)`.
- [ ] Text fields have a persistent programmatic label (`labelText` or `Semantics`), not `hintText` alone (3.3.2).
- [ ] Sliders/switches are programmatically associated with their visible label (wrap the row in `MergeSemantics`, or give the control a `Semantics(label:)`).

### Target size (2.5.8, AA)
- [ ] Interactive targets are >= 24x24 CSS px, or have >= 24px spacing to neighbours. Check compact/dense controls and low-padding inline controls (`_TextFilter`-style rows) explicitly.

### Projected output and overlay
- [ ] Projected text stays legible on every background preset; roman/translit rows meet normal-text contrast at their smallest scale (0.7x).
- [ ] Overlay HTML: `<html lang>` set, Gurmukhi/Punjabi runs marked `lang="pa"`, a `<title>` present (2.4.2, 3.1.1).
- [ ] Overlay live content sits in an `aria-live="polite"` region so the current verse is announced (4.1.2, 1.3.1).
- [ ] Overlay never hardcodes theme colours that the app can override; all colour comes from the pushed payload.
- [ ] Zoom not blocked (`user-scalable=no` absent); no flashing (2.3.1).

### Process
- [ ] Run Flutter's accessibility guidelines tests (`meetsGuideline(textContrastGuideline / androidTapTargetGuideline / labeledTapTargetGuideline)`) in widget tests for new panes.
- [ ] Sanity-check the overlay page in a browser accessibility inspector after any HTML change.
