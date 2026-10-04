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

from export_prototype_sources import export_sermon


class PrototypeSourceExportTest(unittest.TestCase):
    def test_export_keeps_exact_text_offsets_and_reference_location(self) -> None:
        with tempfile.TemporaryDirectory(prefix="grenier-source-export-") as tmp:
            path = Path(tmp) / "corpus.db"
            con = sqlite3.connect(path)
            con.executescript(
                """
                CREATE TABLE sermons(
                  id INTEGER PRIMARY KEY,code TEXT,title TEXT,year INTEGER,
                  edition_count INTEGER,primary_edition_id TEXT
                );
                CREATE TABLE passages(
                  id INTEGER PRIMARY KEY,edition_id TEXT,sermon_id INTEGER,
                  ordinal INTEGER,source_page_start INTEGER,
                  source_page_end INTEGER,text_display TEXT
                );
                """
            )
            con.execute(
                "INSERT INTO sermons VALUES(1,'47-0412','Test',1947,1,'e1')"
            )
            text = "1\nIntroduction.\n\nIl cite Jean 3:16 dans ce contexte."
            con.execute(
                "INSERT INTO passages VALUES(10,'e1',1,0,3,3,?)",
                (text,),
            )
            con.commit()

            payload = export_sermon(con, 1)
            self.assertEqual(text, payload["passages"][0]["exact_text"])
            self.assertEqual(2, len(payload["paragraphs"]))
            ref = payload["explicit_scripture_references"][0]
            self.assertEqual("Jean 3:16", ref["display_reference"])
            paragraph = payload["paragraphs"][1]
            passage_text = payload["passages"][0]["exact_text"]
            self.assertEqual(
                "Jean 3:16",
                passage_text[
                    ref["passage_start_offset"] : ref["passage_end_offset"]
                ],
            )
            self.assertEqual(
                paragraph["exact_text"],
                passage_text[
                    paragraph["start_offset"] : paragraph["end_offset"]
                ],
            )
            con.close()


if __name__ == "__main__":
    unittest.main()
