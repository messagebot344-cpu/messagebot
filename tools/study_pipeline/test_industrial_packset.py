#!/usr/bin/env python3
from __future__ import annotations

import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from build_industrial_packset import build_packset
from validate_industrial_packset import validate


def create_toy_corpus(path: Path) -> None:
    db = sqlite3.connect(path)
    try:
        db.execute(
            "CREATE TABLE corpus_meta(key TEXT PRIMARY KEY,value TEXT NOT NULL)"
        )
        db.executemany(
            "INSERT INTO corpus_meta(key,value) VALUES(?,?)",
            [
                ("corpus_version", "toy-v4"),
                ("canonical_text_sha256", "toy-canonical-hash"),
            ],
        )
        db.execute(
            "CREATE TABLE sermons("
            "id INTEGER PRIMARY KEY,code TEXT,title TEXT,year INTEGER,"
            "primary_edition_id TEXT)"
        )
        db.execute(
            "CREATE TABLE passages("
            "id INTEGER PRIMARY KEY,edition_id TEXT,sermon_id INTEGER,"
            "ordinal INTEGER,source_page_start INTEGER,source_page_end INTEGER,"
            "text_display TEXT)"
        )

        passage_id = 1
        for sermon_id, name in enumerate(
            ["Alpha", "Beta", "Gamma", "Delta"],
            start=1,
        ):
            edition = f"edition-{sermon_id}"
            db.execute(
                "INSERT INTO sermons("
                "id,code,title,year,primary_edition_id"
                ") VALUES(?,?,?,?,?)",
                (
                    sermon_id,
                    f"50-000{sermon_id}",
                    f"Prédication {name}",
                    1950,
                    edition,
                ),
            )
            paragraphs: list[str] = []
            paragraph_count = 1 if sermon_id == 4 else 3
            sentence_count = 30 if sermon_id == 4 else 7
            for paragraph_index in range(paragraph_count):
                sentences = [
                    (
                        f"Dans la prédication {name}, la section "
                        f"{paragraph_index + 1} présente précisément "
                        f"l’affirmation numéro {sentence_index + 1} "
                        "afin de vérifier une lecture attentive et fidèle."
                    )
                    for sentence_index in range(sentence_count)
                ]
                paragraphs.append(" ".join(sentences))
            text = "\n\n".join(paragraphs)
            db.execute(
                "INSERT INTO passages("
                "id,edition_id,sermon_id,ordinal,source_page_start,"
                "source_page_end,text_display"
                ") VALUES(?,?,?,?,?,?,?)",
                (
                    passage_id,
                    edition,
                    sermon_id,
                    0,
                    sermon_id,
                    sermon_id + 1,
                    text,
                ),
            )
            passage_id += 1
        db.commit()
    finally:
        db.close()


class IndustrialPacksetTest(unittest.TestCase):
    def test_generic_generator_publishes_auditable_offline_packs(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            corpus = root / "corpus.db"
            study = root / "study_packs.db"
            assets = root / "assets" / "study"
            report_path = root / "report.json"
            create_toy_corpus(corpus)

            report = build_packset(
                corpus,
                study,
                schema_path=HERE / "study_pack_schema.sql",
                assets_dir=assets,
                report_path=report_path,
            )

            self.assertEqual(report["sermons_processed"], 4)
            self.assertEqual(report["packs_published"], 4)
            self.assertEqual(report["packs_rejected"], 0)
            self.assertGreater(report["total_questions_validated"], 90)

            validation = validate(corpus, study)
            self.assertEqual(validation["errors"], [])
            self.assertEqual(validation["published_packs"], 4)
            self.assertGreater(validation["evidence_checked"], 0)

            db = sqlite3.connect(study)
            try:
                short_rule = db.execute(
                    "SELECT exam_size,pass_threshold "
                    "FROM study_exam_rules WHERE sermon_id=4"
                ).fetchone()
                self.assertEqual(short_rule, (10, 0.85))
                short_categories = {
                    row[0]: row[1]
                    for row in db.execute(
                        "SELECT category,question_count "
                        "FROM study_exam_category_rules "
                        "WHERE sermon_id=4"
                    )
                }
                self.assertEqual(
                    short_categories,
                    {"comprehension": 7, "reasoning": 3},
                )
            finally:
                db.close()

            manifest = (assets / "manifest.json").read_text(
                encoding="utf-8"
            )
            self.assertIn('"status": "industrial_v1"', manifest)
            self.assertTrue(report_path.exists())


if __name__ == "__main__":
    unittest.main()
