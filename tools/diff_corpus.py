#!/usr/bin/env python3
"""Upgrade gate: diff two corpus bakes and report what an upstream bump
actually changed - BEFORE it ships. Id removal is the red flag (saved
history/favorites reference line ids); text changes are listed for review.

    tools/diff_corpus.py old.sqlite new.sqlite [--out report.md]

Exit 0 = no id removals; exit 2 = ids were removed (review required).
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path


def _lines(path: Path) -> dict[str, tuple]:
    db = sqlite3.connect(path)
    rows = db.execute(
        "SELECT id, gurmukhi_uni, source_page, order_id, type_id FROM lines"
    ).fetchall()
    db.close()
    return {r[0]: r[1:] for r in rows}


def _counts(path: Path) -> dict[str, int]:
    db = sqlite3.connect(path)
    out = {}
    for t in (
        "lines",
        "shabads",
        "translations",
        "transliterations",
        "writers",
        "sections",
        "sources",
    ):
        out[t] = db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]  # noqa: S608
    db.close()
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("old", type=Path)
    ap.add_argument("new", type=Path)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--max-listed", type=int, default=200)
    args = ap.parse_args()

    old, new = _lines(args.old), _lines(args.new)
    removed = sorted(set(old) - set(new))
    added = sorted(set(new) - set(old))
    text_changed = [
        (i, old[i][0], new[i][0]) for i in old.keys() & new.keys() if old[i][0] != new[i][0]
    ]
    moved = [
        i
        for i in old.keys() & new.keys()
        if old[i][1:] != new[i][1:] and old[i][0] == new[i][0]
    ]
    oc, nc = _counts(args.old), _counts(args.new)

    r: list[str] = ["# Corpus diff", ""]
    r.append(f"`{args.old.name}` -> `{args.new.name}`")
    r.append("")
    r.append("| table | old | new | delta |")
    r.append("|---|---|---|---|")
    for t in oc:
        r.append(f"| {t} | {oc[t]} | {nc[t]} | {nc[t] - oc[t]:+d} |")
    r.append("")
    r.append(f"## Line ids: {len(removed)} removed · {len(added)} added")
    r.append("")
    if removed:
        r.append("**REMOVED ids (saved user data may reference these):**")
        r.extend(f"- `{i}` {old[i][0][:60]}" for i in removed[: args.max_listed])
        r.append("")
    if added:
        r.extend(f"- added `{i}` {new[i][0][:60]}" for i in added[: args.max_listed])
        r.append("")
    r.append(f"## Text changed on {len(text_changed)} lines")
    r.append("")
    for i, o, n in text_changed[: args.max_listed]:
        r.append(f"- `{i}`")
        r.append(f"  - old: {o}")
        r.append(f"  - new: {n}")
    r.append("")
    r.append(f"## Metadata moved (page/order/type) on {len(moved)} unchanged-text lines")
    report = "\n".join(r)
    if args.out:
        args.out.write_text(report)
        print(f"report -> {args.out}")
    else:
        print(report)
    if removed:
        print(f"\nRED FLAG: {len(removed)} ids removed", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
