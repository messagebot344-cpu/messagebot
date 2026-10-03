from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from pathlib import Path

TARGET_CHARS = 3600
MAX_CHARS = 4800
MIN_CHARS = 1800
SPACE_RE = re.compile(r"\s+")
SENTENCE_BREAK = re.compile(r"(?<=[.!?…])\s+(?=[A-ZÀ-ÖØ-Þ0-9«“])")


try:
    from search_text import clean_controls, prepare_search_text
except ImportError:  # pragma: no cover - module execution
    from .search_text import clean_controls, prepare_search_text

def page_blocks(page_text: str) -> list[str]:
    page_text = clean_controls(page_text).strip()
    if not page_text:
        return []
    blocks = [block.strip() for block in re.split(r"\n\s*\n", page_text) if block.strip()]
    result: list[str] = []
    for block in blocks:
        if len(block) <= MAX_CHARS:
            result.append(block)
            continue
        sentences = SENTENCE_BREAK.split(SPACE_RE.sub(" ", block).strip())
        current = ""
        for sentence in sentences:
            if not sentence:
                continue
            if current and len(current) + 1 + len(sentence) > MAX_CHARS:
                result.append(current)
                current = sentence
            else:
                current = (current + " " + sentence).strip()
        if current:
            result.append(current)
    return result


def make_passages(pages: list[str], first_page: int) -> list[tuple[int, int, str]]:
    passages: list[tuple[int, int, str]] = []
    current: list[str] = []
    current_length = 0
    start_page: int | None = None
    end_page: int | None = None

    def flush() -> None:
        nonlocal current, current_length, start_page, end_page
        if current and start_page is not None and end_page is not None:
            passages.append((start_page, end_page, "\n\n".join(current).strip()))
        current = []
        current_length = 0
        start_page = None
        end_page = None

    for index, page_text in enumerate(pages):
        page_number = first_page + index
        for block in page_blocks(page_text):
            if start_page is None:
                start_page = page_number
            if current and current_length >= MIN_CHARS and current_length + 2 + len(block) > MAX_CHARS:
                flush()
                start_page = page_number
            current.append(block)
            current_length += len(block) + 2
            end_page = page_number
            if current_length >= TARGET_CHARS:
                flush()
    flush()
    return passages


def main() -> None:
    parser = argparse.ArgumentParser(description="Construit corpus.db et son index lexical FTS5.")
    parser.add_argument("work", type=Path, help="Répertoire produit par extract_corpus.py")
    parser.add_argument("database", type=Path)
    args = parser.parse_args()

    reports = args.work / "reports"
    raw_dir = args.work / "sermons_raw"
    editions = json.loads((reports / "editions.json").read_text(encoding="utf-8"))
    sermons = json.loads((reports / "sermons.json").read_text(encoding="utf-8"))

    db_path = args.database.resolve()
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    connection = sqlite3.connect(db_path)
    connection.execute("PRAGMA journal_mode=OFF")
    connection.execute("PRAGMA synchronous=OFF")
    connection.execute("PRAGMA temp_store=MEMORY")
    connection.execute("PRAGMA page_size=4096")
    connection.executescript(
        """
CREATE TABLE corpus_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE sermons(
 id INTEGER PRIMARY KEY,code TEXT NOT NULL UNIQUE,title TEXT NOT NULL,
 year INTEGER,edition_count INTEGER NOT NULL,primary_edition_id TEXT NOT NULL
);
CREATE TABLE editions(
 id TEXT PRIMARY KEY,sermon_id INTEGER NOT NULL,title TEXT NOT NULL,
 bookmark_title TEXT NOT NULL,is_primary INTEGER NOT NULL,is_frn INTEGER NOT NULL,
 source_page_start INTEGER NOT NULL,source_page_end INTEGER NOT NULL,
 sha256 TEXT NOT NULL,char_count INTEGER NOT NULL
);
CREATE INDEX idx_editions_sermon ON editions(sermon_id);
CREATE TABLE passages(
 id INTEGER PRIMARY KEY,edition_id TEXT NOT NULL,sermon_id INTEGER NOT NULL,
 ordinal INTEGER NOT NULL,source_page_start INTEGER NOT NULL,source_page_end INTEGER NOT NULL,
 text_display TEXT NOT NULL
);
CREATE INDEX idx_passages_edition_ord ON passages(edition_id,ordinal);
CREATE INDEX idx_passages_sermon ON passages(sermon_id);
CREATE VIRTUAL TABLE passages_fts USING fts5(
 text_search,content='',tokenize='unicode61 remove_diacritics 2'
);
"""
    )

    sermon_id_by_code: dict[str, int] = {}
    for identifier, sermon in enumerate(sorted(sermons, key=lambda item: item["sermon_code"]), 1):
        year = 1900 + int(sermon["sermon_code"][:2])
        connection.execute(
            "INSERT INTO sermons(id,code,title,year,edition_count,primary_edition_id) VALUES(?,?,?,?,?,?)",
            (
                identifier,
                sermon["sermon_code"],
                sermon["title"],
                year,
                sermon["edition_count"],
                sermon["primary_edition_id"],
            ),
        )
        sermon_id_by_code[sermon["sermon_code"]] = identifier

    passage_count = 0
    primary_passages = 0
    for edition_index, edition in enumerate(editions, 1):
        sermon_id = sermon_id_by_code[edition["sermon_code"]]
        connection.execute(
            "INSERT INTO editions(id,sermon_id,title,bookmark_title,is_primary,is_frn,source_page_start,source_page_end,sha256,char_count) VALUES(?,?,?,?,?,?,?,?,?,?)",
            (
                edition["edition_id"],
                sermon_id,
                edition["title"],
                edition["bookmark_title"],
                1 if edition["is_primary"] else 0,
                1 if edition["is_frn"] else 0,
                edition["source_page_start"],
                edition["source_page_end"],
                edition["sha256"],
                edition["chars"],
            ),
        )
        text = (raw_dir / edition["raw_file"]).read_text(encoding="utf-8", errors="replace")
        pages = text.split("\n\f\n")
        expected_pages = edition["source_page_end"] - edition["source_page_start"] + 1
        if len(pages) != expected_pages:
            raise RuntimeError(
                f"Nombre de pages incohérent pour {edition['edition_id']}: {len(pages)} != {expected_pages}"
            )

        for ordinal, (page_start, page_end, display_text) in enumerate(
            make_passages(pages, edition["source_page_start"])
        ):
            search_text = prepare_search_text(display_text)
            if not search_text:
                continue
            cursor = connection.execute(
                "INSERT INTO passages(edition_id,sermon_id,ordinal,source_page_start,source_page_end,text_display) VALUES(?,?,?,?,?,?)",
                (
                    edition["edition_id"],
                    sermon_id,
                    ordinal,
                    page_start,
                    page_end,
                    display_text,
                ),
            )
            passage_id = cursor.lastrowid
            connection.execute(
                "INSERT INTO passages_fts(rowid,text_search) VALUES(?,?)",
                (passage_id, search_text),
            )
            passage_count += 1
            if edition["is_primary"]:
                primary_passages += 1

        if edition_index % 100 == 0:
            connection.commit()
            print(f"{edition_index}/{len(editions)} éditions ; {passage_count} passages", flush=True)

    inventory = json.loads((reports / "inventory.json").read_text(encoding="utf-8"))
    meta = {
        "schema_version": "2",
        "corpus_version": "2019.06-source / app-build-2026.09.20-v2",
        "search_filter_version": "editorial-footer-filter-v1",
        "sermon_count": str(len(sermons)),
        "edition_count": str(len(editions)),
        "passage_count": str(passage_count),
        "primary_passage_count": str(primary_passages),
        "source_pdf_pages": str(inventory["pdf_pages"]),
        "segmentation_target_chars": str(TARGET_CHARS),
        "segmentation_max_chars": str(MAX_CHARS),
    }
    connection.executemany("INSERT INTO corpus_meta(key,value) VALUES(?,?)", meta.items())
    connection.commit()
    connection.execute("VACUUM")
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    fts_rows = connection.execute("SELECT count(*) FROM passages_fts").fetchone()[0]
    connection.close()

    report = {
        "database": db_path.name,
        "bytes": db_path.stat().st_size,
        "sha256": hashlib.sha256(db_path.read_bytes()).hexdigest(),
        "sermons": len(sermons),
        "editions": len(editions),
        "passages": passage_count,
        "primary_passages": primary_passages,
        "fts_rows": fts_rows,
        "integrity_check": integrity,
    }
    (reports / "database_build.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
