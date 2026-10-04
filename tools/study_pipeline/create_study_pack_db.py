#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path


def create_database(
    target: Path,
    schema: Path,
    *,
    corpus_version: str,
    corpus_canonical_sha256: str,
    packset_version: str,
) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        target.unlink()
    connection = sqlite3.connect(target)
    try:
        connection.executescript(schema.read_text(encoding="utf-8"))
        connection.executemany(
            "INSERT INTO study_pack_meta(key,value) VALUES(?,?)",
            [
                ("schema_version", "1"),
                ("packset_version", packset_version),
                ("corpus_version", corpus_version),
                (
                    "corpus_canonical_sha256",
                    corpus_canonical_sha256,
                ),
            ],
        )
        connection.commit()
        quick = connection.execute("PRAGMA quick_check").fetchone()[0]
        if str(quick).lower() != "ok":
            raise RuntimeError(f"Study Pack database invalid: {quick}")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", type=Path)
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path(__file__).with_name("study_pack_schema.sql"),
    )
    parser.add_argument("--corpus-version", required=True)
    parser.add_argument("--corpus-canonical-sha256", required=True)
    parser.add_argument("--packset-version", default="prototype-1")
    args = parser.parse_args()
    create_database(
        args.target,
        args.schema,
        corpus_version=args.corpus_version,
        corpus_canonical_sha256=args.corpus_canonical_sha256,
        packset_version=args.packset_version,
    )


if __name__ == "__main__":
    main()
