#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["sherpa-onnx", "soundfile", "numpy"]
# ///
"""Transcribe an audio file into a test fixture: the exact chunk texts the app
would see.

Mirrors lib/engine/transcribe_isolate.dart - same 6s window on a 3s hop, same
finetuned IndicConformer-CTC ONNX through sherpa - so a fixture built here is
what the running app actually produces, not an approximation of it. Output is a
plain JSON array of chunk texts, which is what the tracking tests consume.

    tools/make_fixture.py --audio kirtan.wav --out test/fixtures/kirtan_sherpa_chunks.json

Any format ffmpeg can read is fine; it is converted to 16 kHz mono first.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import sherpa_onnx
import soundfile as sf

ASSETS = Path(__file__).resolve().parent.parent / "assets" / "models"


def load_mono_16k(path: Path) -> tuple[np.ndarray, int]:
    """Decode anything (mp3, m4a, stereo wav, odd sample rates) to 16 kHz mono."""
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "audio.wav"
        subprocess.run(
            ["ffmpeg", "-nostdin", "-loglevel", "error", "-y",
             "-i", str(path), "-ac", "1", "-ar", "16000", str(wav)],
            check=True,
        )
        samples, rate = sf.read(wav, dtype="float32")
    return samples, rate


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--model", type=Path, default=ASSETS / "indicconformer-pa-ctc.onnx")
    ap.add_argument("--tokens", type=Path, default=ASSETS / "tokens.txt")
    ap.add_argument("--window", type=float, default=6.0, help="seconds (app: 6)")
    ap.add_argument("--hop", type=float, default=3.0, help="seconds (app: 3)")
    args = ap.parse_args()

    samples, rate = load_mono_16k(args.audio)
    recognizer = sherpa_onnx.OfflineRecognizer.from_nemo_ctc(
        model=str(args.model),
        tokens=str(args.tokens),
        num_threads=2,
        decoding_method="greedy_search",
    )

    window, hop = int(rate * args.window), int(rate * args.hop)
    chunks: list[str] = []
    for start in range(0, len(samples), hop):
        stream = recognizer.create_stream()
        stream.accept_waveform(rate, samples[start : start + window])
        recognizer.decode_stream(stream)
        chunks.append(stream.result.text.strip())

    args.out.write_text(json.dumps(chunks, ensure_ascii=False, indent=1) + "\n")
    spoken = sum(1 for c in chunks if c)
    print(
        f"wrote {args.out}: {len(chunks)} chunks "
        f"({len(samples) / rate / 60:.1f} min, {spoken} non-empty)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
