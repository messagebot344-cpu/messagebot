#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from create_study_pack_db import create_database
from derive_paragraphs import derive_for_sermon, paragraph_spans, write_pack_foundation


class StudyPipelineFoundationTest(unittest.TestCase):
    def test_paragraph_spans_preserve_exact_canonical_substrings(self) -> None:
        text = "  Premier paragraphe.  \n\n2\nDeuxième paragraphe.\n\n\nTroisième.  "
        spans = paragraph_spans(text)
        values = [text[start:end] for start, end in spans]
        self.assertEqual(
            values,
            [
                "Premier paragraphe.",
                "2\nDeuxième paragraphe.",
                "Troisième.",
            ],
        )
        for (start, end), value in zip(spans, values):
            self.assertEqual(text[start:end], value)

    def test_derivation_is_generic_and_bound_to_corpus_metadata(self) -> None:
        with tempfile.TemporaryDirectory(prefix="grenier-study-pipeline-") as tmp:
            root = Path(tmp)
            corpus_path = root / "corpus.db"
            study_path = root / "study_packs.db"
            schema_path = HERE / "study_pack_schema.sql"

            corpus = sqlite3.connect(corpus_path)
            corpus.executescript(
                """
                CREATE TABLE corpus_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL);
                CREATE TABLE sermons(
                  id INTEGER PRIMARY KEY,
                  code TEXT NOT NULL,
                  title TEXT NOT NULL,
                  year INTEGER,
                  edition_count INTEGER NOT NULL,
                  primary_edition_id TEXT NOT NULL
                );
                CREATE TABLE passages(
                  id INTEGER PRIMARY KEY,
                  edition_id TEXT NOT NULL,
                  sermon_id INTEGER NOT NULL,
                  ordinal INTEGER NOT NULL,
                  source_page_start INTEGER NOT NULL,
                  source_page_end INTEGER NOT NULL,
                  text_display TEXT NOT NULL
                );
                """
            )
            corpus.executemany(
                "INSERT INTO corpus_meta(key,value) VALUES(?,?)",
                [
                    ("corpus_version", "fixture-v4"),
                    ("canonical_text_sha256", "fixture-canonical-sha"),
                ],
            )
            corpus.execute(
                "INSERT INTO sermons VALUES(1,'47-0412','La Foi Est l''Assurance',1947,1,'e1')"
            )
            first = "1\nOn apprête de nouveaux appareils.\n\nLa foi est une ferme assurance."
            second = "Un autre paragraphe.\n\n4\nConclusion."
            corpus.executemany(
                "INSERT INTO passages VALUES(?,?,?,?,?,?,?)",
                [
                    (10, "e1", 1, 0, 3, 3, first),
                    (11, "e1", 1, 1, 4, 4, second),
                ],
            )
            corpus.commit()

            create_database(
                study_path,
                schema_path,
                corpus_version="fixture-v4",
                corpus_canonical_sha256="fixture-canonical-sha",
                packset_version="prototype-test",
            )

            corpus.row_factory = sqlite3.Row
            sermon, paragraphs = derive_for_sermon(corpus, 1)
            self.assertEqual(4, len(paragraphs))
            self.assertEqual([0, 1, 2, 3], [p.global_ordinal for p in paragraphs])
            self.assertEqual("1", paragraphs[0].printed_paragraph_number)
            self.assertEqual("4", paragraphs[-1].printed_paragraph_number)

            for p in paragraphs:
                source = corpus.execute(
                    "SELECT text_display FROM passages WHERE id=?",
                    (p.passage_id,),
                ).fetchone()["text_display"]
                exact = source[p.start_offset : p.end_offset]
                self.assertEqual(
                    p.text_sha256,
                    hashlib.sha256(exact.encode("utf-8")).hexdigest(),
                )

            study = sqlite3.connect(study_path)
            with study:
                write_pack_foundation(
                    study,
                    {
                        "corpus_version": "fixture-v4",
                        "canonical_text_sha256": "fixture-canonical-sha",
                    },
                    sermon,
                    paragraphs,
                    pack_version=1,
                )
            meta = dict(study.execute("SELECT key,value FROM study_pack_meta"))
            self.assertEqual("fixture-v4", meta["corpus_version"])
            self.assertEqual(
                "fixture-canonical-sha",
                meta["corpus_canonical_sha256"],
            )
            pack = study.execute(
                "SELECT status,validation_status FROM study_packs WHERE sermon_id=1"
            ).fetchone()
            self.assertEqual(("draft", "needs_review"), pack)
            stored = study.execute(
                "SELECT paragraph_key,passage_id,start_offset,end_offset,text_sha256 "
                "FROM study_paragraphs ORDER BY global_ordinal"
            ).fetchall()
            self.assertEqual(4, len(stored))

            study.close()
            corpus.close()


if __name__ == "__main__":
    unittest.main()
