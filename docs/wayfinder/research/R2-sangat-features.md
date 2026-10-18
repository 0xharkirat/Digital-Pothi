# R2 · Sangat-facing features

`wayfinder:research` · resolves [tickets/R2-sangat-features.md](../tickets/R2-sangat-features.md) · researched 2026-08-01

## Summary

The projected screen serves the room; it does not serve the individual reader or the remote viewer.
The Sikh app ecosystem has already solved the static half of the sangat problem: mature personal readers with search, larivaar, vishraam, and multiple translations, plus one shipped second-screen sync (Khalis "Sangat Sync") that mirrors an operator's manually-driven display to phones in the room and lets each phone pick its own translation and transliteration.
What nobody ships is a pointer to the current verse derived from the audio itself rather than from a human operator.
That single difference is what a live-follow presenter uniquely holds, and it is the axis every sangat-facing feature below turns on.
The cross-domain precedent is blunt about the payoff: YouVersion built true real-time verse-push in 2009, then retreated to a self-paced guide because keeping every phone on the spoken position by hand was too heavy; our follow engine removes exactly that cost, so we can offer the automatic version YouVersion had to abandon.
Our app already carries most of the transport: a LAN HTTP+WebSocket server (`lib/overlay/overlay_server.dart`) that pushes the current line as a small JSON delta to every connected browser, and the AI-follow pointer already feeds it.

Reading guide, in the order the argument builds:

1. The candidate feature space.
2. What existing apps already cover, so we build the gaps.
3. The gaps.
4. Five features uniquely enabled by live-follow, each with rough value vs effort, grounded in cross-domain precedent and the current codebase.
5. Dependencies on the open T1/T2 decisions.

---

## 1. Candidate feature space

Grouped by who the audience is and what they are doing.

### In-room sangat (present in the Gurdwara)

- Companion follow-along: your phone shows the verse currently on the projector, so you read up close instead of squinting at a far screen.
- Personal second-screen reading: your own translation, transliteration, larivaar, and font size while the projected screen stays clean for everyone.
- Accessibility for elderly and low-vision sangat: the same live verse at a size and contrast the projector cannot offer, optionally spoken.
- Sing-along line-follow: the current tuk highlighted as the ragi sings, for people who cannot yet read fluent Gurmukhi at kirtan speed.

### Remote and livestream viewers (not in the room)

- Follow the live kirtan from home on your own device, in your own language, instead of a fixed burned-in subtitle.
- Auto-translation and transliteration per viewer, driven by one shared live pointer.
- A "live" link or QR that travels with the livestream so a YouTube or Facebook viewer can join the follow.

### Study and personal practice (any time)

- Larivaar with assist (bold alternate words) as a santhia and reading aid.
- Vishraam pause marks from a chosen scholarly source, as a meaning and pronunciation aid.
- Word-by-word arth and teeka on tap, for study rather than performance.
- Karaoke-style line-follow of any recording without pre-baked timings.

### Sharing

- Deep-link to a shabad, or to a specific verse, that opens the same reader.
- Share the exact line being sung right now.
- Render a verse as an image card for social media.

---

## 2. What existing apps already cover for the sangat

The ecosystem is mature on the personal-reader side and thin on live, audio-driven sync.
Three framing facts matter before the table:

- The "SikhiToTheMax" name spans two different organizations, and Shabad OS is a third, independent project.
  Khalis Foundation runs STTM web and desktop (the presenter, Sangat Sync, Bani Controller); SHARE Charity UK runs the separate STTM mobile app (`com.nest.sttm`); Shabad OS (`github.com/shabados`, MIT) is an unrelated open-source presenter, database, and font stack.
  App Store reviews of "SikhiToTheMax" are feedback on the SHARE mobile product, not the Khalis presenter.
- The content layer is a solved, open resource.
  iGurbani, STTM, and others share the **BaniDB Alliance** API; GurbaniNow runs a separate open API.
  BaniDB serves per-line data that already includes a first-class larivaar field, three vishraam sources (`sttm`, `sttm2`, `igurbani`), multi-source translations (`en`, `pu`, `es`, `hi`), and transliterations, keyed by a globally unique `verseId`.
  Neither API does any live, sync, or broadcast work; all of that lives in the app layer.
- Every audio-sync feature that ships today is bound to pre-recorded audio with baked-in timings.
  Nothing follows live or arbitrary recitation.

### Personal readers

| App (owner) | Good at, for the sangat / personal reader | Key gaps |
|---|---|---|
| **STTM web** (Khalis) | Multi-mode search including search-by-ang; larivaar; vishraam with three selectable sources; split view separating Gurbani from translations; Unicode rendering with no font install; font size; dark theme; share with a verse-level deep-link. | Web reader is intentionally light; heavy display config lives in the desktop app. PWA/offline not confirmed. |
| **STTM mobile** (SHARE Charity, 4.9/5, ~356 ratings) | Fast auto-search, search-by-ang, a large built-in dictionary, continuous scroll, larivaar, sehaj-paath tracking, bookmarks, notes, themes, Chromecast. | Reviewers report you cannot reliably load a single pankti inside a bani; an iOS update once broke the vishraam and larivaar toggles. Its "Bani Sync" is personal bookmark sync, not congregation sync. |
| **iGurbani** (Akal Design, 4.7/5, 468 ratings) | The named home of **Baba Darshan Singh Ji (Mallehwal) vishraam**, offered ecosystem-wide as a source. Strong search, larivaar, transliteration, four translation/teeka stacks (Sant Singh Khalsa, Manmohan Singh, SGGS Darpan / Prof. Sahib Singh, Faridkot Teeka), dark mode, keep-awake. | No built-in audio playback; a text tool. Sharing limited to favorites import/export. Offline not documented. |
| **GurbaniNow** (open API) | Fast modern search; clean shabad permalinks; larivaar/Unicode toggle, English+Punjabi translation, Hindi+English transliteration, day/night, font size, WhatsApp/FB/Twitter/email share. Easiest API to prototype against. | Shares the link, not an image card. No audio, no vishraam colouring evident. |
| **SriGranth** (web) | The scholar's tool: hover any word for meanings from three dictionaries plus Mahan Kosh; two English translations and two full Punjabi teekas (Sahib Singh Darpan, Faridkot) side by side; full 1,430-ang navigation. | Dated early-2000s desktop UI, not responsive, no mobile app. |
| **Sundar Gutka** (Khalis) | The standard nitnem companion: full bani set with adjustable lengths, larivaar, romanization, English translation, autoscroll, reminders, stay-awake, offline, font and background controls. | Autoscroll only, no line highlight synced to audio. Single-purpose. |

### Audio-sync precedents (the closest UX to our live-follow)

- **Sikh World – Nitnem & Gurbani** (4.8/5, 374 ratings): the clearest karaoke precedent, real-time text highlighting synced to Nitnem audio in Gurmukhi/Hindi/English.
  Bound to fixed pre-recorded audio with baked timings; not live, not arbitrary recordings.
- **SikhNet Play** (4.9/5, ~1.9K ratings): shows the shabad text of the currently playing track with translation and transliteration.
  Track-level only, not line-level; reviews report the text failing to advance to the next shabad.

### Second-screen, sync, and livestream (the direct prior art)

- **Sangat Sync** (Khalis, `sttm.co/sync`): the desktop shows a code on the projector; a sangat member enters it and then chooses what they see, "translations, transliterations, larivaar and more," on their own phone while following the room, tracking the operator's current shabad and current line.
  This is real per-viewer second-screen reading, shipped.
  Two limits define it: it needs the desktop app running and driven by an operator, and the join code is visible only on the in-room screen, so a remote viewer cannot join.
- **Shabad OS presenter** (independent, OSS): a server model lets multiple devices join one LAN as displays or controllers, with live captions kept in sync.
  It mirrors the same content to every device, with no per-viewer preference layer, so it is an AV-setup feature, not a personal-reader one.
- **Bani Overlay** (Khalis) and **Shabad OS broadcast captions**: burn the current line into a livestream by syncing to the operator's laptop.
  The remote viewer gets the operator's font, translation, and language, fixed, with no way to change it or tap through.
- **Zoom Overlay** (Khalis): injects Gurbani into Zoom closed-captions, but it is operator-side (you must host the Zoom call and paste an API key); remote sangat read it passively.
- **Bani Controller** (Khalis): lets the operator drive the desktop from a phone, an operator tool rather than a sangat feature.

### Sharing and study aids

- Deep links already work at both shabad and verse granularity.
  STTM encodes the line: `sikhitothemax.org/shabad?id=5532&highlight=60319`, where `highlight` is the verse's unique id; short forms are `sttm.co/s/<shabadId>` and `sttm.co/a/<ang>`.
  GurbaniNow has `/shabad/<id>` permalinks.
  So verse-level linking is not a gap.
- STTM mobile sharing is clipboard-only ("copy a line or copy the shabad"); GurbaniNow shares the link.
  Polished per-line image cards are a relative gap, done well only by side tools (SikhNet Shabad Printer, iGranth Gurbani Share).
- Larivaar-with-assist is a named study aid (Khalis "Learn Larivaar", an assisted/unassisted toggle), and vishraam renders as coloured words or a gradient background (red long pause, yellow short), source-selectable.
  Vishraam is treated as a sourced interpretation, not ground truth.

---

## 3. The gaps

1. **The pointer is always operator-driven or pre-baked.**
   Sangat Sync mirrors a human operator, Shabad OS mirrors a driven display, and karaoke highlight needs pre-aligned audio.
   Nothing follows live recitation from the audio itself.
2. **Remote and livestream viewers are second-class.**
   They get a burned-in subtitle or a Zoom caption in the operator's language and font, or nothing.
   They cannot read in their own script, resize, or tap through to the full shabad and arth.
3. **No venue-independent option.**
   Every sync path assumes the Gurdwara runs a specific presenter and someone drives it.
   A Gurdwara projecting with anything else, or nothing, has no companion story.
4. **No first-class accessibility mode.**
   "Unable to read along to Bani" is a documented barrier for low-vision and disabled sangat (Baaz News accessibility report).
   Font size, dark mode, and Unicode rendering exist, but screen-reader support and a one-tap senior/high-contrast mode are unconfirmed in any of these apps.
5. **Sharing has no live dimension.**
   You can link a shabad or a verse, but not "the line being sung right now," and per-line image cards live in separate side tools.
6. **Second-screen is either personalized or synced, never both without an operator.**
   Sangat Sync personalizes but needs an operator; Shabad OS syncs many devices but mirror-only.
   Neither derives the line from audio.

---

## 4. Features uniquely enabled by live-follow

The unifying idea: because the current verse is derived from audio, it can be broadcast to any device with no operator and no venue lock-in, including devices not in the room.
Each feature is scored value (to the sangat) vs effort (for us), grounded in cross-domain precedent and in what the codebase already has.

Our starting position is strong.
`OverlayServer` already binds to all interfaces on the LAN, serves an HTML page over `/ws`, pushes the current line as a JSON delta (`{g, en, pa, roman, larivaar, vishraam, scales...}`), replays the last line on connect, and auto-reconnects; the page already honours a `?show=gurmukhi,punjabi,english,roman` content filter.
The AI-follow path (`_showLineOf(verse.id, following: true)`) already feeds that server.
So "the live verse over a socket, with a selectable content subset" is done; the sangat features are new views over an existing transport, not new plumbing.

The cross-domain menu tells us how followers should join and what they expect.
The dominant modern join is a QR code to a web page, no app install, then pick your language and personalize the captions on-device (Wordly and Interprefy do exactly this for live translation, and sell it as accessibility "without cluttering the main presentation display").
The network-free way to keep hundreds of phones on the current position is ambient-audio sync, where the phone locates itself from the room's own sound with no pairing (CUE Audio for stadium light shows, and the TV second-screen industry's audio watermarking and fingerprinting).
That last pattern fits us better than anyone, because our app already identifies the live verse from audio.
And YouVersion's own history says to auto-follow by default but always leave a "scroll freely" escape hatch, since people read ahead and behind.

### 4.1 Operator-free in-room companion (QR to follow along)

The projector shows a QR or short URL; sangat open it and read the live current verse on their own phone, choosing their own translation, transliteration, larivaar, and font size, while the projection stays clean.
Delta over Sangat Sync and Shabad OS: no sevadaar has to drive a presenter, and it works in a Gurdwara that runs neither, because the AI derives the line from the audio.
Follow the kirtan automatically by default, with a free-scroll mode for reading ahead, per the YouVersion lesson.
**Value: high.** It folds second-screen reading and the clean-projection tension into one, and it is the entry point for everything else.
**Effort: low-medium.** Reuse `OverlayServer` and the show-line delta; add a mobile-styled page with in-page toggles (the current page reads `?show=` from the URL, not from user taps) and a QR to the LAN address.
LAN-only, so it respects the local-first constraint with no server.
One scale caveat worth a spike: a single Gurdwara wifi AP will not hold hundreds of phones, so the honest ceiling of the LAN version is the sevadaars and front rows; the network-free path to whole-room scale is on-phone follow from ambient audio, which is a larger effort and ties into T2.

### 4.2 Remote / livestream follow on the viewer's own device

Run the follow engine on the broadcast or room audio and publish the current verse to a link or QR that travels with the livestream (the Resi "QRclick" pattern of injecting a follow pointer into the stream).
Home viewers read in their own script, size, and translation, and tap through to the full shabad and word-by-word arth, instead of the fixed burned-in Bani Overlay subtitle or passive Zoom caption.
Delta: this reaches the diaspora sangat, the largest audience by far, and needs no in-room join code.
**Value: high.** It is the feature no existing product offers and the one that most extends the mission beyond the room.
**Effort: high, and gated on T2.** Reaching devices outside the LAN needs a public relay, which is the network exception the local-first policy has not yet decided (see [T2](../tickets/T2-ondevice-vs-network.md)).
The follow engine and the per-viewer render are cheap; the relay is the cost and the policy question.

### 4.3 Personal accessibility mode driven by the live line

The far projector is unreadable for many elderly sangat.
Their phone shows the same live verse at very large size, high contrast, and optionally read aloud, plus an enlarged transliteration for those who lost fluent Gurmukhi reading.
Because the line is pushed live, they never fall behind the recitation.
This is the exact split Wordly and the opera-titles device AirScript already validate: personal language, size, and contrast on your own device while the shared screen stays canonical, explicitly framed for low-vision and Deaf or hard-of-hearing patrons.
**Value: high.** It answers a documented, unmet accessibility need and directly serves the WCAG 2.2 AA bar the project already committed to (see [T4](../tickets/T4-wcag-audit.md)).
**Effort: low.** It is a display preset of 4.1's companion page, not a new system.

### 4.4 Per-viewer live translation and transliteration

The pointer is a verse id, not pixels, so each follower's device renders that verse from the local corpus in the viewer's chosen translation (English, Punjabi, Hindi) and transliteration (roman, Devanagari), all driven by one shared live pointer.
Diaspora youth read English or roman, a Hindi speaker reads Devanagari, and a fluent reader reads larivaar Gurmukhi, at the same moment in the same kirtan.
This mirrors the live-translation model where each attendee picks a language and the source stays single (Wordly, Interprefy, opera surtitles), applied to a corpus we already ship.
**Value: medium-high.** It is the strongest answer to a sangat that does not all read one script.
**Effort: low in-room** (the delta already carries en/pa/roman, and the corpus holds more), **higher remote** (rides on 4.2's relay).

### 4.5 Live verse link, plus karaoke follow of any recording

Two sharing wins the live pointer unlocks that static verse-links cannot.
Tap to share a link that keeps following the kirtan, so a friend opens the current verse live or joins the follow, rather than a frozen link to one verse (verse-level links already exist ecosystem-wide, so the new thing is the live one).
Separately, point the app at any recording, a home nitnem or a kirtan track, and get line-highlight follow with no pre-baked timings, which every existing karaoke app requires.
**Value: medium.** The live link is a small step over existing shabad and verse links; the arbitrary-recording follow is a genuinely new personal-practice tool.
**Effort: medium.** Static verse deep-links are cheap because the corpus already has stable ids matching the ecosystem's `verseId`; the live link needs 4.2's relay; the recording-follow reuses the follow engine on recorded audio.

---

## 5. Dependencies and constraints

- **T2 (on-device vs network) is the fork.**
  The in-room features (4.1 LAN, 4.3, 4.4-local) are pure LAN and need no server, so they ship under local-first as-is.
  The remote and livestream features (4.2, 4.4-remote, the live link in 4.5) need a public relay and cannot be decided until T2 decides whether the follow may reach a server.
  Whole-room in-person scale (beyond the wifi-AP ceiling) points at on-phone ambient-audio follow, which is also a T2 question.
- **T4 (WCAG AA) makes 4.3 a requirement, not a nice-to-have.**
  The accessibility mode is the sangat-facing expression of the AA bar.
- **Reuse, do not rebuild, the corpus.**
  BaniDB and the ShabadOS data already carry the translations, transliterations, and named vishraam sources, keyed by a stable `verseId` our order ids can align to; the app already ships an enriched local copy.
  The build cost is in the companion views and the optional relay, not in content.
- **Do not reinvent Sangat Sync or Shabad OS multi-device.**
  Between them they already prove that sangat want per-person translation on a second screen and that many devices can track one display.
  Our job is to remove the two limits neither of them crosses: the operator and the venue lock, by driving the pointer from audio.

---

## Sources

### SikhiToTheMax, Khalis, and Shabad OS

- [SikhiToTheMax Sync (Sangat Sync)](https://www.sikhitothemax.org/sync)
- [SikhiToTheMax Bani Controller](https://www.sikhitothemax.org/control)
- [SikhiToTheMax web help](https://www.sikhitothemax.org/help)
- [STTM desktop HELP.md (larivaar, vishraam sources, themes)](https://github.com/KhalisFoundation/sttm-desktop/blob/dev/HELP.md)
- [STTM verse-level deep-link example (highlight = verseId)](https://www.sikhitothemax.org/shabad?id=5532&highlight=60319)
- [Khalis support: how to share a shabad (sttm.co short URLs)](https://support.khalisfoundation.org/support/solutions/articles/63000076431-how-do-i-share-a-shabad-with-someone-)
- [Khalis support: Zoom Overlay (remote captions, operator-side)](https://support.khalisfoundation.org/support/solutions/articles/63000255302-how-to-use-zoom-overlay-with-sikhitothemax)
- [Khalis support: coloured words / vishraam explainer](https://support.khalisfoundation.org/support/solutions/articles/63000258096-what-are-some-words-in-different-colors-)
- [Khalis Foundation Apps (Sundar Gutka, Learn Larivaar, MyPothi)](https://khalisfoundation.org/apps/)
- [SikhiToTheMax mobile on the App Store (SHARE Charity)](https://apps.apple.com/us/app/sikhitothemax/id1370303478)
- [SikhiToTheMax help mirror (SHARE Charity)](https://sharecharityuk.com/sttmhelp/)
- [STTM mobile vs web ownership split (Discover Sikhism)](https://www.discoversikhism.com/sikhism/sikhitothemax_everywhere.html)
- [Shabad OS GitHub org](https://github.com/shabados)
- [Shabad OS presenter README (server model, multi-device, broadcast captions)](https://github.com/shabados/presenter)

### Personal readers and corpus APIs

- [iGurbani on the App Store](https://apps.apple.com/us/app/igurbani/id569235977)
- [iGurbani official site](https://www.igurbani.com)
- [GurbaniNow](https://www.gurbaninow.com)
- [SriGranth reader](https://www.srigranth.org/servlet/gurbani.gurbani?Action=Page&Param=1)
- [Sundar Gutka on Google Play](https://play.google.com/store/apps/details?id=com.WahegurooNetwork.SundarGutka)
- [BaniDB Alliance (open corpus/API)](https://www.banidb.com/)
- [BaniDB per-line data model (verseId, larivaar, visraam, translations)](https://api.banidb.com/v2/shabads/1)
- [BaniDB partner page: iGurbani (named vishraam source)](https://www.banidb.com/partners/igurbani/)

### Audio-sync and sharing precedents (Sikh)

- [Sikh World – Nitnem & Gurbani (karaoke line-highlight)](https://apps.apple.com/us/app/sikh-world-nitnem-gurbani/id1177339919)
- [SikhNet Play (track-level text follow)](https://apps.apple.com/us/app/sikhnet-play/id487763229)
- [SikhNet Shabad Printer (quote/print tool)](https://www.sikhnet.com/news/gurbani-shabad-printer)
- [iGranth Gurbani Share (per-line image cards)](https://igranth-gurbani-share.soft112.com/)

### Cross-domain precedent (how followers join and what they see)

- [YouVersion Events (2016): self-paced guide plus live moments](https://blog.youversion.com/2016/03/introducing-events-the-newest-feature-in-the-bible-app/)
- [YouVersion Live (2009): the real-time verse-push it later pulled back from](https://blog.youversion.com/2009/09/introducing-youversion-live/)
- [YouVersion Events FAQ (join by link, QR, location search)](https://partner-support.youversion.com/l/en/article/tj4xeapuix-events-faq)
- [ProPresenter Stage Display (stage-only, no congregation push)](https://renewedvision.com/propresenter/stage-display)
- [Wordly church translation (QR join, per-viewer language and captions)](https://www.wordly.ai/church-translation)
- [Interprefy in-person (QR to language channel, no AV setup)](https://www.interprefy.com/solutions/use-cases/in-person-meetings-no-av-equipment)
- [Resi church live streaming (QRclick pointer in the stream)](https://resi.io/church-live-streaming/)
- [CUE Audio (ambient inaudible audio sync, no wifi)](https://www.connectwithcue.com/)
- [AirScript (personal synced opera libretto, multi-language)](https://en.wikipedia.org/wiki/Airscript)
- [Watermarking vs fingerprinting for companion-app sync (Red Bee)](https://www.redbeemedia.com/blog/watermarking-vs-fingerprinting-how-to-synch-companion-apps/)
- [ACRCloud second-screen synchronization](https://acrcloud.com/second-screen-synchronization)

### Accessibility and the live-Gurbani context

- [Accessibility in Sikh Spaces (Baaz News): "unable to read along to Bani"](https://www.baaznews.org/p/accessibility-sikh-spaces-disabilities-in-focus)
- [Golden Temple accessibility for disabled people (The Quint)](https://www.thequint.com/my-report/golden-temple-not-disabled-friendly-persons-with-disabilities-sikh-gurdwara)
- [Importance of Larivaar (Nihung Santhia)](https://www.nihungsanthia.com/post/importance-of-lareevaar)
- [SGPC Live (Gurbani livestream)](https://sgpclive.com/)
- [SikhNet Radio (global live kirtan)](https://play.sikhnet.com/radio)

### Caveats

- STTM web PWA/offline capability, and screen-reader / WCAG compliance in any of these apps, could not be verified and are not claimed.
- Whether current YouVersion Events still supports operator-pushed verse-by-verse advance is ambiguous in public docs; the 2009 Live clearly did.
- Ambient-audio sync accuracy (CUE, TV watermark/ACR) is described qualitatively; vendors publish no numeric latency spec.
