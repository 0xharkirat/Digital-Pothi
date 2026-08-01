# R1 · Research: better ASR approaches

Labels: wayfinder:research
Status: closed
Blocked by: —
Assignee: (resolved by research agent)

## Question

Survey approaches to improve Gurbani live-transcription accuracy beyond the
current finetuned CTC + tracker: model families, decoding/rescoring, and the
SGPC-livestream-banner ground-truth eval loop.

Output: research/R1-asr-approaches.md — candidate approaches, what each buys,
cost/complexity, and which are worth prototyping. Ground on the measured
regimes (finetune 4x better; retrieval breaks at GGS scale; funnel worse).

## Resolution

Resolved 2026-08-01. Findings: [../research/R1-asr-approaches.md](../research/R1-asr-approaches.md)

On-device wins: corpus-constrained (n-gram/FST) decoding + closed-set forced alignment, source separation (Spleeter/UVR, already in sherpa-onnx) for the kirtan gap, and promoting the SGPC-livestream OCR loop to a continuous eval + kirtan-training flywheel. Keep the finetuned IndicConformer (the aligned dataset is the moat); watch Meta Omnilingual 300M-CTC. Free-form "bigger ASR" is not the lever.
