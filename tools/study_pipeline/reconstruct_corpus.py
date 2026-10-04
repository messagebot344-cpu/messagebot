#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path


def reconstruct(project_root: Path, output: Path) -> dict:
    manifest_path = project_root / "assets/corpus/manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    parts_dir = project_root / "assets/corpus/db_parts"

    output.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    total = 0
    with output.open("wb") as target:
        for part in manifest["parts"]:
            source = parts_dir / part["name"]
            data = source.read_bytes()
            if len(data) != part["bytes"]:
                raise RuntimeError(
                    f"Invalid byte count for {part['name']}"
                )
            part_sha = hashlib.sha256(data).hexdigest()
            if part_sha != part["sha256"]:
                raise RuntimeError(
                    f"Invalid SHA-256 for {part['name']}"
                )
            target.write(data)
            digest.update(data)
            total += len(data)

    if total != manifest["database_bytes"]:
        raise RuntimeError(
            f"Database size mismatch: {total} != "
            f"{manifest['database_bytes']}"
        )
    actual_sha = digest.hexdigest()
    if actual_sha != manifest["database_sha256"]:
        raise RuntimeError("Database SHA-256 mismatch.")

    connection = sqlite3.connect(output)
    try:
        quick = connection.execute("PRAGMA quick_check").fetchone()[0]
        if str(quick).lower() != "ok":
            raise RuntimeError(f"PRAGMA quick_check={quick}")
        sermon_count = connection.execute(
            "SELECT COUNT(*) FROM sermons"
        ).fetchone()[0]
    finally:
        connection.close()

    return {
        "database_bytes": total,
        "database_sha256": actual_sha,
        "sermons": sermon_count,
        "quick_check": "ok",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("project_root", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = reconstruct(args.project_root.resolve(), args.output.resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
