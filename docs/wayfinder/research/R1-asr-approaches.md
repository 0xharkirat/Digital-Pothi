# R1 · Better ASR approaches for Gurbani live transcription

Ticket: [R1 · Better ASR approaches](../tickets/R1-asr-approaches.md) · research · charted 2026-08-01

Survey of ways to push live-transcription accuracy past the current finetuned-CTC + tracker stack, weighted toward closing the kirtan gap.
Grounded on the measured regimes already established in this project: finetune is ~4x better than base, paath sits at ~16% WER and kirtan caps near ~55% WER even after 420h of finetuning, the naive escalation funnel scored worse than either model alone, and brute-force retrieval breaks at full Guru Granth Sahib scale.
Those are properties of the scripture and the singing, not of any one model, so no amount of "bigger ASR" erases them.

## TL;DR

Prototype these three first, in this order:

1. **Constrain decoding and matching to the closed corpus** (corpus-biased CTC decoding + closed-set forced alignment). Attacks the root cause, reuses the runtime already shipped, helps paath and kirtan both.
2. **Source-separation front-end for kirtan** (sherpa-onnx Spleeter / UVR, on-device, same runtime). The only lever aimed squarely at the 55% kirtan WER.
3. **Turn the livestream OCR loop into a continuous eval harness and a kirtan training harvester.** Makes 1 and 2 measurable and compounds into a data flywheel.

Everything else (bigger backbones, Whisper prompt-biasing, RNNT hotwords, augmentation re-finetunes) is a second-tier lever that only pays off once the eval harness exists to prove it.

## The frame: where accuracy is actually lost

The current pipeline forces audio through a lossy open-vocabulary transcript before matching a *known, finite* 141k-line corpus.
That is the structural mistake.
The model is allowed to emit any Gurmukhi string, then a fuzzy matcher tries to snap that string back onto the one corpus line that was always the only legal answer.
Every gain below is really about spending the closed-corpus prior earlier, or about cleaning the signal before the model sees it, rather than buying a marginally better open-vocabulary transcriber.

Two hard constraints carry over from the corpus-ambiguity work and bound what any approach can achieve:

- Kirtan holds one tuk across many audio windows, so a single chunk is a fragment ("saajan de"), never a line. Locating has to accumulate over a rolling multi-chunk buffer; the follower stays single-chunk.
- Lines repeat verbatim across sources (a Japji line is byte-identical to a Sukhmani line), so no single chunk can disambiguate. The next chunk votes.

Any decoding or model change has to respect both, or it trades a frozen tracker for one that teleports on noise.

---

## A. Model families

### Keep IndicConformer-pa hybrid CTC+RNNT (120M) as the baseline

The shipped finetune (surindersinghssj v3) is the asset, and its real moat is the canonicalized aligned ~660h dataset, not the weights.
It already exports to ONNX and runs in sherpa-onnx at ~0.05-0.08 RTF on CPU (measured in-project).
Do not swap the backbone casually: any new backbone throws away the finetune and needs the aligned data re-applied.

One under-used property: it is a *hybrid* model, so the RNNT/transducer decoder branch is available alongside the CTC branch the app currently uses.
That matters for biasing (see section B) because sherpa-onnx supports hotwords only on transducer decoders, not CTC.

### Meta Omnilingual ASR (Nov 2025) — the most credible new backbone

wav2vec2 backbone pretrained on 4.3M hours across 1600+ languages, released open-source with a model family at 300M / 1B / 3B / 7B and both CTC and LLM-decoder heads.
The **300M CTC** variant is explicitly aimed at low-power devices, uses fairseq2's standard CTC implementation (ONNX-export path plausible but unverified), and reports character error below 10% for 78% of covered languages.
Punjabi is in the covered set (Meta's earlier MMS already shipped a Punjabi adapter, and Omnilingual is a superset); confirm `pan` coverage and CER on the model card before committing.
It also offers zero-shot in-context learning (supply a few paired examples at inference), which is interesting for a closed liturgical domain but is a research bet, not a shipping path.
Verdict: the strongest candidate *if* a backbone change is ever justified, but only after a re-finetune on the aligned Gurbani data and an ONNX/sherpa export check. Not a drop-in.
https://github.com/facebookresearch/omnilingual-asr · https://arxiv.org/abs/2511.09690

### Meta MMS wav2vec2 (Punjabi adapter) — valuable mainly for its aligner

The Punjabi ASR adapter is unremarkable next to the existing finetune.
The reason MMS matters here is its **forced-alignment** release (MMS-FA), a multilingual CTC aligner that snaps known text to audio.
That is a tool for section B, not a transcriber to adopt.
https://huggingface.co/facebook/mms-1b-all · https://ai.meta.com/blog/multilingual-model-speech-recognition/

### NVIDIA Nemotron 3.5 ASR streaming (0.6B) — watch, do not adopt yet

Streaming, 40 locales including South Asian languages and Devanagari-script output, and a sherpa-onnx export path is actively in progress (k2-fsa issue #3664).
Punjabi is not confirmed in the locale list, and it carries no Gurbani finetune.
Track it for when native streaming multilingual lands, but it does not beat the finetuned IndicConformer on this task today.
https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b

### NVIDIA Parakeet TDT / AI4Bharat 600M — skip / defer

Parakeet is fast and ONNX-friendly but has no Indic coverage, so it is off the table for Punjabi.
AI4Bharat's newer 600M multilingual IndicConformer covers Punjabi but at 5x the parameters of the shipped model and, again, with no Gurbani finetune; the on-device cost is not worth it over the existing 120M finetune.

---

## B. Decoding and rescoring: spend the closed-corpus prior earlier

This is the highest-leverage axis and the cheapest, because most of it runs inside the sherpa-onnx runtime already in the app.

### Closed-set forced alignment instead of transcribe-then-fuzzy-match

Once the tracker has a shabad candidate, the *text of that shabad is known*.
So the question stops being "what did they say" and becomes "where in this known line are they", which is forced alignment over CTC posteriors, not open decoding.
Mature tools do exactly this: NVIDIA's NeMo Forced Aligner (Viterbi over the CTC log-probs against given text), the CTC-segmentation toolkit (NeMo-integrated), and MMS-based `ctc-forced-aligner`.
This is the same design Quranic-recitation systems use to follow a fixed text (HMM/CTC forced alignment), which is the closest published prior art to a live scripture follower.
What it buys for kirtan: instead of asking a 55%-WER transcript to name the line, you score how well the audio aligns to the *handful* of candidate lines the tracker already anchors, which is a far easier, closed problem.
Cost: medium. sherpa-onnx does not yet ship a first-class aligner API (feature request k2-fsa #3536), so a prototype runs the aligner in the Python dev-lab first, or reads CTC posteriors out of sherpa and does Viterbi in Dart.
https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/tools/nemo_forced_aligner.html · https://github.com/MahmoudAshraf97/ctc-forced-aligner · https://ieeexplore.ieee.org/document/10371319/

### Corpus-constrained CTC decoding (HLG / n-gram WFST)

sherpa-onnx exposes an online CTC FST decoder (`OnlineCtcFstDecoderConfig`, plus a blank-penalty knob).
Compile an n-gram language model from the 141k-line corpus into an HLG graph and decode the CTC output against it, so the search is a joint acoustic + corpus-LM search rather than free-form.
The transcript then lands on plausible Gurbani token sequences by construction, which shrinks the substitution noise the fuzzy matcher has to absorb.
Buys: cleaner transcripts on both paath and kirtan for near-zero added latency, entirely in-runtime.
Cost: low-to-medium (build the HLG once, offline). Risk: an over-tight LM can wallpaper genuine out-of-corpus audio (katha, ardaas) into scripture, so this must be gated by the same out-of-corpus detection the tracker already needs.
https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/c-api/c-api.h · https://k2-fsa.github.io/sherpa/onnx/index.html

### Hotword / contextual biasing on the RNNT branch

sherpa-onnx hotwords (Aho-Corasick contextual biasing) work only on transducer decoders, not CTC.
The shipped model *is* hybrid, so switching the follower to the RNNT branch unlocks it: after the locator picks a shabad, feed that shabad's words as hotwords to bias the RNNT decode toward the lines actually on screen.
Buys: targeted boosting of the current-shabad vocabulary, which is precisely where kirtan fragments are hardest to recover.
Cost: medium (dual-branch runtime, retune the follower against RNNT output, which is jumpier than CTC).
https://k2-fsa.github.io/sherpa/onnx/hotwords/index.html

### Keyword-spotting against verse-distinctive words

sherpa-onnx open-vocabulary keyword spotting (transducer, boosting-based) can watch for the rare, distinctive words of the anchored shabad rather than transcribing everything.
Useful as a cheap *confirmation* signal for the tracker ("did the distinctive word of the expected next line just fire") rather than as the primary transcriber.
Lower priority than the two above, but a clean way to add confidence without a full second decode.
https://k2-fsa.github.io/sherpa/onnx/kws/index.html

### Whisper `initial_prompt` biasing — low priority

The surt-small Whisper finetune supports `initial_prompt` to nudge vocabulary, but the prompt is capped at 224 tokens (nowhere near a shabad), and it is documented to *increase* hallucination and disfluency.
The CTC path is the runtime, so this is a dev-lab curiosity, not a shipping lever.
https://github.com/ggml-org/whisper.cpp/issues/1979 · https://arxiv.org/pdf/2410.18363

---

## C. Domain adaptation for sung audio

The kirtan gap is fundamentally a train/test mismatch: the model learned speech-like acoustics, and singing stretches vowels, adds vibrato, and rides melody.

### PDAugment-style pitch/duration augmentation (train-time, no new labels)

PDAugment adjusts the pitch and duration of ordinary *speech* under the guidance of music scores to synthesize singing-like training data, and reported 5.9% and 18.1% absolute WER improvements on lyric transcription.
Applied here: take the abundant, cheap paath/sehaj audio (which transcribes well) and augment it into synthetic sung Gurbani to close the kirtan gap *without needing more hand-labeled kirtan*.
Buys: attacks the 55% cap at its source. Cost: high (a re-finetune cycle in the dev-lab), but it reuses data you already have.
https://arxiv.org/abs/2109.07940

### wav2vec2 pretrained on singing, then finetuned

Recent ALT work shows a wav2vec2 pretrained on large-scale singing can be finetuned directly for lyric transcription, skipping the usual speech-to-singing transfer step.
This is the same backbone family as Omnilingual/MMS, so it dovetails with a future backbone move rather than being a separate bet.
Research-tier; park it behind the augmentation route.

---

## D. Source separation for kirtan (the direct kirtan lever)

Kirtan audio is vocals plus tabla and harmonium, and the accompaniment is loud relative to normal speech noise, which is a primary cause of the WER blow-up.
The published result is directly on point: running Whisper on separated vocals (Hybrid Demucs `mdx_extra`) improved substitution rate and set a state-of-the-art open-source result on the Jam-ALT long-form lyric benchmark, and the separation signal doubles as a vocal-activity detector for segmentation.
Same paper's caveat: separation can *increase hallucinations*, so it must be gated, not applied blindly.
https://arxiv.org/abs/2506.15514

The decisive fact for this project: **sherpa-onnx already ships source separation as a first-class, on-device feature, in the exact runtime the app uses.**

- Spleeter 2-stem (vocals/accompaniment), ONNX with int8/fp16, RTF ~0.072-0.079 on one CPU thread (~12-14x real time). Fast enough to run per-window with headroom.
- UVR-MDX-NET, 17 models at 28-64MB, cleaner vocals but ~10x slower (RTF ~0.6-0.7, still ~1.5x real time on CPU).
- Both are offline (whole-buffer), not streaming, which fits the app's existing windowed pipeline with a little buffering; latency is the tuning knob.
- Speech-enhancement models (GTCRN, DPDFNet) are also available if full separation is overkill for lighter accompaniment.

Buys: a cleaner vocal signal into the *same* CTC model for kirtan, no model retrain, one new preprocessing stage.
Cost: low-to-medium. Start with Spleeter (cheap) as a front-end when the tracker is in kirtan mode; escalate to UVR only if quality demands it. Gate on the hallucination risk by comparing pre/post-separation locate confidence.
https://k2-fsa.github.io/sherpa/onnx/source-separation/models.html · https://github.com/k2-fsa/sherpa-onnx/releases/tag/source-separation-models · https://github.com/k2-fsa/sherpa-onnx/releases/tag/speech-enhancement-models

---

## E. The livestream ground-truth loop as a data flywheel

This is already built (SGPC banner OCR to `locate()` to timestamped truth, measured 92.4% within 2 lines where the banner is clean) and it is the highest-leverage *meta* investment, because it turns every lever above from a guess into a measured delta.

Two roles:

- **Continuous eval harness.** Every change in sections A-D gets scored over hours of the real paath/kirtan/ardaas mix with zero manual labeling. Without this, "did source separation help kirtan" is an opinion.
- **Kirtan training harvester.** The banner gives the clean corpus line (label) and the audio gives the timing, so the same aligned pairs are finetuning and forced-alignment data, harvested specifically over kirtan and over the out-of-corpus stretches (katha, ardaas) that no current model handles.

The known limiter is banner OCR coverage (~16-35% of frames on the stylized low-contrast font), not the tracker, so better crop/threshold preprocessing directly raises yield.
This loop is what makes the PDAugment re-finetune (section C) and any backbone move (section A) affordable: it supplies the labeled kirtan data those levers need.

---

## Ranked shortlist

| # | Approach | What it buys (esp. kirtan) | Cost / complexity | On-device (sherpa-onnx / ONNX) |
|---|---|---|---|---|
| 1 | Corpus-constrained decoding + closed-set forced alignment (B) | Stops discarding the closed-corpus prior; scores audio against known lines instead of naming them | Low-Med; HLG built offline, aligner in dev-lab first | CTC-FST decoder is in-runtime; aligner API not yet native (workaround) |
| 2 | Source separation front-end for kirtan (D) | Cleaner vocals into the same model; the direct attack on 55% WER | Low-Med; one preprocessing stage, gate on hallucination | Native: Spleeter RTF ~0.08, UVR RTF ~0.6, same runtime |
| 3 | Livestream OCR loop as eval + harvester (E) | Makes 1/2/others measurable; harvests kirtan + out-of-corpus training data | Low; extend existing tool, improve OCR crop | Dev-lab (Python), not on device |
| 4 | RNNT-branch hotword biasing to current shabad (B) | Boosts current-shabad vocabulary where fragments are hardest | Med; dual-branch runtime, retune follower | Native (transducer hotwords) |
| 5 | PDAugment pitch/duration re-finetune (C) | Closes kirtan gap at the source, no new labels | High; a finetune cycle | Reuses existing ONNX export |
| 6 | Omnilingual 300M CTC backbone (A) | Modern wav2vec2 backbone, low-power target | High; re-finetune + export check | 300M CTC plausible; verify `pan` + ONNX |
| 7 | Whisper `initial_prompt` biasing (B) | Minor vocab nudge | Low | Off-runtime (Whisper), hallucination-prone |

## Prototype first (the 2-3)

1. **Corpus-constrained decoding + closed-set forced alignment.**
   Biggest structural win, reuses the shipped runtime, helps paath and kirtan.
   Build the corpus n-gram HLG for the sherpa CTC-FST decoder, and stand up a forced-alignment scorer (NeMo NFA or `ctc-forced-aligner`) in the dev-lab to reframe matching as "align to the anchored candidate lines" rather than "transcribe then fuzzy-match".

2. **Source-separation front-end for kirtan.**
   The one lever pointed straight at the 55% number, and it is a native sherpa-onnx feature so the prototype is a preprocessing stage, not a new dependency.
   Start with Spleeter 2-stem when the tracker is in kirtan mode; measure locate-confidence pre/post separation; escalate to UVR only if needed.

3. **Livestream loop as the continuous eval + kirtan harvester.**
   Do this alongside 1 and 2, not after, because it is what proves whether they helped and it feeds the training data the later levers (PDAugment, backbone swap) will need.

Second tier, gated on the eval harness existing: RNNT-branch hotword biasing, then a PDAugment re-finetune, then re-evaluating Omnilingual as a backbone.

## Sources

- IndicConformer-pa hybrid CTC+RNNT: https://huggingface.co/ai4bharat/indicconformer_stt_pa_hybrid_ctc_rnnt_large
- Meta Omnilingual ASR (1600+ langs, wav2vec2, 300M-7B, CTC/LLM heads): https://github.com/facebookresearch/omnilingual-asr · https://arxiv.org/abs/2511.09690 · https://ai.meta.com/blog/omnilingual-asr-advancing-automatic-speech-recognition/
- Meta MMS (Punjabi adapter + forced alignment): https://huggingface.co/facebook/mms-1b-all · https://ai.meta.com/blog/multilingual-model-speech-recognition/
- NVIDIA Nemotron 3.5 ASR streaming 0.6B: https://huggingface.co/nvidia/nemotron-3.5-asr-streaming-0.6b · sherpa export request https://github.com/k2-fsa/sherpa-onnx/issues/3664
- Music source separation for lyric transcription with Whisper (Hybrid Demucs mdx_extra, Jam-ALT SOTA, hallucination caveat): https://arxiv.org/abs/2506.15514
- PDAugment (pitch/duration augmentation for ALT): https://arxiv.org/abs/2109.07940
- sherpa-onnx source separation (Spleeter / UVR, RTF numbers): https://k2-fsa.github.io/sherpa/onnx/source-separation/models.html · https://github.com/k2-fsa/sherpa-onnx/releases/tag/source-separation-models
- sherpa-onnx speech enhancement (GTCRN / DPDFNet): https://github.com/k2-fsa/sherpa-onnx/releases/tag/speech-enhancement-models
- sherpa-onnx hotwords (transducer-only, Aho-Corasick): https://k2-fsa.github.io/sherpa/onnx/hotwords/index.html
- sherpa-onnx keyword spotting (open-vocabulary): https://k2-fsa.github.io/sherpa/onnx/kws/index.html
- sherpa-onnx CTC-FST decoding + blank penalty (C API), forced-alignment feature request #3536: https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/c-api/c-api.h · https://github.com/k2-fsa/sherpa-onnx/issues/3536
- NeMo Forced Aligner (NFA): https://docs.nvidia.com/nemo-framework/user-guide/latest/nemotoolkit/tools/nemo_forced_aligner.html
- CTC forced aligner (MMS-based): https://github.com/MahmoudAshraf97/ctc-forced-aligner
- Forced alignment for Quranic recitation (closest scripture-follow prior art): https://ieeexplore.ieee.org/document/10371319/
- Whisper initial_prompt / contextual biasing (limits + hallucination): https://github.com/ggml-org/whisper.cpp/issues/1979 · https://arxiv.org/pdf/2410.18363
