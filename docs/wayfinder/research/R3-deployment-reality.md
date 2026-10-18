# R3 - Gurdwara Deployment Reality

Ticket: R3 (Wayfinder research).
Question: how is Gurbani projection actually run in Gurdwaras today, and what does that force on our v1 scope and our on-device-vs-network decision.
Method: web research grounded in STTM docs/source, the Khalis Foundation, the Live Gurbani Tracking paper, a competing open-source presenter (Shabad OS), app-store reviews, and rural-connectivity data.
Status: read-only research. No code touched.

## TL;DR

The incumbent is SikhiToTheMax (STTM), a free open-source desktop app that has been the de facto standard in Gurdwaras since 2000.
It runs on a laptop wired to a projector or TV in extended-desktop mode, driven live by a volunteer (sewadar) who types the first letter of each word to find the shabad and then clicks line-by-line to keep the display in sync with the singer.
The core display path already works fully offline after the one-time database download, so any network dependency we add is a regression against the thing we are replacing.
The hard, unautomated part is exactly the part we want to automate: manually following live kirtan line-by-line.
The two things that matter most for our decisions: (1) misspelled Gurmukhi is religiously unacceptable, which kills free-form ASR and forces canonical-line snapping, and (2) the deployment environment is often low-bandwidth and power-flaky, which pushes the AI follow on-device.

## 1. The real-world deployment picture

### The dominant stack

SikhiToTheMax is described by its own maintainer as "the world's most popular Gurbani presentation software," and its source repo calls it "a de facto standard for Keertans and Gurdwaras around the world."
It started in 2000, built by SHARE Charity UK, and is now maintained by the Khalis Foundation as seva (donated volunteer service), open source, accepting pull requests.
It became the standard fixture at Gurdwara diwans, kirtan events, rensbai (all-night kirtan), and smagams (large programs) for showing shabads on-screen so the sangat can read or sing along.
There is a real, purpose-built open-source competitor, Shabad OS Presenter, but it has not displaced STTM.

The projection stack in typical use:

- A Windows or macOS laptop runs the STTM desktop app. Linux builds also exist. Windows 7 legacy builds are still shipped, which tells you what hardware is still in the field.
- The laptop is wired to a projector or a large TV/LED screen mounted so the sangat faces both the Guru Granth Sahib and the text.
- Display is set to extended desktop (not mirroring): the operator sees the search/control window on the laptop, the sangat sees only the clean "Presenter View" full-screen output.
- Wireless display over Chromecast is a supported alternative to an HDMI cable, and STTM documents casting to it in a line-by-line presentation mode.
- For livestreams, "Bani Overlay" feeds the current line into OBS (or straight to Facebook/YouTube) as a subtitle overlay with real-time translation, synced to the same laptop that drives the projector.

### The operator: who runs it and how

The operator is a sevadaar, a volunteer, not paid AV staff.
Skill level is uneven and there is no standard training pipeline. Comparable house-of-worship AV guidance treats volunteer training as "non-negotiable" precisely because it usually is not done well, and STTM's own help docs contain no operator training protocol, just setup steps.
The interaction the volunteer performs, straight from the Live Gurbani Tracking paper:

> "the sewadar listens for the opening words of the next shabad, types the first letter of each word into a search box, picks the matching shabad from a candidate list, and then clicks line-by-line through the shabad's verses as the singer advances."

So the manual workload has two distinct phases:

1. Identify the shabad. Catch the opening words, type first-letters (for example `gmsshn`), disambiguate from a candidate list. STTM also supports wildcard and filtered search.
2. Track within the shabad. Click the display forward one line at a time, staying locked to whatever line the ragi is currently on, through repeats, pauses, and tempo changes.

Recent STTM versions try to relieve the operator's physical tether, not the cognitive load: the app can be controlled remotely from a phone/tablet ("controllers"), so the operator can sit with the kirtani or in the sangat instead of behind the laptop. "Sangat Sync" lets individuals mirror the live display on their own phones. None of this automates the line-following. A human is still the tracker.

### Live kirtan vs paath vs ceremonies

- Kirtan (sung hymns). Non-sequential and improvised. The ragi picks a shabad, may repeat a line many times, may pause for viakhya (explanation), changes tempo. This is the case that demands active, moment-to-moment human tracking, and it is the case the arxiv reference system targets.
- Paath (recited reading, for example Sukhmani Sahib, sehaj/akhand paath). Sequential: the text advances ang-by-ang (page-by-page) in canonical order, so the operator mostly pages forward. STTM even has an Akhand Paat scrolling mode. Reviewers report the app "lags when going to the next ang" during sehaj paath, which is a performance complaint on an otherwise-simple flow.
- Ceremonies (Anand Karaj wedding Laavan, Sukhmani Sahib paath, specific occasion banis). Largely scripted and predictable in content and order, even if timing varies.

The difficulty ranking for automatic following is kirtan >> paath > ceremonies.
This maps directly onto our v1 scope question (Section 6).

## 2. Room and network constraints

### The physical room

- Low light. Darbar halls are lit for atmosphere and for the Guru Granth Sahib, not for screen contrast. Projector guidance repeatedly notes projectors need controlled lighting to stay legible; in practice halls compromise. High-contrast, large Gurmukhi is mandatory, not a nicety.
- Reading distance. Sangat sits on the floor across a deep hall; the back rows are far from the screen. This is why STTM defaults to one or two large lines at a time rather than paragraphs, and why font-size/legibility complaints recur in reviews.
- Display variety. Single projector, dual screens in one hall (STTM users describe HDMI splitters/repeaters and Chromecast to drive two screens), or wall-mounted TVs. Our output has to look right on all of them.
- Larivaar vs padd-ched. STTM exposes Larivaar (continuous, no word spaces), Gutka-style grouping, and bisraam (pause) marks as display toggles. These are real, expected display options, and one review flagged the Larivaar/bisraam toggles breaking after an OS update.

### The network

The core claim to internalize: STTM's display path is offline-first.
Internet is required once to download the Gurbani database at install, and after that "internet connection is not needed but recommended" only to pull database updates.
An offline installer is listed as "coming soon," and STTM II already shipped an offline database so Gurdwaras can "operate independently from internet connectivity during services."
Meanwhile the deployment environment, especially in Punjab and rural diaspora Gurdwaras, is genuinely bandwidth- and power-constrained:

- Only ~3.8% of rural Indian households have high-speed fibre (vs ~15.3% urban); rural connectivity is often slow, congested mobile data rather than stable Wi-Fi.
- Power outages and load-shedding are frequent daily occurrences in rural Punjab, which also takes down any router/ONT.
- Livestreaming (where it happens) already competes for that same thin uplink.

Implication: an incumbent that works with the internet unplugged has set the baseline. A new app whose AI follow needs a live server round-trip per line would be strictly worse on exactly the days the network is down.

## 3. Switching costs and STTM pain points

### Why STTM is entrenched

- Price and licence. Free, open source, framed explicitly as seva. There is no budget line to defend a paid replacement.
- Canonical data. It ships the full, community-trusted corpus: Sri Guru Granth Sahib, Dasam Granth, Bhai Gurdas, Bhai Nand Lal, rehatnamas, with translations in multiple languages. Getting the text exactly right is table stakes and it already has.
- Operator muscle memory. The first-letter search and line-click flow is what every existing sevadaar already knows. Retraining volunteers is a real cost.
- Institutional default. Two decades as the standard means committees, ragis, and AV volunteers all assume STTM. It is the safe choice nobody gets blamed for.
- Ecosystem lock-in. Controllers, Sangat Sync, and the OBS Bani Overlay are already wired into how some Gurdwaras livestream.

### STTM's actual pain points (the openings)

Grounded in app-store reviews and the maintainer's own modernization drive:

- Manual live-following is laborious and error-prone. The entire kirtan use-case is a human doing real-time search-and-click. This is the unautomated gap, and it is our whole reason to exist.
- Performance rough edges. Reviewers report lag advancing to the next ang during sehaj paath, and a broken "search a pankti" (line) flow that dumps the user back to the search page.
- Fragility across OS updates. Display toggles (Larivaar, bisraam) reported breaking after an OS update. Legacy Windows-7 builds signal an aging install base.
- Rebuild churn. Khalis rebuilt STTM to reach "more devices, more locations, faster speeds," which is itself an admission the old stack was slow and hard to extend.

### The competitive landscape (for switching context)

- Shabad OS Presenter. Open-source, purpose-built for projectors/TVs/livestreams at diwans and smagams, with a server/controller model where multiple devices act as display or controller. It is the closest thing to what we are building, and notably it is still a manual presenter with no automatic audio-following. That is the open lane.
- iGurbani, Gurbani Anywhere, Sundar Gutka, SikhNet, etc. Mostly personal/mobile reading and search apps; some kirtani use a phone as an ad-hoc projector when nobody else is running the display. Not projection-first.

Bottom line on switching: nobody switches a Gurdwara projector setup for a marginally nicer manual presenter, and definitely not for a paid or online-only one.
The only switch worth the retraining risk is a capability STTM does not have. Automatic, reliable line-following of live kirtan is that capability. It has to be additive (works alongside/like STTM, offline, free) rather than a rip-and-replace.

## 4. Constraints a v1 must respect (hard requirements)

1. Canonical Gurmukhi only, never free-form ASR text. Displaying misspelled Gurmukhi is religiously inappropriate. Every line shown must be a snapped canonical corpus line, not a transcription. This is non-negotiable and it is the core technical constraint.
2. Works offline. The display and the follow must run with the internet unplugged, because the incumbent does and because the rooms are network-flaky.
3. The human keeps control. The paper's own deployment runs a confirm-style interface (system proposes, a person taps to commit) rather than autonomously driving the display, because "sewadars must retain control over the display, especially in group settings." Full autopilot that can show the wrong scripture to the whole sangat is a trust non-starter for v1.
4. Legible at distance in a dark hall. Large, high-contrast Gurmukhi; support Larivaar/padd-ched and bisraam; behave on projector, TV, and dual-screen.
5. Free. Anything with a price tag is dead on arrival against a seva incumbent.
6. Low-end hardware and real-time budget. Target machines are modest laptops (Windows-7-era still around). The reference pipeline hits RTF ~0.05 on a single Apple Silicon core, so real-time follow on commodity hardware is proven feasible and must stay that cheap.

## 5. Implications for the two pending decisions

### Decision A: v1 scope (paath vs kirtan vs ceremonies)

The value and the difficulty point in opposite directions, so name the trade explicitly.

- Kirtan is the highest-value, most-visible, most-painful-to-do-manually case, and it is the one no competitor automates. It is also the hardest: non-sequential selection, line repeats, viakhya pauses, tempo swings. If we ship kirtan-follow and it works, that is the single feature that justifies switching from STTM.
- Paath is the tractable beachhead. It is sequential, so following is closer to "detect the current line and advance," and the ambiguity is mostly local. It is lower-glory but far higher-reliability, and STTM already annoys operators here (next-ang lag). Note the corpus caveat from our own MEMORY: paath runs ~1 canonical line per audio chunk and lines repeat verbatim across the corpus, which can break naive single-chunk locating and follower hysteresis, so even "easy" paath needs the fuzzy-matcher + state-machine, not a toy.
- Ceremonies are scripted and predictable, a narrow, demoable slice (for example Anand Karaj Laavan, Sukhmani Sahib), but a small market and not where the STTM pain is loudest.

Recommendation to carry into the scope decision: v1 should prove the follow on paath (reliability-first, sequential, forgiving), while architecting the matcher + state-machine so kirtan is the very next step, since kirtan is the actual reason a Gurdwara would switch.
Do not ship kirtan-follow as the headline of v1 unless it clears the "never show the wrong line to the sangat" bar, because a single public mistake burns the trust that switching requires.
Ship it behind the confirm-style interface first (operator taps to commit), matching the reference deployment, then earn autonomy.

### Decision B: on-device vs network for the AI follow

This one is close to decided by the environment.

- On-device wins on the constraints that actually bind here. The rooms are bandwidth- and power-constrained; the incumbent already works offline; and the reference system runs the full ASR-plus-matcher pipeline entirely on-device (INT8 ONNX, iOS app, no audio leaves the device), at RTF ~0.05 on one core.
- Privacy is a real bonus, not the driver. Not shipping hall audio to a server is good, but the deciding factor is that a networked follow fails exactly when rural power/network fails, i.e. when the incumbent still works.
- Where network is still fine: optional, non-blocking sync (database updates, the existing OBS/Bani-Overlay livestream path, Sangat Sync to phones, telemetry/ground-truth collection). Keep all of that off the critical path so pulling the ethernet cable degrades nothing that matters.

Recommendation to carry into the decision: default to on-device for the follow, treat the network as an optional enhancement layer. The reference implementation already demonstrates this is achievable on modest hardware, so "on-device" is not a research risk here, it is the proven path.

## Sources

- Live Gurbani Tracking: A Benchmark and Reference System for Captioning Sikh Kirtan (Karanbir Singh, 2026) - the manual sewadar workflow, misspelled-Gurmukhi constraint, on-device iOS pipeline, RTF ~0.05, confirm-style deployment: https://arxiv.org/html/2607.13457
- SikhiToTheMax desktop HELP.md (Khalis Foundation, GitHub) - extended-desktop + Presenter View setup, first-letter search, Bani Overlay/OBS: https://github.com/KhalisFoundation/sttm-desktop/blob/dev/HELP.md
- SikhiToTheMax desktop repo README ("de facto standard", platforms): https://github.com/KhalisFoundation/sttm-desktop
- SikhiToTheMax portfolio, Khalis Foundation ("world's most popular", Bani Overlay to FB/YouTube, Chromecast, offline installer "coming soon"): https://khalisfoundation.org/portfolio/sikhitothemax/
- SikhiToTheMax Release Candidate announcement (modernization goals): https://khalisfoundation.org/press-releases/949/
- SikhiToTheMax help (SHARE Charity UK) - Chromecast presentation, Larivaar/Gutka modes, multi-presenter mobile control: https://sharecharityuk.com/sttmhelp/
- Discover Sikhism, "Sikhi To The MAX Everywhere" (2000 origin, SHARE Charity UK, gurdwara projector history): https://www.discoversikhism.com/sikhism/sikhitothemax_everywhere.html
- Discover Sikhism, "Sikhi To The MAX II" (offline database, line-by-line display, operate without internet): https://www.discoversikhism.com/sikhism/sikhitothemaxII.html
- Shabad OS Presenter (open-source competitor; projector/TV/livestream presenter; server/controller model), GitHub: https://github.com/shabados/presenter and support: https://www.shabados.com/support/install-shabad-os-presenter/
- SikhiToTheMax on the Apple App Store (reviews: next-ang lag during sehaj paath, broken pankti search, Larivaar/bisraam toggle breaking after OS update): https://apps.apple.com/us/app/sikhitothemax/id1370303478
- Sikhi To The Max on Google Play: https://play.google.com/store/apps/details?id=com.nest.sttm
- SikhiWiki, Sikhitothemax (became "standard requirement" for on-screen shabads at kirtan/rensbai/smagams): https://www.sikhiwiki.org/index.php/Sikhitothemax
- 24 Gurbani Apps Which Have Changed the Sikh World (ecosystem/landscape, iGurbani and others): https://www.sikhnet.com/news/24-gurbani-apps-which-have-changed-sikh-world
- Rural broadband in India/Punjab (~3.8% rural fibre, unreliable mobile data): https://www.excitel.com/blogs/high-speed-internet-challenges-in-semi-urban-and-rural-areas-of-india/
- House-of-worship AV guidance (volunteer training "non-negotiable"; projectors need controlled lighting): https://vallect.com/blog/house-of-worship-auditorium-av-solutions/

### Research gaps / caveats

- Reddit (r/Sikh) and SikhNet threads were not directly retrievable (403 / blocked to the fetcher), so the "operator voice" is reconstructed from the STTM help docs, the arxiv paper's workflow description, app-store reviews, and house-of-worship AV analogs rather than raw forum quotes. The workflow itself is well-corroborated across sources.
- Rural-connectivity figures are India/Punjab-wide, not Gurdwara-specific measurements; use them as directional, not exact.
- The arxiv reference system appears to be this project's own predecessor work (single author, on-device iOS, same matcher+state-machine design). Treat it as the strongest signal for our own decisions, but also as an interested source rather than an independent third party.
