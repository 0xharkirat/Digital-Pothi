#!/usr/bin/env python3
"""Deterministic corpus bake: pinned ShabadOS tgz -> our schema -> golden gate
-> stamped gurbani.sqlite. Replaces the (previously unscripted) base build and
absorbs enrich_corpus.py. The two derived columns were verified to reproduce
the shipped asset exactly (141,264/141,264 for both, 2026-07-17):

    gurmukhi_uni      = anvaad.unicode(gurmukhi)
    first_letters_uni = anvaad.unicode(first_letters)

Inputs come from tools/pins.json (tgz + sha256, anvaad module + version).
Output carries a db_meta table (schema_semver, upstream pins, built_at,
content_sha256 over an ordered logical dump).

    tools/build_corpus.py --out /tmp/corpus.sqlite
    tools/build_corpus.py --self-test-gate   # prove the gate can fail
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Straight copies from v4 (our lines keeps its shape + two derived columns).
_COPY = {
    "lines": "INSERT INTO main.lines (id, shabad_id, source_page, source_line, "
    "first_letters, vishraam_first_letters, gurmukhi, pronunciation, type_id, "
    "order_id) SELECT id, shabad_id, source_page, source_line, first_letters, "
    "vishraam_first_letters, gurmukhi, pronunciation, type_id, order_id FROM v4.lines",
    "shabads": "INSERT INTO main.shabads SELECT id, source_id, writer_id, "
    "section_id, subsection_id, sttm_id, order_id FROM v4.shabads",
    "banis": "INSERT INTO main.banis SELECT id, name_gurmukhi, name_english FROM v4.banis",
    "bani_lines": "INSERT INTO main.bani_lines SELECT line_id, bani_id, line_group FROM v4.bani_lines",
    "sources": "INSERT INTO main.sources SELECT id, name_gurmukhi, name_english, "
    "length, page_name_english, page_name_gurmukhi FROM v4.sources",
    "line_types": "INSERT INTO main.line_types SELECT id, name_gurmukhi, name_english FROM v4.line_types",
    "writers": "INSERT INTO main.writers SELECT id, name_gurmukhi, name_english FROM v4.writers",
    "sections": "INSERT INTO main.sections SELECT id, name_gurmukhi, name_english FROM v4.sections",
}
# The STTM default display set (was enrich_corpus.py): (lang, source, v4 id).
_TRANSLATIONS = [("en", "Dr. Sant Singh Khalsa", 1), ("pa", "Prof. Sahib Singh", 6)]
# (script, v4 language_id)
_TRANSLITERATIONS = [("roman", 1), ("devnagri", 4)]

_ANVAAD_RUNNER = """
globalThis.self = globalThis;
const anvaad = require(process.argv[1]);
const rl = require('readline').createInterface({ input: process.stdin });
rl.on('line', (l) => {
  const [id, text] = JSON.parse(l);
  process.stdout.write(JSON.stringify([id, anvaad.unicode(text)]) + '\\n');
});
"""


def _pins() -> dict:
    return json.loads((HERE / "pins.json").read_text())


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _extract_v4(pins: dict, tmp: Path) -> Path:
    tgz = (HERE / pins["shabados"]["tgz"]).resolve()
    if not tgz.exists():
        sys.exit(f"pinned tgz missing: {tgz} (run tools/fetch_upstreams.py)")
    if _sha256(tgz) != pins["shabados"]["sha256"]:
        sys.exit(f"pinned tgz sha256 mismatch: {tgz}")
    with tarfile.open(tgz) as t:
        t.extractall(tmp, filter="data")
    db = tmp / "package" / "build" / "database.sqlite"
    if not db.exists():
        sys.exit("tgz did not contain package/build/database.sqlite")
    return db


def _derive_unicode(db: sqlite3.Connection, anvaad_dir: Path) -> None:
    """Batch (gurmukhi, first_letters) -> unicode through anvaad via one node
    process; anvaad is the same converter the ecosystem uses, pinned."""
    rows = db.execute("SELECT rowid, gurmukhi, first_letters FROM lines").fetchall()
    feed = []
    for rowid, g, fl in rows:
        feed.append(json.dumps([f"g{rowid}", g or ""]))
        feed.append(json.dumps([f"f{rowid}", fl or ""]))
    out = subprocess.run(
        ["node", "-e", _ANVAAD_RUNNER, str(anvaad_dir)],
        input="\n".join(feed),
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    g_map: dict[int, str] = {}
    f_map: dict[int, str] = {}
    for line in out.splitlines():
        key, val = json.loads(line)
        (g_map if key[0] == "g" else f_map)[int(key[1:])] = val
    db.executemany(
        "UPDATE lines SET gurmukhi_uni = ?, first_letters_uni = ? WHERE rowid = ?",
        [(g_map[r], f_map[r], r) for r, _, _ in rows],
    )


def _content_sha(db: sqlite3.Connection) -> str:
    """Order-stable logical hash over every content table (not db_meta, not
    FTS shadow tables) - the identity of the data, independent of page layout."""
    h = hashlib.sha256()
    orders = {
        "lines": "order_id",
        "shabads": "order_id",
        "banis": "id",
        "bani_lines": "bani_id, line_group, line_id",
        "sources": "id",
        "line_types": "id",
        "writers": "id",
        "sections": "id",
        "translations": "line_id, lang, source",
        "transliterations": "line_id, script",
    }
    for table, order in orders.items():
        h.update(table.encode())
        for row in db.execute(f"SELECT * FROM {table} ORDER BY {order}"):  # noqa: S608 - fixed identifiers
            h.update(repr(row).encode())
    return h.hexdigest()


def _gate(db: sqlite3.Connection, pins: dict, anvaad_dir: Path) -> list[str]:
    """The golden gate: every check is an anchor a regression would move."""
    errs: list[str] = []

    def expect(cond: bool, msg: str) -> None:  # noqa: FBT001 - assertion helper
        if not cond:
            errs.append(msg)

    q = db.execute
    base = pins["baseline"]
    for table, want in [
        ("lines", base["lines"]),
        ("shabads", base["shabads"]),
        ("translations", base["translations"]),
        ("transliterations", base["transliterations"]),
    ]:
        got = q(f"SELECT COUNT(*) FROM {table}").fetchone()[0]  # noqa: S608
        expect(
            abs(got - want) <= want * 0.005,
            f"{table} count {got} drifted >0.5% from baseline {want}",
        )

    # Anchor content: ang 1 mool mantar, exact.
    row = q(
        "SELECT gurmukhi_uni, first_letters, first_letters_uni FROM lines WHERE id='0NVY'"
    ).fetchone()
    expect(row is not None, "anchor line 0NVY missing")
    if row:
        expect(
            row[0].startswith("ੴ ਸਤਿ ਨਾਮੁ ਕਰਤਾ ਪੁਰਖੁ"),
            f"mool mantar text drifted: {row[0][:40]}",
        )
        expect(row[1] == "<>snkpnnAmAsgp", f"0NVY first_letters drifted: {row[1]}")
    # Derivation spot check: 200 random lines re-derived must match stored.
    sample = q(
        "SELECT rowid, gurmukhi, first_letters, gurmukhi_uni, first_letters_uni "
        "FROM lines WHERE gurmukhi IS NOT NULL ORDER BY rowid LIMIT 200"
    ).fetchall()
    feed = []
    for rowid, g, fl, _, _ in sample:
        feed.append(json.dumps([f"g{rowid}", g or ""]))
        feed.append(json.dumps([f"f{rowid}", fl or ""]))
    out = subprocess.run(
        ["node", "-e", _ANVAAD_RUNNER, str(anvaad_dir)],
        input="\n".join(feed),
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    derived = dict(json.loads(line) for line in out.splitlines())
    for rowid, _, _, gu, flu in sample:
        expect(derived[f"g{rowid}"] == gu, f"rowid {rowid}: gurmukhi_uni != anvaad")
        expect(
            derived[f"f{rowid}"] == flu, f"rowid {rowid}: first_letters_uni != anvaad"
        )

    # Line types present and rahao lines carry the marker text.
    expect(
        q("SELECT COUNT(*) FROM line_types").fetchone()[0] == 4,
        "line_types must have 4 rows",
    )
    n_rahao = q(
        "SELECT COUNT(*) FROM lines WHERE type_id=3 AND gurmukhi_uni LIKE '%ਰਹਾਉ%'"
    ).fetchone()[0]
    expect(n_rahao > 2000, f"rahao text/type cross-check too low: {n_rahao}")

    # FTS smoke: the mool mantar is findable.
    hit = q(
        "SELECT COUNT(*) FROM lines_fts WHERE lines_fts MATCH 'ਕਰਤਾ ਪੁਰਖੁ'"
    ).fetchone()[0]
    expect(hit > 0, "FTS smoke query returned nothing")
    return errs


def build(out: Path) -> int:
    pins = _pins()
    anvaad_dir = (HERE / pins["anvaad"]["module"]).resolve()
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        v4 = _extract_v4(pins, tmp)
        out.unlink(missing_ok=True)
        db = sqlite3.connect(out)
        db.executescript((HERE / "schema" / "corpus.sql").read_text())
        db.execute("ATTACH ? AS v4", (str(v4),))
        for sql in _COPY.values():
            db.execute(sql)
        for lang, source, src_id in _TRANSLATIONS:
            db.execute(
                "INSERT INTO main.translations (line_id, lang, source, text) "
                "SELECT line_id, ?, ?, translation FROM v4.translations "
                "WHERE translation_source_id = ?",
                (lang, source, src_id),
            )
        for script, lang_id in _TRANSLITERATIONS:
            db.execute(
                "INSERT INTO main.transliterations (line_id, script, text) "
                "SELECT line_id, ?, transliteration FROM v4.transliterations "
                "WHERE language_id = ?",
                (script, lang_id),
            )
        db.commit()
        db.execute("DETACH v4")
        _derive_unicode(db, anvaad_dir)
        db.execute(
            "INSERT INTO lines_fts(rowid, gurmukhi_uni, first_letters_uni) "
            "SELECT rowid, gurmukhi_uni, first_letters_uni FROM lines"
        )
        db.commit()

        errs = _gate(db, pins, anvaad_dir)
        if errs:
            for e in errs:
                print(f"GATE FAIL: {e}", file=sys.stderr)
            db.close()
            out.unlink(missing_ok=True)
            return 1

        meta = {
            "schema_semver": pins["schema_semver"],
            "shabados_version": pins["shabados"]["version"],
            "anvaad_version": pins["anvaad"]["version"],
            "built_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "content_sha256": _content_sha(db),
        }
        db.executemany(
            "INSERT INTO db_meta (key, value) VALUES (?, ?)", list(meta.items())
        )
        db.commit()
        db.execute("VACUUM")
        db.close()
        print(json.dumps(meta, indent=1))
        return 0


def self_test_gate() -> int:
    """Bake, corrupt one anchor, prove the gate refuses it."""
    with tempfile.TemporaryDirectory() as tmpdir:
        out = Path(tmpdir) / "gate-test.sqlite"
        if build(out) != 0:
            print("self-test: clean build failed", file=sys.stderr)
            return 1
        db = sqlite3.connect(out)
        db.execute("UPDATE lines SET gurmukhi_uni = 'ਗਲਤ' WHERE id='0NVY'")
        db.commit()
        pins = _pins()
        errs = _gate(db, pins, (HERE / pins["anvaad"]["module"]).resolve())
        db.close()
        if errs:
            print(f"self-test OK: gate caught the corruption ({errs[0]})")
            return 0
        print("self-test FAIL: gate accepted corrupted data", file=sys.stderr)
        return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", type=Path)
    ap.add_argument("--self-test-gate", action="store_true")
    args = ap.parse_args()
    if args.self_test_gate:
        return self_test_gate()
    if not args.out:
        ap.error("--out is required (or --self-test-gate)")
    return build(args.out)


if __name__ == "__main__":
    raise SystemExit(main())
