#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from select_prototype_sermons import SermonProfile, select_prototypes


def profile(
    sermon_id: int,
    code: str,
    chars: int,
    *,
    editions: int = 1,
    refs: int = 2,
    unique_refs: int = 2,
    exact_date: bool = True,
) -> SermonProfile:
    return SermonProfile(
        sermon_id=sermon_id,
        code=code,
        title=f"Sermon {code}",
        edition_count=editions,
        primary_edition_id=f"e{sermon_id}",
        passage_count=max(1, chars // 3000),
        paragraph_count=max(1, chars // 500),
        character_count=chars,
        scripture_reference_mentions=refs,
        unique_scripture_references=unique_refs,
        scripture_mentions_per_10k_chars=refs * 10000.0 / chars,
        exact_date_available=exact_date,
    )


class PrototypeSelectionTest(unittest.TestCase):
    def test_required_roles_are_selected_from_profiles(self) -> None:
        profiles = [
            profile(
                1,
                "47-0412",
                12000,
                refs=8,
                unique_refs=5,
            ),
        ]
        for i in range(2, 22):
            profiles.append(
                profile(
                    i,
                    f"60-{i:04d}",
                    5000 + i * 1500,
                    editions=2 if i == 12 else 1,
                    refs=40 if i == 18 else 3,
                    unique_refs=20 if i == 18 else 2,
                    exact_date=i != 15,
                )
            )

        selected = select_prototypes(profiles)

        self.assertEqual("47-0412", selected["reference_47_0412"].code)
        self.assertEqual(2, selected["multi_edition"].edition_count)
        self.assertFalse(selected["imprecise_date"].exact_date_available)
        self.assertGreaterEqual(
            selected["long_q90"].character_count,
            selected["median_q50"].character_count,
        )
        self.assertLessEqual(
            selected["short_q10"].character_count,
            selected["median_q50"].character_count,
        )
        self.assertEqual(
            18,
            selected["high_scripture_density"].sermon_id,
        )


if __name__ == "__main__":
    unittest.main()
