#!/usr/bin/env python3
"""Cross-corpus concordance: our ShabadOS-based corpus vs the BaniDB text in
STTM's shipped realm. Two independently proofread digitizations agreeing is
the strongest automatic accuracy signal we have; every real disagreement is a
line for human adjudication against a physical saroop.

Inputs: the realm SGGS dump (tmp/sttm-desktop/dump_sggs.cjs writes it) and the
built corpus. Output: exact/slicing/true-delta counts and the adjudication
report (JSON, sorted by similarity so near-misses - single matras - lead).

    tools/concordance.py --realm /tmp/realm-sggs.json \
        --corpus assets/corpus/gurbani.sqlite \
        --out tools/data/concordance/sggs-true-deltas-<date>.json

Measured 2026-07-17 (shabados 4.8.7 vs realm evergreen-v2): 60,555 lines ->
98.97% exact, 453 slicing-only, 135 true text deltas (0.22%), mostly single
matras (e.g. ang 26 sqgur vs siqgur).
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sqlite3
from collections import defaultdict
from pathlib import Path

# Letters only: strip spaces, vishraams, dandas, verse digits, and the
# subscript footnote markers ShabadOS puts in sirlekh lines.
_STRIP = re.compile(r"[ ;,.।\]\[0-9¤@#$%*()_+=\-'\"`~/?!{}:₀-₉¹²³⁰-⁹]|\|\|")


def norm(s: str | None) -> str:
    return _STRIP.sub("", s or "")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--realm", required=True, type=Path)
    ap.add_argument("--corpus", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    realm = json.loads(args.realm.read_text())
    db = sqlite3.connect(args.corpus)
    ours = db.execute(
        "SELECT l.id, l.source_page, l.gurmukhi FROM lines l "
        "JOIN shabads sh ON sh.id = l.shabad_id WHERE sh.source_id = 1 "
        "ORDER BY l.order_id"
    ).fetchall()

    theirs_by_page: dict[int, set[str]] = defaultdict(set)
    for r in realm:
        theirs_by_page[r["p"]].add(norm(r["g"]))

    def on_pages(page: int) -> set[str]:
        s: set[str] = set()
        for p in (page - 1, page, page + 1):
            s |= theirs_by_page.get(p, set())
        return s

    lines = [(oid, page, norm(g)) for oid, page, g in ours]
    unmatched = [i for i, (_, page, n) in enumerate(lines) if n not in on_pages(page)]

    # A slicing artifact: our line joined with a neighbour equals a realm line
    # (the two ecosystems split long tuks differently - not a text error).
    slicing: set[int] = set()
    for i in unmatched:
        _, page, n = lines[i]
        cands = on_pages(page)
        for j in (i - 1, i + 1):
            if 0 <= j < len(lines):
                joined = lines[j][2] + n if j < i else n + lines[j][2]
                if joined in cands:
                    slicing.add(i)
                    break

    true_delta = [i for i in unmatched if i not in slicing]
    report = []
    for i in true_delta:
        oid, page, n = lines[i]
        best, score = "", 0.0
        for c in on_pages(page):
            s = difflib.SequenceMatcher(None, n, c).ratio()
            if s > score:
                best, score = c, s
        report.append(
            {"id": oid, "ang": page, "ours": n, "theirs": best, "sim": round(score, 3)}
        )
    report.sort(key=lambda r: -r["sim"])
    args.out.write_text(json.dumps(report, ensure_ascii=False, indent=1))

    total = len(lines)
    exact = total - len(unmatched)
    print(f"lines: {total}")
    print(f"exact (normalized, page±1): {exact} ({100 * exact / total:.2f}%)")
    print(f"slicing artifacts: {len(slicing)}")
    print(f"TRUE text deltas: {len(true_delta)} ({100 * len(true_delta) / total:.3f}%)")
    print(f"report -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
