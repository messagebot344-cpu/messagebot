from __future__ import annotations

import re
import unicodedata

SPACE_RE = re.compile(r"\s+")

# Editorial/distribution material appears in the visible source PDF and must remain
# in text_display for fidelity. It is removed only from the searchable representation
# so that contact blocks and publisher footers do not outrank sermon content.
_FOOTER_STARTS = (
    "ce texte est la version française du message oral",
    "ce texte est la version francaise du message oral",
    "la traduction de ce sermon a été fournie",
    "la traduction de ce sermon a ete fournie",
)
_FOOTER_MARKERS = (
    "shekinah publications",
    "branham.fr",
    "branham.ru",
    "exemplaires supplémentaires",
    "exemplaires supplementaires",
)
_LINE_MARKERS = (
    "shekinah publications",
    "shekinahgospelmissions",
    "shekinahmission@",
    "pasteurdick@",
    "www.branham.fr",
    "www.branham.ru",
    "http://www.branham",
    "https://www.branham",
    "b.p. 10. 493",
    "central africa",
    "commune de limete",
    "17e rue / bld lumumba",
    "veuillez trouver les autres prédications",
    "veuillez trouver les autres predications",
)


def clean_controls(value: str) -> str:
    return "".join(char for char in value if char in "\n\r\t\f" or ord(char) >= 32)


def remove_editorial_search_noise(value: str) -> str:
    """Return a search-only text while preserving the canonical display text elsewhere.

    The rule is deliberately narrow: it cuts a tail only when a known publisher/footer
    introduction is followed by a known distribution marker. It also removes isolated
    address/URL lines. No sermon wording is rewritten.
    """
    value = clean_controls(value).replace("\u00ad", " ")
    lowered = value.lower()
    cut_at: int | None = None
    for start in _FOOTER_STARTS:
        index = lowered.find(start)
        if index < 0:
            continue
        tail = lowered[index:]
        if any(marker in tail for marker in _FOOTER_MARKERS):
            cut_at = index
            break
    if cut_at is not None:
        value = value[:cut_at]

    kept_lines: list[str] = []
    for line in value.splitlines():
        lowered_line = line.lower()
        if any(marker in lowered_line for marker in _LINE_MARKERS):
            continue
        kept_lines.append(line)
    return "\n".join(kept_lines).strip()


def normalize_search(value: str) -> str:
    value = clean_controls(value).replace("\u00ad", " ")
    value = unicodedata.normalize("NFKD", value)
    value = "".join(char for char in value if not unicodedata.combining(char))
    value = value.lower().replace("œ", "oe").replace("æ", "ae")
    value = re.sub(r"[^0-9a-z']+", " ", value, flags=re.I)
    return SPACE_RE.sub(" ", value).strip()


def prepare_search_text(display_text: str) -> str:
    return normalize_search(remove_editorial_search_noise(display_text))
