#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from create_study_pack_db import create_database
from derive_paragraphs import DerivedParagraph, derive_for_sermon, write_pack_foundation

SENTENCE_RE = re.compile(r"[^.!?…\n]+(?:[.!?…]+|$)")
WORD_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿŒœÆæ][A-Za-zÀ-ÖØ-öø-ÿŒœÆæ'’-]{5,}")
SPACE_RE = re.compile(r"\s+")
PART_BYTES = 8 * 1024 * 1024

STOP_WORDS = {
    "alors", "ainsi", "après", "avant", "aucune", "aussi", "autres",
    "avoir", "cette", "comme", "comment", "depuis", "encore", "entre",
    "étaient", "était", "faire", "leurs", "mais", "même", "notre",
    "parce", "peut", "pour", "quand", "quelque", "serait", "toute",
    "toutes", "votre", "vous", "nous", "dans", "avec", "sans",
}


@dataclass(frozen=True)
class SentenceCandidate:
    sermon_id: int
    paragraph_key: str
    passage_id: int
    start_offset: int
    end_offset: int
    source_page_start: int
    source_page_end: int
    text: str


def normalize(value: str) -> str:
    return SPACE_RE.sub(" ", value.strip().lower())


def sentence_spans(value: str) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    for match in SENTENCE_RE.finditer(value):
        start, end = match.span()
        while start < end and value[start].isspace():
            start += 1
        while end > start and value[end - 1].isspace():
            end -= 1
        if end <= start:
            continue
        exact = value[start:end]
        words = exact.split()
        if 7 <= len(words) <= 46 and 45 <= len(exact) <= 320:
            result.append((start, end))
    return result


def stable_index(seed: str, size: int) -> int:
    digest = hashlib.sha256(seed.encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big") % max(1, size)


def current_corpus_meta(corpus: sqlite3.Connection) -> dict[str, str]:
    return {
        key: value
        for key, value in corpus.execute("SELECT key,value FROM corpus_meta")
    }


def paragraph_text_map(
    corpus: sqlite3.Connection,
    paragraphs: Iterable[DerivedParagraph],
) -> dict[int, str]:
    passage_ids = sorted({item.passage_id for item in paragraphs})
    if not passage_ids:
        return {}
    marks = ",".join("?" for _ in passage_ids)
    return {
        row[0]: row[1]
        for row in corpus.execute(
            f"SELECT id,text_display FROM passages WHERE id IN ({marks})",
            passage_ids,
        )
    }


def candidates_for_sermon(
    corpus: sqlite3.Connection,
    sermon_id: int,
    paragraphs: list[DerivedParagraph],
) -> list[SentenceCandidate]:
    texts = paragraph_text_map(corpus, paragraphs)
    result: list[SentenceCandidate] = []
    for paragraph in paragraphs:
        source = texts.get(paragraph.passage_id)
        if source is None:
            continue
        exact_paragraph = source[paragraph.start_offset:paragraph.end_offset]
        for local_start, local_end in sentence_spans(exact_paragraph):
            text = exact_paragraph[local_start:local_end]
            result.append(
                SentenceCandidate(
                    sermon_id=sermon_id,
                    paragraph_key=paragraph.paragraph_key,
                    passage_id=paragraph.passage_id,
                    start_offset=paragraph.start_offset + local_start,
                    end_offset=paragraph.start_offset + local_end,
                    source_page_start=paragraph.source_page_start,
                    source_page_end=paragraph.source_page_end,
                    text=text,
                )
            )
    return result


def build_global_distractor_pool(
    corpus: sqlite3.Connection,
    *,
    limit: int = 6000,
) -> list[tuple[int, str]]:
    pool: list[tuple[int, str]] = []
    rows = corpus.execute(
        "SELECT sermon_id,text_display FROM passages "
        "WHERE sermon_id IS NOT NULL ORDER BY id"
    )
    for sermon_id, text in rows:
        for start, end in sentence_spans(text or ""):
            candidate = text[start:end]
            if 55 <= len(candidate) <= 220:
                pool.append((int(sermon_id), candidate))
                if len(pool) >= limit:
                    return pool
    return pool


def global_word_pool(sentences: list[tuple[int, str]], limit: int = 3000) -> list[str]:
    values: list[str] = []
    seen: set[str] = set()
    for _, sentence in sentences:
        for match in WORD_RE.finditer(sentence):
            word = match.group(0)
            key = normalize(word)
            if key in STOP_WORDS or key in seen:
                continue
            seen.add(key)
            values.append(word)
            if len(values) >= limit:
                return values
    return values


def split_sections(
    paragraphs: list[DerivedParagraph],
) -> list[list[DerivedParagraph]]:
    total_chars = sum(item.character_count for item in paragraphs)
    if not paragraphs:
        return []
    desired = max(3, min(12, round(total_chars / 18000)))
    desired = min(desired, len(paragraphs))
    target = max(1, math.ceil(total_chars / desired))
    sections: list[list[DerivedParagraph]] = []
    current: list[DerivedParagraph] = []
    current_chars = 0
    remaining_groups = desired
    for index, paragraph in enumerate(paragraphs):
        current.append(paragraph)
        current_chars += paragraph.character_count
        remaining_paragraphs = len(paragraphs) - index - 1
        if (
            remaining_groups > 1
            and current_chars >= target
            and remaining_paragraphs >= remaining_groups - 1
        ):
            sections.append(current)
            current = []
            current_chars = 0
            remaining_groups -= 1
    if current:
        sections.append(current)
    return sections


class PackWriter:
    def __init__(
        self,
        study: sqlite3.Connection,
        corpus: sqlite3.Connection,
        distractor_pool: list[tuple[int, str]],
        word_pool: list[str],
    ) -> None:
        self.study = study
        self.corpus = corpus
        self.distractor_pool = distractor_pool
        self.word_pool = word_pool
        self.evidence_cache: dict[tuple[int, int, int, str], int] = {}

    def evidence(self, item: SentenceCandidate, pack_version: int) -> int:
        key = (
            item.passage_id,
            item.start_offset,
            item.end_offset,
            hashlib.sha256(item.text.encode("utf-8")).hexdigest(),
        )
        cached = self.evidence_cache.get(key)
        if cached is not None:
            return cached
        cursor = self.study.execute(
            "INSERT INTO study_source_evidence("
            "sermon_id,pack_version,source_kind,evidence_role,passage_id,"
            "paragraph_key,start_offset,end_offset,exact_quote,quote_sha256,"
            "source_page_start,source_page_end"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                item.sermon_id,
                pack_version,
                "sermon",
                "correct_answer_support",
                item.passage_id,
                item.paragraph_key,
                item.start_offset,
                item.end_offset,
                item.text,
                hashlib.sha256(item.text.encode("utf-8")).hexdigest(),
                item.source_page_start,
                item.source_page_end,
            ),
        )
        evidence_id = int(cursor.lastrowid)
        self.evidence_cache[key] = evidence_id
        return evidence_id

    def create_question(
        self,
        *,
        sermon_id: int,
        pack_version: int,
        section_id: int,
        qtype: str,
        category: str,
        difficulty: int,
        prompt: str,
        options: list[tuple[str, bool]],
        evidence: list[SentenceCandidate],
        generator_kind: str,
        correct_order_texts: list[str] | None = None,
    ) -> int:
        cursor = self.study.execute(
            "INSERT INTO study_questions("
            "sermon_id,pack_version,section_id,type,category,difficulty,prompt,"
            "pedagogical_explanation,correct_answer_payload,scoring_payload,"
            "validation_status,certification_eligible,generator_kind,created_at,"
            "reviewed_at,reviewer"
            ") VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                sermon_id,
                pack_version,
                section_id,
                qtype,
                category,
                difficulty,
                prompt,
                "",
                "{}",
                json.dumps({"mode": "exact"}, ensure_ascii=False),
                "validated",
                1,
                generator_kind,
                0,
                0,
                "deterministic-validator-v1",
            ),
        )
        question_id = int(cursor.lastrowid)
        option_ids: list[int] = []
        correct_ids: list[int] = []
        text_to_id: dict[str, int] = {}
        for ordinal, (text, correct) in enumerate(options):
            option_cursor = self.study.execute(
                "INSERT INTO study_question_options("
                "question_id,ordinal,option_text,is_correct,rationale"
                ") VALUES(?,?,?,?,?)",
                (
                    question_id,
                    ordinal,
                    text,
                    1 if correct else 0,
                    None,
                ),
            )
            option_id = int(option_cursor.lastrowid)
            option_ids.append(option_id)
            text_to_id[text] = option_id
            if correct:
                correct_ids.append(option_id)

        if qtype == "reasoning_order":
            if not correct_order_texts:
                raise RuntimeError("reasoning_order requires correct order")
            correct_order = [text_to_id[value] for value in correct_order_texts]
            payload: object = {"correct_order": correct_order}
        elif qtype == "multiple_choice":
            payload = {"option_ids": correct_ids}
        else:
            if len(correct_ids) != 1:
                raise RuntimeError(
                    f"{qtype} must have exactly one correct option"
                )
            payload = {"option_id": correct_ids[0]}

        self.study.execute(
            "UPDATE study_questions SET correct_answer_payload=? WHERE id=?",
            (json.dumps(payload, ensure_ascii=False), question_id),
        )

        for item in evidence:
            evidence_id = self.evidence(item, pack_version)
            self.study.execute(
                "INSERT OR IGNORE INTO study_question_evidence("
                "question_id,evidence_id,evidence_role"
                ") VALUES(?,?,?)",
                (question_id, evidence_id, "correct_answer_support"),
            )
        return question_id

    def quote_distractors(
        self,
        sermon_id: int,
        correct: str,
        *,
        seed: str,
        count: int = 3,
        sermon_text: str,
    ) -> list[str]:
        if not self.distractor_pool:
            return []
        result: list[str] = []
        start = stable_index(seed, len(self.distractor_pool))
        for step in range(len(self.distractor_pool)):
            other_sermon, value = self.distractor_pool[
                (start + step) % len(self.distractor_pool)
            ]
            if other_sermon == sermon_id:
                continue
            if normalize(value) == normalize(correct):
                continue
            if normalize(value) in sermon_text:
                continue
            if value in result:
                continue
            result.append(value)
            if len(result) == count:
                break
        return result

    def word_distractors(
        self,
        correct: str,
        *,
        seed: str,
        count: int = 3,
    ) -> list[str]:
        if not self.word_pool:
            return []
        result: list[str] = []
        correct_key = normalize(correct)
        start = stable_index(seed, len(self.word_pool))
        for step in range(len(self.word_pool)):
            value = self.word_pool[(start + step) % len(self.word_pool)]
            if normalize(value) == correct_key or value in result:
                continue
            result.append(value)
            if len(result) == count:
                break
        return result


def select_blank_word(sentence: str) -> tuple[str, str] | None:
    matches = [
        match
        for match in WORD_RE.finditer(sentence)
        if normalize(match.group(0)) not in STOP_WORDS
    ]
    if not matches:
        return None
    match = matches[len(matches) // 2]
    word = match.group(0)
    prompt = sentence[:match.start()] + "____" + sentence[match.end():]
    return prompt, word


def insert_sections(
    study: sqlite3.Connection,
    sermon_id: int,
    pack_version: int,
    sections: list[list[DerivedParagraph]],
) -> tuple[list[int], dict[str, int]]:
    ids: list[int] = []
    paragraph_to_section: dict[str, int] = {}
    for ordinal, paragraphs in enumerate(sections):
        first_page = paragraphs[0].source_page_start
        last_page = paragraphs[-1].source_page_end
        page_label = (
            f"p. {first_page}"
            if first_page == last_page
            else f"pp. {first_page}-{last_page}"
        )
        title = f"Partie {ordinal + 1} · {page_label}"
        cursor = study.execute(
            "INSERT INTO study_sections("
            "sermon_id,pack_version,ordinal,title,kind,required_for_exam,"
            "minimum_reading_percent"
            ") VALUES(?,?,?,?,?,?,?)",
            (
                sermon_id,
                pack_version,
                ordinal,
                title,
                "canonical_sequence",
                1,
                0.90,
            ),
        )
        section_id = int(cursor.lastrowid)
        ids.append(section_id)
        study.execute(
            "INSERT INTO study_learning_objectives("
            "section_id,label,validation_status"
            ") VALUES(?,?,?)",
            (
                section_id,
                "Repérer les déclarations exactes et leur progression "
                "dans cette partie de la prédication.",
                "validated",
            ),
        )
        for position, paragraph in enumerate(paragraphs):
            study.execute(
                "INSERT INTO study_section_paragraphs("
                "section_id,paragraph_key,position"
                ") VALUES(?,?,?)",
                (section_id, paragraph.paragraph_key, position),
            )
            paragraph_to_section[paragraph.paragraph_key] = section_id
    return ids, paragraph_to_section


def build_questions_for_sermon(
    writer: PackWriter,
    *,
    sermon: sqlite3.Row,
    pack_version: int,
    sections: list[list[DerivedParagraph]],
    section_ids: list[int],
    candidates: list[SentenceCandidate],
) -> dict[str, int]:
    by_paragraph: dict[str, list[SentenceCandidate]] = {}
    for item in candidates:
        by_paragraph.setdefault(item.paragraph_key, []).append(item)

    section_candidates: list[list[SentenceCandidate]] = []
    for paragraphs in sections:
        values: list[SentenceCandidate] = []
        for paragraph in paragraphs:
            values.extend(by_paragraph.get(paragraph.paragraph_key, []))
        section_candidates.append(values)

    sermon_text = normalize(" ".join(item.text for item in candidates))
    counts = {"comprehension": 0, "context": 0, "reasoning": 0}

    for section_index, values in enumerate(section_candidates):
        if not values:
            continue
        section_id = section_ids[section_index]

        for local_index, item in enumerate(values[:4]):
            distractors = writer.quote_distractors(
                int(sermon["id"]),
                item.text,
                seed=f"quote|{sermon['id']}|{section_index}|{local_index}",
                sermon_text=sermon_text,
            )
            if len(distractors) == 3:
                options = [(item.text, True)] + [
                    (value, False) for value in distractors
                ]
                writer.create_question(
                    sermon_id=int(sermon["id"]),
                    pack_version=pack_version,
                    section_id=section_id,
                    qtype="single_choice",
                    category="comprehension",
                    difficulty=3,
                    prompt=(
                        "Laquelle de ces citations appartient exactement "
                        "à cette prédication ?"
                    ),
                    options=options,
                    evidence=[item],
                    generator_kind="deterministic_exact_quote_v1",
                )
                counts["comprehension"] += 1

        for local_index, item in enumerate(values[:4]):
            blank = select_blank_word(item.text)
            if blank is None:
                continue
            prompt_text, correct_word = blank
            distractors = writer.word_distractors(
                correct_word,
                seed=f"blank|{sermon['id']}|{section_index}|{local_index}",
            )
            if len(distractors) != 3:
                continue
            writer.create_question(
                sermon_id=int(sermon["id"]),
                pack_version=pack_version,
                section_id=section_id,
                qtype="fill_blank",
                category="comprehension",
                difficulty=4,
                prompt=(
                    "Quel mot complète exactement cette citation ?\n\n"
                    + prompt_text
                ),
                options=[(correct_word, True)]
                + [(value, False) for value in distractors],
                evidence=[item],
                generator_kind="deterministic_fill_blank_v1",
            )
            counts["comprehension"] += 1

        if len(section_ids) >= 3:
            for local_index, item in enumerate(values[:2]):
                other_indices = [
                    index
                    for index in range(len(section_ids))
                    if index != section_index
                ]
                start = stable_index(
                    f"context|{sermon['id']}|{section_index}|{local_index}",
                    len(other_indices),
                )
                chosen = [
                    other_indices[(start + offset) % len(other_indices)]
                    for offset in range(min(3, len(other_indices)))
                ]
                option_sections = [section_index] + chosen
                if len(set(option_sections)) < 3:
                    continue
                options = [
                    (
                        f"Partie {index + 1}",
                        index == section_index,
                    )
                    for index in option_sections
                ]
                writer.create_question(
                    sermon_id=int(sermon["id"]),
                    pack_version=pack_version,
                    section_id=section_id,
                    qtype="quote_to_context",
                    category="context",
                    difficulty=4,
                    prompt=(
                        "Dans quelle partie du parcours se trouve "
                        "cette citation exacte ?\n\n«"
                        + item.text
                        + "»"
                    ),
                    options=options,
                    evidence=[item],
                    generator_kind="deterministic_context_v1",
                )
                counts["context"] += 1

        if len(values) >= 3:
            ordered = values[:3]
            options = [(item.text, False) for item in ordered]
            writer.create_question(
                sermon_id=int(sermon["id"]),
                pack_version=pack_version,
                section_id=section_id,
                qtype="reasoning_order",
                category="reasoning",
                difficulty=5,
                prompt=(
                    "Remettez ces citations dans l’ordre où elles "
                    "apparaissent dans la prédication."
                ),
                options=options,
                evidence=ordered,
                generator_kind="deterministic_sequence_v1",
                correct_order_texts=[item.text for item in ordered],
            )
            counts["reasoning"] += 1

    return counts


def configure_exam(
    study: sqlite3.Connection,
    *,
    sermon_id: int,
    pack_version: int,
    counts: dict[str, int],
) -> tuple[bool, str]:
    required = {
        "comprehension": 6,
        "context": 2,
        "reasoning": 2,
    }
    exam_size = sum(required.values())
    total = sum(counts.values())
    minimum_bank = math.ceil(exam_size * 2.4)
    if total < minimum_bank:
        return False, f"bank={total}<{minimum_bank}"
    for category, needed in required.items():
        if counts.get(category, 0) < needed:
            return False, f"{category}={counts.get(category, 0)}<{needed}"

    study.execute(
        "INSERT INTO study_exam_rules("
        "sermon_id,pack_version,exam_size,pass_threshold,"
        "recent_question_exclusion_count,minimum_reading_percent,"
        "minimum_bank_multiplier"
        ") VALUES(?,?,?,?,?,?,?)",
        (
            sermon_id,
            pack_version,
            exam_size,
            0.85,
            2,
            0.95,
            2.4,
        ),
    )
    rules = [
        ("comprehension", 0.50, 6, 0.75),
        ("context", 0.20, 2, 0.70),
        ("reasoning", 0.30, 2, 0.70),
    ]
    study.executemany(
        "INSERT INTO study_exam_category_rules("
        "sermon_id,pack_version,category,weight,question_count,minimum_score"
        ") VALUES(?,?,?,?,?,?)",
        [
            (sermon_id, pack_version, category, weight, count, minimum)
            for category, weight, count, minimum in rules
        ],
    )
    return True, "ready"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_assets(
    database: Path,
    assets_dir: Path,
    *,
    corpus_meta: dict[str, str],
    report: dict,
) -> dict:
    parts_dir = assets_dir / "db_parts"
    if parts_dir.exists():
        shutil.rmtree(parts_dir)
    parts_dir.mkdir(parents=True, exist_ok=True)

    parts: list[dict] = []
    digest = hashlib.sha256()
    total = 0
    with database.open("rb") as source:
        index = 0
        while True:
            data = source.read(PART_BYTES)
            if not data:
                break
            name = f"study_packs.db.part{index:03d}"
            path = parts_dir / name
            path.write_bytes(data)
            part_sha = hashlib.sha256(data).hexdigest()
            parts.append(
                {"name": name, "bytes": len(data), "sha256": part_sha}
            )
            digest.update(data)
            total += len(data)
            index += 1

    manifest = {
        "packset_version": "industrial-v1-" + corpus_meta["corpus_version"],
        "schema_version": 1,
        "corpus_version": corpus_meta["corpus_version"],
        "corpus_canonical_sha256": corpus_meta["canonical_text_sha256"],
        "database_file": "study_packs.db",
        "database_bytes": total,
        "database_sha256": digest.hexdigest(),
        "parts": parts,
        "stats": {
            "published_packs": report["packs_published"],
            "needs_review_packs": report["packs_needs_review"],
            "status": "industrial_v1",
        },
    }
    assets_dir.mkdir(parents=True, exist_ok=True)
    (assets_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def build_packset(
    corpus_path: Path,
    output_db: Path,
    *,
    schema_path: Path,
    assets_dir: Path | None = None,
    report_path: Path | None = None,
    sermon_limit: int | None = None,
) -> dict:
    corpus = sqlite3.connect(f"file:{corpus_path}?mode=ro", uri=True)
    corpus.row_factory = sqlite3.Row
    meta = current_corpus_meta(corpus)
    if "corpus_version" not in meta or "canonical_text_sha256" not in meta:
        raise RuntimeError("Corpus metadata incomplete.")

    create_database(
        output_db,
        schema_path,
        corpus_version=meta["corpus_version"],
        corpus_canonical_sha256=meta["canonical_text_sha256"],
        packset_version="industrial-v1-" + meta["corpus_version"],
    )
    study = sqlite3.connect(output_db)
    distractor_pool = build_global_distractor_pool(corpus)
    words = global_word_pool(distractor_pool)
    writer = PackWriter(study, corpus, distractor_pool, words)

    sermons = corpus.execute(
        "SELECT id,code,title,year,primary_edition_id "
        "FROM sermons ORDER BY id"
    ).fetchall()
    if sermon_limit is not None:
        sermons = sermons[:sermon_limit]

    report: dict = {
        "artifact_kind": "industrial_study_pack_report",
        "generator": "deterministic-safe-v1",
        "corpus_version": meta["corpus_version"],
        "sermons_detected": len(sermons),
        "sermons_processed": 0,
        "packs_generated": 0,
        "packs_published": 0,
        "packs_needs_review": 0,
        "packs_rejected": 0,
        "total_sections": 0,
        "total_questions_proposed": 0,
        "total_questions_validated": 0,
        "total_questions_needs_review": 0,
        "total_questions_rejected": 0,
        "duplicate_questions": 0,
        "invalid_quotes": 0,
        "invalid_scripture_refs": 0,
        "bible_coverage": 0.0,
        "packs_with_exam_ready": 0,
        "packs_without_sufficient_bank": 0,
        "sermons": [],
    }

    try:
        for sermon in sermons:
            sermon_id = int(sermon["id"])
            pack_version = 1
            try:
                _, paragraphs = derive_for_sermon(corpus, sermon_id)
                with study:
                    write_pack_foundation(
                        study,
                        meta,
                        sermon,
                        paragraphs,
                        pack_version=pack_version,
                    )
                    sections = split_sections(paragraphs)
                    if len(sections) < 3:
                        raise RuntimeError("fewer than 3 study sections")
                    section_ids, _ = insert_sections(
                        study,
                        sermon_id,
                        pack_version,
                        sections,
                    )
                    candidates = candidates_for_sermon(
                        corpus,
                        sermon_id,
                        paragraphs,
                    )
                    counts = build_questions_for_sermon(
                        writer,
                        sermon=sermon,
                        pack_version=pack_version,
                        sections=sections,
                        section_ids=section_ids,
                        candidates=candidates,
                    )
                    ready, reason = configure_exam(
                        study,
                        sermon_id=sermon_id,
                        pack_version=pack_version,
                        counts=counts,
                    )
                    question_count = sum(counts.values())
                    status = "published" if ready else "needs_review"
                    validation_status = "validated" if ready else "needs_review"
                    study.execute(
                        "UPDATE study_packs SET status=?,validation_status=?,"
                        "published_at=? WHERE sermon_id=? AND pack_version=?",
                        (
                            status,
                            validation_status,
                            0 if ready else None,
                            sermon_id,
                            pack_version,
                        ),
                    )

                report["sermons_processed"] += 1
                report["packs_generated"] += 1
                report["total_sections"] += len(sections)
                report["total_questions_proposed"] += question_count
                report["total_questions_validated"] += question_count
                if ready:
                    report["packs_published"] += 1
                    report["packs_with_exam_ready"] += 1
                else:
                    report["packs_needs_review"] += 1
                    report["packs_without_sufficient_bank"] += 1
                report["sermons"].append(
                    {
                        "sermon_id": sermon_id,
                        "code": sermon["code"],
                        "status": status,
                        "sections": len(sections),
                        "questions": question_count,
                        "categories": counts,
                        "exam": reason,
                    }
                )
            except Exception as error:
                study.rollback()
                with study:
                    study.execute(
                        "UPDATE study_packs SET status='rejected',"
                        "validation_status='rejected' "
                        "WHERE sermon_id=? AND pack_version=?",
                        (sermon_id, pack_version),
                    )
                    study.execute(
                        "INSERT INTO study_validation_issues("
                        "sermon_id,pack_version,entity_kind,entity_id,"
                        "validator_code,severity,message,created_at"
                        ") VALUES(?,?,?,?,?,?,?,?)",
                        (
                            sermon_id,
                            pack_version,
                            "pack",
                            str(sermon_id),
                            "INDUSTRIAL_BUILD",
                            "error",
                            str(error),
                            0,
                        ),
                    )
                report["sermons_processed"] += 1
                report["packs_rejected"] += 1
                report["sermons"].append(
                    {
                        "sermon_id": sermon_id,
                        "code": sermon["code"],
                        "status": "rejected",
                        "error": str(error),
                    }
                )

        quick = study.execute("PRAGMA quick_check").fetchone()[0]
        if str(quick).lower() != "ok":
            raise RuntimeError(f"study_packs quick_check={quick}")
        study.commit()
    finally:
        study.close()
        corpus.close()

    if report_path is not None:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    if assets_dir is not None:
        manifest = package_assets(
            output_db,
            assets_dir,
            corpus_meta=meta,
            report=report,
        )
        report["packset_database_bytes"] = manifest["database_bytes"]
        report["packset_database_sha256"] = manifest["database_sha256"]

    return report


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus_db", type=Path)
    parser.add_argument("output_db", type=Path)
    parser.add_argument(
        "--schema",
        type=Path,
        default=Path(__file__).with_name("study_pack_schema.sql"),
    )
    parser.add_argument("--assets-dir", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--sermon-limit", type=int)
    args = parser.parse_args()

    report = build_packset(
        args.corpus_db.resolve(),
        args.output_db.resolve(),
        schema_path=args.schema.resolve(),
        assets_dir=(
            args.assets_dir.resolve()
            if args.assets_dir is not None
            else None
        ),
        report_path=(
            args.report.resolve()
            if args.report is not None
            else None
        ),
        sermon_limit=args.sermon_limit,
    )
    print(
        json.dumps(
            {
                key: value
                for key, value in report.items()
                if key != "sermons"
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
