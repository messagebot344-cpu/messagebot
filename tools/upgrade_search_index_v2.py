from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
from pathlib import Path

from corpus_pipeline.search_text import remove_editorial_search_noise

CANDIDATE_SQL = """
SELECT id,text_display FROM passages
WHERE text_display LIKE '%Shekinah%'
   OR text_display LIKE '%branham.fr%'
   OR text_display LIKE '%branham.ru%'
   OR text_display LIKE '%Veuillez trouver les autres prédications%'
   OR text_display LIKE '%Veuillez trouver les autres predications%'
   OR text_display LIKE '%La traduction de ce sermon%'
"""

EXCLUDE_SQL = """
NOT (
       text_display LIKE '%Shekinah%'
    OR text_display LIKE '%branham.fr%'
    OR text_display LIKE '%branham.ru%'
    OR text_display LIKE '%Veuillez trouver les autres prédications%'
    OR text_display LIKE '%Veuillez trouver les autres predications%'
    OR text_display LIKE '%La traduction de ce sermon%'
)
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Rebuild lexical FTS without known publisher/footer noise.")
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    args = parser.parse_args()

    source = args.source.resolve()
    target = args.target.resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        target.unlink()
    shutil.copy2(source, target)

    con = sqlite3.connect(target)
    con.execute("PRAGMA journal_mode=OFF")
    con.execute("PRAGMA synchronous=OFF")
    con.execute("PRAGMA temp_store=MEMORY")

    candidates = con.execute(CANDIDATE_SQL).fetchall()
    con.execute("DROP TABLE passages_fts")
    con.execute("CREATE VIRTUAL TABLE passages_fts USING fts5(text_search,content='',tokenize='unicode61 remove_diacritics 2')")

    # SQLite's unicode61 tokenizer performs lowercase/diacritic handling itself,
    # so untouched canonical text can be indexed directly in C without a costly
    # Python pass over the whole 130M-character corpus.
    con.execute(
        f"INSERT INTO passages_fts(rowid,text_search) SELECT id,text_display FROM passages WHERE {EXCLUDE_SQL}"
    )

    changed = 0
    empty = 0
    removed_chars = 0
    for passage_id, display_text in candidates:
        cleaned = remove_editorial_search_noise(display_text)
        if cleaned != display_text.strip():
            changed += 1
            removed_chars += max(0, len(display_text.strip()) - len(cleaned))
        if not cleaned.strip():
            empty += 1
        con.execute("INSERT INTO passages_fts(rowid,text_search) VALUES(?,?)", (passage_id, cleaned))

    total = con.execute("SELECT count(*) FROM passages").fetchone()[0]
    meta = {
        "schema_version": "2",
        "corpus_version": "2019.06-source / app-build-2026.09.20-v2",
        "search_filter_version": "editorial-footer-filter-v1",
        "search_filtered_passages": str(changed),
        "search_empty_passages": str(empty),
        "search_removed_chars": str(removed_chars),
    }
    for key, value in meta.items():
        con.execute(
            "INSERT INTO corpus_meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, value),
        )
    con.execute("INSERT INTO passages_fts(passages_fts) VALUES('optimize')")
    con.commit()
    con.execute("VACUUM")
    integrity = con.execute("PRAGMA integrity_check").fetchone()[0]
    fts_rows = con.execute("SELECT count(*) FROM passages_fts").fetchone()[0]
    con.close()

    result = {
        "status": "OK" if integrity == "ok" and fts_rows == total else "ERROR",
        "passages": total,
        "fts_rows": fts_rows,
        "candidate_passages": len(candidates),
        "filtered_passages": changed,
        "empty_after_filter": empty,
        "removed_characters_from_search_only": removed_chars,
        "sqlite_integrity": integrity,
        "target": str(target),
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
