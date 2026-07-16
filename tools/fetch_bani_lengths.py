#!/usr/bin/env python3
"""Build a self-contained Sundar Gutka database with per-line bani lengths.

STTM's bani-length feature (short / medium / long / extra long) relies on
per-line flags that are NOT in the open ShabadOS SQLite - only in STTM's curated
Realm build. The BaniDB API exposes the same data as JSON, per verse:
  existsSGPC, existsMedium, existsTaksal, existsBuddhaDal
mapping to STTM's short / medium / long / extralong respectively (verified
against the STTM source: www/main/viewer/ShabadDeck/ShabadDeck.jsx).

This fetches every needed bani once (build-time only; the app stays fully local
at runtime) and bakes a self-contained `sundar_gutka.sqlite` - each verse carries
its own Gurmukhi + transliteration + translation, so no fragile cross-DB line-id
mapping is needed.

Most banis come from BaniDB. A few aren't BaniDB banis (e.g. Anand Sahib Bhog =
Anand's 6 pauris + the closing salok) but ARE in the bundled ShabadOS corpus, so
they're bridged from there with --corpus. Run:

    ./tools/fetch_bani_lengths.py --out assets/corpus/sundar_gutka.sqlite \
        --corpus assets/corpus/gurbani.sqlite
"""
import argparse
import json
import sqlite3
import time
import urllib.request

API = 'https://api.banidb.com/v2'

# STTM length name -> BaniDB per-verse flag (from the STTM source).
LENGTHS = {
    'short': 'existsSGPC',
    'medium': 'existsMedium',
    'long': 'existsTaksal',
    'extralong': 'existsBuddhaDal',
}

# STTM groups its Sundar Gutka list: Nitnem banis + Popular banis get shown as
# cards, the rest fill out the full list (BaniDB has ~90). These id lists are
# STTM's (www/main/common/constants/index.js).
NITNEM = [2, 4, 6, 9, 10, 21, 23]  # id 20 in STTM is a phantom; dropped
POPULAR = [90, 30, 31, 22]

# Clean English names for the common banis; the rest fall back to the BaniDB
# transliteration, which reads as an English name well enough.
ENGLISH = {
    2: 'Japji Sahib', 4: 'Jaap Sahib', 6: 'Tav Prasad Savaiye',
    9: 'Benti Chaupai Sahib', 10: 'Anand Sahib', 21: 'Rehras Sahib',
    23: 'Sohila Sahib', 3: 'Shabad Hazare', 5: 'Shabad Hazare Patshahi 10',
    30: 'Salok Mahalla 9', 31: 'Sukhmani Sahib', 90: 'Asa Ki Var',
    22: 'Aarti', 11: 'Lavan (Anand Karaj)',
}

# Banis bridged from the ShabadOS corpus (BaniDB doesn't carry them as banis),
# placed after a given BaniDB id. `kind` selects how the corpus text is arranged
# (see corpus_rows); each gets a stable sg id.
#   after_bdb_id: [(kind, gurmukhi_name, english_name, group), ...]
CORPUS_AFTER = {
    10: [
        ('anand_bhog', 'ਅਨੰਦੁ ਸਾਹਿਬ (ਭੋਗ)', 'Anand Sahib Bhog', 'nitnem'),
        ('salok', 'ਸਲੋਕੁ (ਪਵਣੁ ਗੁਰੂ)', 'Salok (Pavan Guru)', 'nitnem'),
    ],
}
CORPUS_SG_ID = {'anand_bhog': 1006, 'salok': 1007}


def build_order(all_ids):
    """Ordered [(kind, ...)] entries: Nitnem, then Popular, then the rest by id."""
    order = []
    seen = set()

    def add_bdb(bid, group):
        if bid in all_ids and bid not in seen:
            order.append(('bdb', bid, group))
            seen.add(bid)
            for kind, gur, eng, grp in CORPUS_AFTER.get(bid, []):
                order.append(('corpus', kind, gur, eng, grp))

    for bid in NITNEM:
        add_bdb(bid, 'nitnem')
    for bid in POPULAR:
        add_bdb(bid, 'popular')
    for bid in sorted(all_ids):
        add_bdb(bid, 'other')
    return order


def get(url):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(url, timeout=40) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001 - build script, just retry
            if attempt == 3:
                raise
            print(f'  retry {url}: {e}')
            time.sleep(2)


def dig(obj, *path, default=None):
    for key in path:
        if not isinstance(obj, dict) or key not in obj:
            return default
        obj = obj[key]
    return obj if isinstance(obj, str) else default


def bdb_rows(banis, bid, sg_id):
    """(has_lengths, rows) for a BaniDB bani."""
    data = get(f'{API}/banis/{bid}')
    verses = data.get('verses', [])
    counts = {k: 0 for k in LENGTHS}
    rows = []
    for seq, v in enumerate(verses):
        vv = v.get('verse', {})
        flags = {name: 1 if v.get(flag) else 0 for name, flag in LENGTHS.items()}
        for name in LENGTHS:
            counts[name] += flags[name]
        rows.append((
            sg_id, seq,
            dig(vv, 'verse', 'unicode', default=''),
            dig(vv, 'transliteration', 'en', default=''),
            dig(vv, 'translation', 'en', 'bdb', default=''),
            dig(vv, 'translation', 'pu', 'ss', 'unicode', default=''),
            (vv.get('pageNo') if isinstance(vv.get('pageNo'), int) else 0),
            1 if v.get('header') else 0,
            flags['short'], flags['medium'], flags['long'], flags['extralong'],
        ))
    has_lengths = 1 if len(set(counts.values())) > 1 else 0
    return has_lengths, rows, counts, banis.get(bid, {})


def _bani6_lines(corpus):
    """The 'Anand Sahib (6 Pauris and Salok)' bani, as (id, gurmukhi, page,
    order_id) sorted by SGGS order."""
    return corpus.cursor().execute(
        'SELECT l.id, l.gurmukhi_uni, l.source_page, l.order_id FROM lines l '
        'JOIN bani_lines bl ON bl.line_id = l.id WHERE bl.bani_id = 6 '
        'ORDER BY l.order_id',
    ).fetchall()


def _split_salok(lines):
    """Split bani 6 into (salok, pauris). Japji's closing salok sits early in the
    SGGS (small order_id); the Anand pauris are in Raag Ramkali (much larger), so
    the boundary is the one big order_id jump."""
    split = next(
        (i for i in range(1, len(lines)) if lines[i][3] - lines[i - 1][3] > 1000),
        0,
    )
    return lines[:split], lines[split:]


def corpus_rows(corpus, kind, sg_id):
    """Rows for a corpus-bridged bani. `anand_bhog` reads the 6 pauris and *then*
    the closing salok (the SGGS order puts the salok first, which is wrong for the
    bhog); `salok` is just that salok on its own."""
    salok, pauris = _split_salok(_bani6_lines(corpus))
    picked = {'anand_bhog': pauris + salok, 'salok': salok}[kind]
    c = corpus.cursor()
    rows = []
    for seq, (lid, g, page, _) in enumerate(picked):
        en = c.execute(
            "SELECT text FROM translations WHERE line_id=? AND lang='en'", (lid,)
        ).fetchone()
        pa = c.execute(
            "SELECT text FROM translations WHERE line_id=? AND lang='pa'", (lid,)
        ).fetchone()
        rom = c.execute(
            "SELECT text FROM transliterations WHERE line_id=? AND script='roman'",
            (lid,),
        ).fetchone()
        rows.append((
            sg_id, seq, g, rom[0] if rom else '', en[0] if en else '',
            pa[0] if pa else '', page or 0, 0, 1, 1, 1, 1,
        ))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--corpus', help='ShabadOS corpus, for bridged banis')
    args = ap.parse_args()

    banis = {b['ID']: b for b in get(f'{API}/banis')}
    corpus = sqlite3.connect(args.corpus) if args.corpus else None
    order = build_order(set(banis))
    print(f'{len(banis)} BaniDB banis; building {len(order)}')

    db = sqlite3.connect(args.out)
    db.executescript(
        'DROP TABLE IF EXISTS sg_banis;'
        'DROP TABLE IF EXISTS sg_lines;'
        'CREATE TABLE sg_banis (id INTEGER PRIMARY KEY, ord INTEGER, '
        "  grp TEXT, gurmukhi TEXT, roman TEXT, english TEXT, has_lengths INTEGER);"
        'CREATE TABLE sg_lines (bani_id INTEGER, seq INTEGER, gurmukhi TEXT, '
        '  roman TEXT, english TEXT, punjabi TEXT, page INTEGER, is_header INTEGER, '
        '  len_short INTEGER, len_medium INTEGER, len_long INTEGER, '
        '  len_extralong INTEGER);'
        'CREATE INDEX sg_lines_bani ON sg_lines(bani_id, seq);'
    )

    for ordinal, entry in enumerate(order):
        if entry[0] == 'bdb':
            _, bid, group = entry
            has_lengths, rows, counts, meta = bdb_rows(banis, bid, bid)
            gurmukhi = meta.get('gurmukhiUni', '')
            roman = meta.get('transliteration', '')
            english = ENGLISH.get(bid, roman)
            sg_id = bid
            note = f' {counts}' if has_lengths else ''
        else:
            _, kind, gurmukhi, english, group = entry
            if corpus is None:
                print(f'  !! skip {english}: --corpus not given')
                continue
            sg_id = CORPUS_SG_ID[kind]
            rows = corpus_rows(corpus, kind, sg_id)
            roman, has_lengths, note = '', 0, ' [corpus]'
        db.execute(
            'INSERT INTO sg_banis VALUES (?,?,?,?,?,?,?)',
            (sg_id, ordinal, group, gurmukhi, roman, english, has_lengths),
        )
        db.executemany(
            'INSERT INTO sg_lines VALUES (?,?,?,?,?,?,?,?,?,?,?,?)', rows
        )
        print(f'  {ordinal:>2} {group:<8} {english:<28} {len(rows):>4}{note}')

    db.commit()
    db.execute('VACUUM')
    db.close()
    print(f'wrote {args.out}')


if __name__ == '__main__':
    main()
