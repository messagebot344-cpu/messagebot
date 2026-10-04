#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path

SEPARATOR_RE = re.compile(r"\n[ \t]*\n+")
PRINTED_NUMBER_RE = re.compile(r"^(\d{1,4})(?:[.)])?(?:\s*\n|\s{2,})")


@dataclass(frozen=True)
class DerivedParagraph:
    paragraph_key: str
    sermon_id: int
    edition_id: str
    passage_id: int
    global_ordinal: int
    start_offset: int
    end_offset: int
    source_page_start: int
    source_page_end: int
    text_sha256: str
    character_count: int
    printed_paragraph_number: str | None


def _trimmed_bounds(text: str, start: int, end: int) -> tuple[int, int]:
    while start < end and text[start].isspace():
        start += 1
    while end > start and text[end - 1].isspace():
        end -= 1
    return start, end


def paragraph_spans(text: str) -> list[tuple[int, int]]:
    if not text:
        return []
    spans: list[tuple[int, int]] = []
    cursor = 0
    for match in SEPARATOR_RE.finditer(text):
        start, end = _trimmed_bounds(text, cursor, match.start())
        if end > start:
            spans.append((start, end))
        cursor = match.end()
    start, end = _trimmed_bounds(text, cursor, len(text))
    if end > start:
        spans.append((start, end))
    if not spans:
        start, end = _trimmed_bounds(text, 0, len(text))
        if end > start:
            spans.append((start, end))
    return spans


def _paragraph_key(
    sermon_id: int,
    edition_id: str,
    passage_id: int,
    start: int,
    end: int,
    text_sha256: str,
) -> str:
    payload = (
        f"{sermon_id}|{edition_id}|{passage_id}|{start}|{end}|{text_sha256}"
    ).encode("utf-8")
    return "sp_" + hashlib.sha256(payload).hexdigest()[:32]


def derive_for_sermon(
    corpus: sqlite3.Connection,
    sermon_id: int,
) -> tuple[sqlite3.Row, list[DerivedParagraph]]:
    corpus.row_factory = sqlite3.Row
    sermon = corpus.execute(
        "SELECT id,code,title,year,primary_edition_id "
        "FROM sermons WHERE id=? LIMIT 1",
        (sermon_id,),
    ).fetchone()
    if sermon is None:
        raise ValueError(f"Unknown sermon_id={sermon_id}")

    edition_id = sermon["primary_edition_id"]
    rows = corpus.execute(
        "SELECT id,edition_id,sermon_id,ordinal,source_page_start,"
        "source_page_end,text_display "
        "FROM passages WHERE edition_id=? ORDER BY ordinal,id",
        (edition_id,),
    ).fetchall()
    if not rows:
        raise ValueError(
            f"No passages for primary edition {edition_id!r} "
            f"(sermon_id={sermon_id})"
        )

    result: list[DerivedParagraph] = []
    global_ordinal = 0
    for row in rows:
        text = row["text_display"]
        for start, end in paragraph_spans(text):
            exact = text[start:end]
            text_hash = hashlib.sha256(exact.encode("utf-8")).hexdigest()
            number_match = PRINTED_NUMBER_RE.match(exact)
            result.append(
                DerivedParagraph(
                    paragraph_key=_paragraph_key(
                        sermon_id,
                        row["edition_id"],
                        row["id"],
                        start,
                        end,
                        text_hash,
                    ),
                    sermon_id=sermon_id,
                    edition_id=row["edition_id"],
                    passage_id=row["id"],
                    global_ordinal=global_ordinal,
                    start_offset=start,
                    end_offset=end,
                    source_page_start=row["source_page_start"],
                    source_page_end=row["source_page_end"],
                    text_sha256=text_hash,
                    character_count=len(exact),
                    printed_paragraph_number=(
                        number_match.group(1) if number_match else None
                    ),
                )
            )
            global_ordinal += 1

    return sermon, result


def write_pack_foundation(
    study: sqlite3.Connection,
    corpus_meta: dict[str, str],
    sermon: sqlite3.Row,
    paragraphs: list[DerivedParagraph],
    *,
    pack_version: int,
) -> None:
    now = int(time.time() * 1000)
    study.execute(
        "INSERT INTO study_packs("
        "sermon_id,sermon_code,title,pack_version,pack_schema_version,"
        "corpus_version,corpus_canonical_sha256,primary_edition_id,"
        "bible_pack_version,status,validation_status,generated_at,published_at"
        ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?) "
        "ON CONFLICT(sermon_id,pack_version) DO UPDATE SET "
        "sermon_code=excluded.sermon_code,title=excluded.title,"
        "corpus_version=excluded.corpus_version,"
        "corpus_canonical_sha256=excluded.corpus_canonical_sha256,"
        "primary_edition_id=excluded.primary_edition_id,"
        "generated_at=excluded.generated_at",
        (
            sermon["id"],
            sermon["code"],
            sermon["title"],
            pack_version,
            1,
            corpus_meta["corpus_version"],
            corpus_meta["canonical_text_sha256"],
            sermon["primary_edition_id"],
            None,
            "draft",
            "needs_review",
            now,
            None,
        ),
    )
    study.execute(
        "DELETE FROM study_paragraphs WHERE sermon_id=? AND pack_version=?",
        (sermon["id"], pack_version),
    )
    study.executemany(
        "INSERT INTO study_paragraphs("
        "paragraph_key,sermon_id,pack_version,edition_id,passage_id,"
        "global_ordinal,start_offset,end_offset,source_page_start,"
        "source_page_end,text_sha256,character_count,printed_paragraph_number"
        ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [
            (
                p.paragraph_key,
                p.sermon_id,
                pack_version,
                p.edition_id,
                p.passage_id,
                p.global_ordinal,
                p.start_offset,
                p.end_offset,
                p.source_page_start,
                p.source_page_end,
                p.text_sha256,
                p.character_count,
                p.printed_paragraph_number,
            )
            for p in paragraphs
        ],
    )


def _load_meta(connection: sqlite3.Connection) -> dict[str, str]:
    return {
        key: value
        for key, value in connection.execute(
            "SELECT key,value FROM corpus_meta"
        )
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Dérive les paragraphes canoniques d'une prédication "
            "sans modifier corpus.db."
        )
    )
    parser.add_argument("corpus_db", type=Path)
    parser.add_argument("study_db", type=Path)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--sermon-id", type=int)
    group.add_argument("--sermon-code")
    parser.add_argument("--pack-version", type=int, default=1)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()

    corpus = sqlite3.connect(f"file:{args.corpus_db}?mode=ro", uri=True)
    corpus.row_factory = sqlite3.Row
    study = sqlite3.connect(args.study_db)
    try:
        if args.sermon_id is not None:
            sermon_id = args.sermon_id
        else:
            row = corpus.execute(
                "SELECT id FROM sermons WHERE code=? LIMIT 1",
                (args.sermon_code,),
            ).fetchone()
            if row is None:
                raise SystemExit(
                    f"Sermon code not found: {args.sermon_code}"
                )
            sermon_id = row["id"]

        meta = _load_meta(corpus)
        if "corpus_version" not in meta or "canonical_text_sha256" not in meta:
            raise SystemExit("Corpus V4 metadata is incomplete.")

        sermon, paragraphs = derive_for_sermon(corpus, sermon_id)
        with study:
            write_pack_foundation(
                study,
                meta,
                sermon,
                paragraphs,
                pack_version=args.pack_version,
            )

        total_chars = sum(p.character_count for p in paragraphs)
        payload = {
            "sermon_id": sermon["id"],
            "sermon_code": sermon["code"],
            "title": sermon["title"],
            "primary_edition_id": sermon["primary_edition_id"],
            "pack_version": args.pack_version,
            "paragraphs": len(paragraphs),
            "characters": total_chars,
            "first_paragraph_key": (
                paragraphs[0].paragraph_key if paragraphs else None
            ),
            "last_paragraph_key": (
                paragraphs[-1].paragraph_key if paragraphs else None
            ),
        }
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(
                json.dumps(payload, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    finally:
        study.close()
        corpus.close()


if __name__ == "__main__":
    main()
