#!/usr/bin/env python3
"""Add translations + transliterations to the bundled corpus from the v4 ShabadOS
database (GPL-3.0), keyed by line_id.

Line IDs are identical between our corpus and v4 (verified: 141,264/141,264
overlap), so this is a straight copy - no fuzzy matching. Bundles the STTM
default display set that v4 actually carries:

  translations     - English (Dr. Sant Singh Khalsa), Punjabi teeka (Prof. Sahib Singh)
  transliterations - Roman, Devnagri (the Hindi script)

v4 has no Hindi *translation* source, so "Hindi" here is the Devnagri
transliteration; a Hindi translation would need another source later. Adding more
sources is just more rows in the same two tables - the app reads them by
(lang) / (script), so the schema doesn't change.

Idempotent: drops and rebuilds both tables. Run after the base corpus exists.
Since v4 is GPL-3.0, the shipped app that bundles this data is GPL-3.0.

    tools/enrich_corpus.py --corpus assets/corpus/gurbani.sqlite \
        --v4 ../tmp/shabados-db/v4/package/build/database.sqlite
"""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

# (lang, human-readable source, v4 translation_source_id)
TRANSLATIONS = [
    ("en", "Dr. Sant Singh Khalsa", 1),
    ("pa", "Prof. Sahib Singh", 6),
]
# (script, v4 language_id)
TRANSLITERATIONS = [
    ("roman", 1),
    ("devnagri", 4),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True, type=Path)
    ap.add_argument("--v4", required=True, type=Path)
    args = ap.parse_args()

    db = sqlite3.connect(args.corpus)
    db.execute("ATTACH ? AS v4", (str(args.v4),))
    # Every table name is qualified `main.` on purpose. With v4 attached, an
    # UNqualified `DROP TABLE translations` resolves to whichever attached DB has
    # it first - and since our corpus has none, SQLite would drop v4's source
    # table. Qualify, and DDL can only ever touch our corpus.
    db.executescript("""
        DROP TABLE IF EXISTS main.translations;
        CREATE TABLE main.translations (
            line_id TEXT NOT NULL, lang TEXT NOT NULL,
            source TEXT NOT NULL, text TEXT NOT NULL);
        DROP TABLE IF EXISTS main.transliterations;
        CREATE TABLE main.transliterations (
            line_id TEXT NOT NULL, script TEXT NOT NULL, text TEXT NOT NULL);
    """)
    for lang, source, source_id in TRANSLATIONS:
        db.execute(
            "INSERT INTO main.translations (line_id, lang, source, text) "
            "SELECT line_id, ?, ?, translation FROM v4.translations "
            "WHERE translation_source_id = ?",
            (lang, source, source_id),
        )
    for script, language_id in TRANSLITERATIONS:
        db.execute(
            "INSERT INTO main.transliterations (line_id, script, text) "
            "SELECT line_id, ?, transliteration FROM v4.transliterations "
            "WHERE language_id = ?",
            (script, language_id),
        )
    # Small lookup tables (42 writers, ~60 sections) so search results can show
    # author + raag. `shabads` already carries writer_id / section_id; a section
    # is the raag (or bani division) for GGS.
    db.executescript("""
        DROP TABLE IF EXISTS main.writers;
        CREATE TABLE main.writers (
            id INTEGER PRIMARY KEY, name_gurmukhi TEXT, name_english TEXT);
        INSERT INTO main.writers
            SELECT id, name_gurmukhi, name_english FROM v4.writers;
        DROP TABLE IF EXISTS main.sections;
        CREATE TABLE main.sections (
            id INTEGER PRIMARY KEY, name_gurmukhi TEXT, name_english TEXT);
        INSERT INTO main.sections
            SELECT id, name_gurmukhi, name_english FROM v4.sections;
    """)
    db.executescript("""
        CREATE INDEX IF NOT EXISTS main.idx_translations_line
            ON translations(line_id);
        CREATE INDEX IF NOT EXISTS main.idx_transliterations_line
            ON transliterations(line_id);
        -- first-letter search: prefix ('sdvsd%') uses these; 'anywhere' scans.
        CREATE INDEX IF NOT EXISTS main.idx_lines_fl ON lines(first_letters);
        CREATE INDEX IF NOT EXISTS main.idx_lines_fl_uni
            ON lines(first_letters_uni);
    """)
    db.commit()
    for table in ("translations", "transliterations", "writers", "sections"):
        n = db.execute(f"SELECT count(*) FROM main.{table}").fetchone()[0]  # noqa: S608
        print(f"{table}: {n} rows")
    db.execute("DETACH v4")  # detach before VACUUM so it only touches our corpus
    db.execute("VACUUM")
    db.close()
    print(f"enriched {args.corpus}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
