#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from create_study_pack_db import create_database

ROOT = Path(__file__).resolve().parents[2]
CORPUS_MANIFEST = ROOT / "assets" / "corpus" / "manifest.json"
STUDY_DIR = ROOT / "assets" / "study"
PARTS_DIR = STUDY_DIR / "db_parts"
SCHEMA = Path(__file__).with_name("study_pack_schema.sql")
BUILD_DB = ROOT / "build" / "study-pack-foundation" / "study_packs.db"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    corpus = json.loads(CORPUS_MANIFEST.read_text(encoding="utf-8"))
    corpus_version = corpus["corpus_version"]
    canonical_sha = corpus["canonical_text_sha256"]
    packset_version = f"foundation-{corpus_version}"

    BUILD_DB.parent.mkdir(parents=True, exist_ok=True)
    create_database(
        BUILD_DB,
        SCHEMA,
        corpus_version=corpus_version,
        corpus_canonical_sha256=canonical_sha,
        packset_version=packset_version,
    )

    STUDY_DIR.mkdir(parents=True, exist_ok=True)
    if PARTS_DIR.exists():
        shutil.rmtree(PARTS_DIR)
    PARTS_DIR.mkdir(parents=True, exist_ok=True)

    part_name = "study_packs.db.part000"
    part = PARTS_DIR / part_name
    shutil.copyfile(BUILD_DB, part)

    database_bytes = BUILD_DB.stat().st_size
    database_sha = sha256(BUILD_DB)
    manifest = {
        "packset_version": packset_version,
        "schema_version": 1,
        "corpus_version": corpus_version,
        "corpus_canonical_sha256": canonical_sha,
        "database_file": "study_packs.db",
        "database_bytes": database_bytes,
        "database_sha256": database_sha,
        "parts": [
            {
                "name": part_name,
                "bytes": part.stat().st_size,
                "sha256": sha256(part),
            }
        ],
        "stats": {
            "published_packs": 0,
            "status": "foundation_only",
        },
    }
    (STUDY_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
