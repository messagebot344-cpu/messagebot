#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from dataclasses import dataclass, asdict
from pathlib import Path

from derive_paragraphs import study_paragraph_spans

SCRIPTURE_RE = re.compile(
    r"\b(?:Gen(?:èse|ese)?|Exode|Lév(?:itique)?|Lev(?:itique)?|Nombres|"
    r"Deut(?:éronome|eronome)?|Josué|Josue|Juges|Ruth|Samuel|Rois|"
    r"Chroniques|Esdras|Néhémie|Nehemie|Esther|Job|Psaumes?|Proverbes|"
    r"Ecclésiaste|Ecclesiaste|Ésaïe|Esaie|Jérémie|Jeremie|Ézéchiel|"
    r"Ezechiel|Daniel|Osée|Osee|Joël|Joel|Amos|Abdias|Jonas|Michée|"
    r"Michee|Nahum|Habacuc|Sophonie|Aggée|Aggee|Zacharie|Malachie|"
    r"Matthieu|Marc|Luc|Jean|Actes|Romains|Corinthiens|Galates|"
    r"Éphésiens|Ephesiens|Philippiens|Colossiens|Thessaloniciens|"
    r"Timothée|Timothee|Tite|Philémon|Philemon|Hébreux|Hebreux|"
    r"Jacques|Pierre|Jude|Apocalypse)\s+\d{1,3}\s*[:.]\s*\d{1,3}"
    r"(?:\s*[-–]\s*\d{1,3})?",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class SermonProfile:
    sermon_id: int
    code: str
    title: str
    edition_count: int
    primary_edition_id: str
    passage_count: int
    paragraph_count: int
    character_count: int
    scripture_reference_mentions: int
    unique_scripture_references: int
    scripture_mentions_per_10k_chars: float
    exact_date_available: bool


def _has_exact_date(code: str) -> bool:
    match = re.match(r"^\d{2}-(\d{2})(\d{2})", code)
    if not match:
        return False
    month = int(match.group(1))
    day = int(match.group(2))
    if not 1 <= month <= 12:
        return False
    if not 1 <= day <= 31:
        return False
    days = {
        2: 29,
        4: 30,
        6: 30,
        9: 30,
        11: 30,
    }
    return day <= days.get(month, 31)


def profile_sermons(connection: sqlite3.Connection) -> list[SermonProfile]:
    connection.row_factory = sqlite3.Row
    sermons = connection.execute(
        "SELECT id,code,title,edition_count,primary_edition_id "
        "FROM sermons ORDER BY code"
    ).fetchall()
    profiles: list[SermonProfile] = []
    for sermon in sermons:
        rows = connection.execute(
            "SELECT text_display FROM passages "
            "WHERE edition_id=? ORDER BY ordinal,id",
            (sermon["primary_edition_id"],),
        ).fetchall()
        texts = [row["text_display"] for row in rows]
        # Prototype metrics use only certifying-study content; canonical
        # publisher/distribution tails remain untouched in corpus.db.
        study_blocks: list[str] = []
        for text in texts:
            for start, end in study_paragraph_spans(text):
                study_blocks.append(text[start:end])
        character_count = sum(len(text) for text in study_blocks)
        paragraph_count = len(study_blocks)
        refs = [
            match.group(0)
            for text in study_blocks
            for match in SCRIPTURE_RE.finditer(text)
        ]
        unique_refs = {
            re.sub(r"\s+", " ", value.strip().lower()) for value in refs
        }
        density = (
            len(refs) * 10000.0 / character_count
            if character_count
            else 0.0
        )
        profiles.append(
            SermonProfile(
                sermon_id=sermon["id"],
                code=sermon["code"],
                title=sermon["title"],
                edition_count=sermon["edition_count"],
                primary_edition_id=sermon["primary_edition_id"],
                passage_count=len(rows),
                paragraph_count=paragraph_count,
                character_count=character_count,
                scripture_reference_mentions=len(refs),
                unique_scripture_references=len(unique_refs),
                scripture_mentions_per_10k_chars=round(density, 4),
                exact_date_available=_has_exact_date(sermon["code"]),
            )
        )
    return profiles


def _quantile_profile(
    profiles: list[SermonProfile],
    quantile: float,
) -> SermonProfile:
    ordered = sorted(profiles, key=lambda item: item.character_count)
    index = round((len(ordered) - 1) * quantile)
    return ordered[index]


def select_prototypes(
    profiles: list[SermonProfile],
) -> dict[str, SermonProfile]:
    if not profiles:
        raise ValueError("No sermons found.")

    by_code = {profile.code: profile for profile in profiles}
    median_chars = _quantile_profile(profiles, 0.50).character_count

    multi = [
        item
        for item in profiles
        if item.edition_count > 1
    ]
    multi_choice = min(
        multi,
        key=lambda item: abs(item.character_count - median_chars),
    )

    scripture_candidates = [
        item
        for item in profiles
        if item.character_count >= median_chars
        and item.scripture_reference_mentions >= 5
    ]
    scripture_choice = max(
        scripture_candidates,
        key=lambda item: (
            item.scripture_mentions_per_10k_chars,
            item.unique_scripture_references,
        ),
    )

    imprecise = [item for item in profiles if not item.exact_date_available]
    imprecise_choice = min(
        imprecise,
        key=lambda item: abs(item.character_count - median_chars),
    )

    return {
        "reference_47_0412": by_code["47-0412"],
        "short_q10": _quantile_profile(profiles, 0.10),
        "median_q50": _quantile_profile(profiles, 0.50),
        "long_q90": _quantile_profile(profiles, 0.90),
        "multi_edition": multi_choice,
        "high_scripture_density": scripture_choice,
        "imprecise_date": imprecise_choice,
    }


def build_report(connection: sqlite3.Connection) -> dict:
    profiles = profile_sermons(connection)
    selected = select_prototypes(profiles)

    unique: dict[int, dict] = {}
    for role, profile in selected.items():
        entry = unique.setdefault(
            profile.sermon_id,
            {
                **asdict(profile),
                "roles": [],
            },
        )
        entry["roles"].append(role)

    char_counts = sorted(item.character_count for item in profiles)
    return {
        "sermons_detected": len(profiles),
        "selection_method": (
            "q10/q50/q90 by primary-edition character count; "
            "multi-edition nearest median; high scripture density among "
            "sermons >= median length; imprecise-date nearest median"
        ),
        "character_count_distribution": {
            "min": char_counts[0],
            "q10": _quantile_profile(profiles, 0.10).character_count,
            "median": _quantile_profile(profiles, 0.50).character_count,
            "q90": _quantile_profile(profiles, 0.90).character_count,
            "max": char_counts[-1],
        },
        "selected_by_role": {
            role: asdict(profile) for role, profile in selected.items()
        },
        "unique_prototypes": sorted(
            unique.values(),
            key=lambda item: item["code"],
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus_db", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    connection = sqlite3.connect(
        f"file:{args.corpus_db}?mode=ro",
        uri=True,
    )
    try:
        report = build_report(connection)
    finally:
        connection.close()

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
