#!/usr/bin/env python3
"""Turn a slice of an SGPC livestream into an eval pair: what the tracker sees
(audio) and what the SGPC operator displayed (the on-screen banner).

One download per slice - a 360p mp4 - gives both:
  * 16 kHz mono audio  -> tools/make_fixture.py -> chunks.json  (tracker input)
  * one frame per hop  -> tesseract (Gurmukhi) -> banner.json   (ground truth)

Both land on the same 3s grid (chunk i and frame i cover the same moment), so
the Dart scorer aligns them by index. The banner OCR is noisy; the Dart side
snaps it to an exact corpus line with the same locate() the tracker uses, so
imperfect OCR still yields a clean truth label.

    tools/eval_livestream.py --url <live-url> --start 3:00:00 --dur 1800 \
        --out test/fixtures/_eval_livestream

Needs yt-dlp, ffmpeg, tesseract (with `pan`) on PATH. Idempotent per slice: it
skips the download if the segment mp4 is already there.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HOP = 3.0  # seconds; must match make_fixture.py / transcribe_isolate.dart
HERE = Path(__file__).resolve().parent
MAKE_FIXTURE = HERE / "make_fixture.py"

# Banner Gurmukhi line on the 360p frame: a strip across the lower third. Cropped
# generously and upscaled - tesseract does better on big, high-contrast text.
BANNER_CROP = "crop=640:44:0:288,scale=iw*4:ih*4,format=gray,eq=contrast=1.6"


def hms(t: str) -> int:
    """'3:00:00' or '90' -> seconds."""
    if ":" not in t:
        return int(t)
    p = [int(x) for x in t.split(":")]
    while len(p) < 3:
        p.insert(0, 0)
    return p[0] * 3600 + p[1] * 60 + p[2]


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--start", required=True, help="HH:MM:SS or seconds")
    ap.add_argument("--dur", type=int, required=True, help="seconds")
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    start = hms(args.start)
    end = start + args.dur
    seg = out / "segment.mp4"
    wav = out / "segment.wav"
    frames = out / "frames"

    if not seg.exists():
        print(f"downloading {args.start} +{args.dur}s @360p ...", flush=True)
        run([
            "yt-dlp", "--no-warnings", "--quiet",
            "--download-sections", f"*{start}-{end}",
            "-f", "best[height<=360]",
            # A 30-min section is one long read from googlevideo; without
            # reconnect, ffmpeg aborts mid-pull (exit 8) and the whole run dies.
            # ponytail: reconnect flags on the existing ffmpeg downloader, not a
            # chunked fetch - one connection is fine once it retries dropped reads.
            "--downloader", "ffmpeg",
            "--downloader-args",
            "ffmpeg:-reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 30",
            "--force-overwrites", "-o", str(seg), args.url,
        ])
    else:
        print("segment.mp4 present, skipping download", flush=True)

    # Audio for the tracker.
    run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y",
         "-i", str(seg), "-ac", "1", "-ar", "16000", str(wav)])
    print("transcribing audio -> chunks.json ...", flush=True)
    run([str(MAKE_FIXTURE), "--audio", str(wav), "--out", str(out / "chunks.json")])

    # One frame per hop, banner strip only.
    if frames.exists():
        for f in frames.glob("*.png"):
            f.unlink()
    frames.mkdir(exist_ok=True)
    run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", str(seg),
         "-vf", f"fps=1/{HOP},{BANNER_CROP}", str(frames / "f_%05d.png")])

    frame_files = sorted(frames.glob("f_*.png"))
    print(f"OCR-ing {len(frame_files)} banner frames ...", flush=True)
    banner: list[str] = []
    for i, f in enumerate(frame_files):
        res = subprocess.run(
            ["tesseract", str(f), "-", "-l", "pan", "--psm", "7"],
            capture_output=True, text=True,
        )
        banner.append(res.stdout.strip())
        if i % 100 == 0:
            print(f"  {i}/{len(frame_files)}", flush=True)

    (out / "banner.json").write_text(
        json.dumps(banner, ensure_ascii=False, indent=1) + "\n"
    )
    chunks = json.loads((out / "chunks.json").read_text())
    print(
        f"done: {len(chunks)} audio chunks, {len(banner)} banner frames "
        f"({sum(1 for b in banner if b)} non-empty) -> {out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
