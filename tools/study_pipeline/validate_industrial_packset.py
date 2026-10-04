#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sqlite3
from pathlib import Path

OPTION_SINGLE_TYPES = {
    "single_choice",
    "true_false_justified",
    "quote_to_context",
    "quote_to_scripture",
    "best_interpretation",
    "bad_interpretation",
    "fill_blank",
}
SUPPORTED_CERT_TYPES = OPTION_SINGLE_TYPES | {
    "multiple_choice",
    "reasoning_order",
    "short_answer",
    "case_study",
    "synthesis",
}


def validate(
    corpus_path: Path,
    study_path: Path,
    *,
    corpus_manifest_path: Path | None = None,
) -> dict:
    corpus = sqlite3.connect(f"file:{corpus_path}?mode=ro", uri=True)
    corpus.row_factory = sqlite3.Row
    study = sqlite3.connect(f"file:{study_path}?mode=ro", uri=True)
    study.row_factory = sqlite3.Row
    errors: list[str] = []
    warnings: list[str] = []

    try:
        quick = study.execute("PRAGMA quick_check").fetchone()[0]
        if str(quick).lower() != "ok":
            errors.append(f"study PRAGMA quick_check={quick}")

        corpus_meta = dict(
            corpus.execute("SELECT key,value FROM corpus_meta").fetchall()
        )
        study_meta = dict(
            study.execute("SELECT key,value FROM study_pack_meta").fetchall()
        )
        expected_corpus_version = corpus_meta.get("corpus_version")
        if corpus_manifest_path is not None:
            packaged = json.loads(
                corpus_manifest_path.read_text(encoding="utf-8")
            )
            if (
                packaged.get("canonical_text_sha256")
                != corpus_meta.get("canonical_text_sha256")
            ):
                errors.append(
                    "Packaged corpus manifest canonical hash mismatch"
                )
            else:
                expected_corpus_version = packaged.get("corpus_version")

        if study_meta.get("corpus_version") != expected_corpus_version:
            errors.append("Study Pack corpus_version mismatch")
        if (
            study_meta.get("corpus_canonical_sha256")
            != corpus_meta.get("canonical_text_sha256")
        ):
            errors.append("Study Pack canonical hash mismatch")

        passage_cache: dict[int, str] = {}
        evidence_rows = study.execute(
            "SELECT id,passage_id,start_offset,end_offset,exact_quote,"
            "quote_sha256 FROM study_source_evidence "
            "WHERE source_kind='sermon' AND exact_quote IS NOT NULL"
        ).fetchall()
        for row in evidence_rows:
            passage_id = row["passage_id"]
            if passage_id is None:
                errors.append(f"evidence {row['id']} missing passage_id")
                continue
            passage_id = int(passage_id)
            text = passage_cache.get(passage_id)
            if text is None:
                source = corpus.execute(
                    "SELECT text_display FROM passages WHERE id=? LIMIT 1",
                    (passage_id,),
                ).fetchone()
                if source is None:
                    errors.append(
                        f"evidence {row['id']} references missing passage "
                        f"{passage_id}"
                    )
                    continue
                text = source["text_display"]
                passage_cache[passage_id] = text
            start = int(row["start_offset"])
            end = int(row["end_offset"])
            if start < 0 or end <= start or end > len(text):
                errors.append(f"evidence {row['id']} has invalid offsets")
                continue
            exact = text[start:end]
            if exact != row["exact_quote"]:
                errors.append(f"evidence {row['id']} exact quote mismatch")
            digest = hashlib.sha256(exact.encode("utf-8")).hexdigest()
            if digest != row["quote_sha256"]:
                errors.append(f"evidence {row['id']} quote hash mismatch")

        published = study.execute(
            "SELECT sermon_id,pack_version,bible_pack_version,"
            "validation_status FROM study_packs WHERE status='published'"
        ).fetchall()

        for pack in published:
            sermon_id = int(pack["sermon_id"])
            pack_version = int(pack["pack_version"])
            label = f"{sermon_id}/v{pack_version}"
            if pack["validation_status"] != "validated":
                errors.append(f"published pack {label} not validated")

            paragraph_count = int(
                study.execute(
                    "SELECT COUNT(*) FROM study_paragraphs "
                    "WHERE sermon_id=? AND pack_version=?",
                    (sermon_id, pack_version),
                ).fetchone()[0]
            )
            assignment_count = int(
                study.execute(
                    "SELECT COUNT(DISTINCT sp.paragraph_key) "
                    "FROM study_section_paragraphs sp "
                    "JOIN study_sections s ON s.id=sp.section_id "
                    "WHERE s.sermon_id=? AND s.pack_version=?",
                    (sermon_id, pack_version),
                ).fetchone()[0]
            )
            if paragraph_count == 0 or assignment_count != paragraph_count:
                errors.append(
                    f"published pack {label} paragraph coverage "
                    f"{assignment_count}/{paragraph_count}"
                )

            duplicate_assignments = int(
                study.execute(
                    "SELECT COUNT(*) FROM ("
                    "SELECT sp.paragraph_key,COUNT(*) AS n "
                    "FROM study_section_paragraphs sp "
                    "JOIN study_sections s ON s.id=sp.section_id "
                    "WHERE s.sermon_id=? AND s.pack_version=? "
                    "GROUP BY sp.paragraph_key HAVING n<>1"
                    ")",
                    (sermon_id, pack_version),
                ).fetchone()[0]
            )
            if duplicate_assignments:
                errors.append(
                    f"published pack {label} has duplicate paragraph assignments"
                )

            rule = study.execute(
                "SELECT exam_size,pass_threshold,minimum_bank_multiplier "
                "FROM study_exam_rules WHERE sermon_id=? AND pack_version=?",
                (sermon_id, pack_version),
            ).fetchone()
            if rule is None:
                errors.append(f"published pack {label} missing exam rules")
                continue
            exam_size = int(rule["exam_size"])
            if not 0 < float(rule["pass_threshold"]) <= 1:
                errors.append(f"published pack {label} invalid pass threshold")

            categories = study.execute(
                "SELECT category,question_count,weight,minimum_score "
                "FROM study_exam_category_rules "
                "WHERE sermon_id=? AND pack_version=?",
                (sermon_id, pack_version),
            ).fetchall()
            if sum(int(row["question_count"]) for row in categories) != exam_size:
                errors.append(f"published pack {label} category quota mismatch")
            if sum(float(row["weight"]) for row in categories) <= 0:
                errors.append(f"published pack {label} invalid category weights")

            questions = study.execute(
                "SELECT id,type,category,correct_answer_payload,"
                "scoring_payload FROM study_questions "
                "WHERE sermon_id=? AND pack_version=? "
                "AND validation_status='validated' "
                "AND certification_eligible=1",
                (sermon_id, pack_version),
            ).fetchall()
            minimum_bank = math.ceil(
                exam_size * float(rule["minimum_bank_multiplier"])
            )
            if len(questions) < minimum_bank:
                errors.append(
                    f"published pack {label} bank {len(questions)}"
                    f"<{minimum_bank}"
                )

            category_counts: dict[str, int] = {}
            signature_seen: set[str] = set()
            for question in questions:
                question_id = int(question["id"])
                category = str(question["category"])
                category_counts[category] = category_counts.get(category, 0) + 1
                qtype = str(question["type"])
                if qtype not in SUPPORTED_CERT_TYPES:
                    errors.append(
                        f"question {question_id} unsupported type {qtype}"
                    )

                evidence_count = int(
                    study.execute(
                        "SELECT COUNT(*) FROM study_question_evidence "
                        "WHERE question_id=? AND evidence_role="
                        "'correct_answer_support'",
                        (question_id,),
                    ).fetchone()[0]
                )
                if evidence_count == 0:
                    errors.append(
                        f"question {question_id} has no answer evidence"
                    )

                options = study.execute(
                    "SELECT id,is_correct FROM study_question_options "
                    "WHERE question_id=? ORDER BY ordinal",
                    (question_id,),
                ).fetchall()
                correct = [
                    int(option["id"])
                    for option in options
                    if int(option["is_correct"]) == 1
                ]

                try:
                    answer_payload = json.loads(
                        question["correct_answer_payload"] or "{}"
                    )
                    scoring_payload = json.loads(
                        question["scoring_payload"] or "{}"
                    )
                except json.JSONDecodeError:
                    errors.append(
                        f"question {question_id} has invalid JSON payload"
                    )
                    continue

                if qtype in OPTION_SINGLE_TYPES and options:
                    if len(correct) != 1:
                        errors.append(
                            f"question {question_id} must have one correct option"
                        )
                    if answer_payload.get("option_id") not in correct:
                        errors.append(
                            f"question {question_id} answer payload mismatch"
                        )
                elif qtype == "multiple_choice":
                    if not correct:
                        errors.append(
                            f"question {question_id} has no correct options"
                        )
                    payload_ids = set(answer_payload.get("option_ids", []))
                    if payload_ids != set(correct):
                        errors.append(
                            f"question {question_id} multi answer mismatch"
                        )
                elif qtype == "reasoning_order":
                    option_ids = {int(option["id"]) for option in options}
                    order = answer_payload.get("correct_order", [])
                    if len(order) != len(option_ids) or set(order) != option_ids:
                        errors.append(
                            f"question {question_id} invalid reasoning order"
                        )
                elif qtype in {"short_answer", "case_study", "synthesis"}:
                    accepted = scoring_payload.get("accepted_answers", [])
                    if not accepted:
                        errors.append(
                            f"question {question_id} open answer lacks "
                            "deterministic rubric"
                        )

                if category == "bible" and not pack["bible_pack_version"]:
                    errors.append(
                        f"question {question_id} requires missing Bible Pack"
                    )

                prompt_row = study.execute(
                    "SELECT prompt FROM study_questions WHERE id=?",
                    (question_id,),
                ).fetchone()
                normalized_prompt = " ".join(
                    str(prompt_row["prompt"]).lower().split()
                )
                option_texts = [
                    " ".join(
                        str(row["option_text"]).lower().split()
                    )
                    for row in study.execute(
                        "SELECT option_text FROM study_question_options "
                        "WHERE question_id=? ORDER BY ordinal",
                        (question_id,),
                    ).fetchall()
                ]
                signature = normalized_prompt + "|" + "|".join(option_texts)
                if signature in signature_seen:
                    errors.append(
                        f"pack {label} has duplicate certification question"
                    )
                signature_seen.add(signature)

            for category_rule in categories:
                category = str(category_rule["category"])
                required = int(category_rule["question_count"])
                if category_counts.get(category, 0) < required:
                    errors.append(
                        f"published pack {label} insufficient {category}"
                    )

        rejected = int(
            study.execute(
                "SELECT COUNT(*) FROM study_packs WHERE status='rejected'"
            ).fetchone()[0]
        )
        needs_review = int(
            study.execute(
                "SELECT COUNT(*) FROM study_packs WHERE status='needs_review'"
            ).fetchone()[0]
        )

        result = {
            "published_packs": len(published),
            "needs_review_packs": needs_review,
            "rejected_packs": rejected,
            "evidence_checked": len(evidence_rows),
            "errors": errors,
            "warnings": warnings,
        }
        return result
    finally:
        study.close()
        corpus.close()


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser()
    parser.add_argument("corpus_db", type=Path)
    parser.add_argument("study_db", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument(
        "--corpus-manifest",
        type=Path,
        default=root / "assets" / "corpus" / "manifest.json",
    )
    args = parser.parse_args()

    result = validate(
        args.corpus_db.resolve(),
        args.study_db.resolve(),
        corpus_manifest_path=(
            args.corpus_manifest.resolve()
            if args.corpus_manifest is not None
            else None
        ),
    )
    if args.report is not None:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result["errors"]:
        raise SystemExit(1)
    if result["published_packs"] == 0:
        raise SystemExit("No published Study Packs were produced.")


if __name__ == "__main__":
    main()
