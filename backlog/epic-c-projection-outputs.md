# Epic C - Projection and Outputs

**Goal:** get the shown line onto every surface a gurdwara uses - projector, extended display, OBS, remote viewers - reliably and locally.

**Done already:** the LAN overlay (dart:io HTTP + WebSocket serving a state-delta page, like STTM's projector), per-overlay content control via the `?show=` URL param, and a native fullscreen output window (a system webview pointed at the overlay URL, no second Flutter engine).

Open sub-issues below.

## C1 - Auto-place the output window on the extended display 🔴 P1

**Area:** overlay/output

STTM detects a non-primary display and opens the projector there full-screen automatically.
Our output window opens on the primary display and must be dragged over.

**Acceptance:**
- [ ] Detect a non-primary display (`screen_retriever` or equivalent).
- [ ] Open the output window on it and size it to that display.
- [ ] Fall back cleanly to the primary display when there is only one.
- [ ] Validate on a real dual-monitor setup.

## C2 - True fullscreen / borderless output on macOS 🔴 P2

**Area:** overlay/output

`desktop_webview_window` has no maximise / move on its macOS build, so the window opens at a fixed size and is fullscreened by hand.

**Acceptance:**
- [ ] The output window can go borderless full-screen programmatically on macOS.
- [ ] If the plugin cannot, evaluate an alternative (native channel, or a different webview).

## C3 - Live-feed text files 🔴 P3

**Area:** overlay/output

STTM writes the current line to text files for lower-thirds / captioning tools.

**Acceptance:**
- [ ] Write the current gurmukhi / translation / transliteration to files on each line change.
- [ ] A setting for the output directory.

## C4 - Chromecast ⏭️ deferred

**Area:** overlay/output

STTM casts to Chromecast.
Deferred: niche for our users, and it pulls in a heavy dependency.

## C5 - Zoom closed-captions ⏭️ deferred

**Area:** overlay/output

STTM pushes captions to Zoom.
Deferred behind real demand.
