#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from pathlib import Path

from derive_paragraphs import derive_for_sermon
from select_prototype_sermons import SCRIPTURE_RE


def _reference_occurrences(
    paragraph_text: str,
    *,
    paragraph_start_in_passage: int,
) -> list[dict]:
    values: list[dict] = []
    for match in SCRIPTURE_RE.finditer(paragraph_text):
        values.append(
            {
                "display_reference": match.group(0),
                "paragraph_start_offset": match.start(),
                "paragraph_end_offset": match.end(),
                "passage_start_offset": (
                    paragraph_start_in_passage + match.start()
                ),
                "passage_end_offset": (
                    paragraph_start_in_passage + match.end()
                ),
            }
        )
    return values


def export_sermon(
    corpus: sqlite3.Connection,
    sermon_id: int,
) -> dict:
    corpus.row_factory = sqlite3.Row
    sermon, paragraphs = derive_for_sermon(corpus, sermon_id)
    passages = corpus.execute(
        "SELECT id,edition_id,sermon_id,ordinal,source_page_start,"
        "source_page_end,text_display "
        "FROM passages WHERE edition_id=? ORDER BY ordinal,id",
        (sermon["primary_edition_id"],),
    ).fetchall()
    passage_text_by_id = {
        row["id"]: row["text_display"] for row in passages
    }

    paragraph_payload = []
    explicit_refs: list[dict] = []
    for paragraph in paragraphs:
        passage_text = passage_text_by_id[paragraph.passage_id]
        exact = passage_text[
            paragraph.start_offset : paragraph.end_offset
        ]
        references = _reference_occurrences(
            exact,
            paragraph_start_in_passage=paragraph.start_offset,
        )
        for reference in references:
            explicit_refs.append(
                {
                    "paragraph_key": paragraph.paragraph_key,
                    "passage_id": paragraph.passage_id,
                    **reference,
                }
            )
        paragraph_payload.append(
            {
                "paragraph_key": paragraph.paragraph_key,
                "sermon_id": paragraph.sermon_id,
                "edition_id": paragraph.edition_id,
                "passage_id": paragraph.passage_id,
                "global_ordinal": paragraph.global_ordinal,
                "start_offset": paragraph.start_offset,
                "end_offset": paragraph.end_offset,
                "source_page_start": paragraph.source_page_start,
                "source_page_end": paragraph.source_page_end,
                "text_sha256": paragraph.text_sha256,
                "character_count": paragraph.character_count,
                "printed_paragraph_number": (
                    paragraph.printed_paragraph_number
                ),
                "exact_text": exact,
                "scripture_references": references,
            }
        )

    unique_references = sorted(
        {
            re.sub(
                r"\s+",
                " ",
                value["display_reference"].strip().lower(),
            )
            for value in explicit_refs
        }
    )

    return {
        "sermon": {
            "id": sermon["id"],
            "code": sermon["code"],
            "title": sermon["title"],
            "year": sermon["year"],
            "primary_edition_id": sermon["primary_edition_id"],
        },
        "passages": [
            {
                "id": row["id"],
                "edition_id": row["edition_id"],
                "ordinal": row["ordinal"],
                "source_page_start": row["source_page_start"],
                "source_page_end": row["source_page_end"],
                "exact_text": row["text_display"],
            }
            for row in passages
        ],
        "paragraphs": paragraph_payload,
        "explicit_scripture_references": explicit_refs,
        "unique_explicit_scripture_references": unique_references,
        "stats": {
            "passages": len(passages),
            "paragraphs": len(paragraph_payload),
            "characters": sum(
                item["character_count"]
                for item in paragraph_payload
            ),
            "scripture_reference_mentions": len(explicit_refs),
            "unique_scripture_references": len(unique_references),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus_db", type=Path)
    parser.add_argument(
        "--selection",
        type=Path,
        default=Path("reports/study_prototype_selection.json"),
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    selection = json.loads(
        args.selection.read_text(encoding="utf-8")
    )
    prototypes = selection["unique_prototypes"]
    sermon_ids = [int(item["sermon_id"]) for item in prototypes]

    corpus = sqlite3.connect(
        f"file:{args.corpus_db}?mode=ro",
        uri=True,
    )
    corpus.row_factory = sqlite3.Row
    try:
        meta = {
            key: value
            for key, value in corpus.execute(
                "SELECT key,value FROM corpus_meta"
            )
        }
        sermons = [
            export_sermon(corpus, sermon_id)
            for sermon_id in sermon_ids
        ]
    finally:
        corpus.close()

    output = {
        "artifact_kind": "development_source_export",
        "runtime_shipping": False,
        "warning": (
            "Exact canonical text for prototype authoring only. "
            "Published Study Packs must reference corpus offsets/hashes "
            "instead of duplicating canonical sermon text."
        ),
        "corpus_version": meta.get("corpus_version"),
        "corpus_canonical_sha256": meta.get(
            "canonical_text_sha256"
        ),
        "prototype_count": len(sermons),
        "sermons": sermons,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(
        json.dumps(
            {
                "prototype_count": len(sermons),
                "sermons": [
                    {
                        "id": item["sermon"]["id"],
                        "code": item["sermon"]["code"],
                        "title": item["sermon"]["title"],
                        **item["stats"],
                    }
                    for item in sermons
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
