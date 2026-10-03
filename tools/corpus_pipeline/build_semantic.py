from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from pathlib import Path

import numpy as np
from sklearn.decomposition import TruncatedSVD
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.preprocessing import normalize

STOPWORDS = set(
    """a au aux avec ce ces dans de des du elle elles en et eux il ils je la le les leur leurs lui ma mais me mes moi mon ne nos notre nous on ou par pas pour qu que qui sa se ses si son sur ta te tes toi ton tu un une vos votre vous y ca cela ceci cet cette comme donc alors tout tous toute toutes plus moins tres bien est sont etre ete etait étaient avoir avait ont fait faire peut peuvent pouvait puis quand comment pourquoi quoi dont ou ici la-bas afin car parce meme aussi encore entre vers chez sans sous dessus avant apres chaque quelque quelques aucun aucune autre autres ainsi lors tandis depuis jusque jusqu tres trop peu beaucoup""".split()
)


try:
    from search_text import prepare_search_text
except ImportError:  # pragma: no cover - module execution
    from .search_text import prepare_search_text

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description="Construit l'index sémantique local TF-IDF + LSA.")
    parser.add_argument("database", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    connection = sqlite3.connect(args.database)
    rows = connection.execute(
        """
SELECT p.id,p.text_display
FROM passages p
JOIN editions e ON e.id=p.edition_id
WHERE e.is_primary=1
ORDER BY p.id
"""
    ).fetchall()
    connection.close()

    ids = np.array([row[0] for row in rows], dtype=np.int32)
    docs = [prepare_search_text(row[1]) for row in rows]
    vectorizer = TfidfVectorizer(
        max_features=10000,
        min_df=3,
        max_df=0.97,
        lowercase=False,
        token_pattern=r"(?u)\b\w\w+\b",
        norm="l2",
        dtype=np.float32,
        stop_words=sorted(STOPWORDS),
        sublinear_tf=True,
    )
    matrix = vectorizer.fit_transform(docs)
    svd = TruncatedSVD(n_components=64, n_iter=4, random_state=42)
    vectors = svd.fit_transform(matrix).astype(np.float32)
    vectors = normalize(vectors, norm="l2").astype(np.float32)

    terms = [""] * len(vectorizer.vocabulary_)
    for term, index in vectorizer.vocabulary_.items():
        terms[index] = term

    vocab = {
        "terms": terms,
        "idf": vectorizer.idf_.astype(float).tolist(),
        "stopwords": sorted(STOPWORDS),
        "token_pattern": "unicode words length >= 2",
        "normalization": "NFKD accents removed, lowercase; known editorial publisher/contact tails excluded from search only",
        "dimensions": 64,
        "sublinear_tf": True,
    }
    (args.output / "semantic_vocab.json").write_text(
        json.dumps(vocab, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    svd.components_.astype("<f4").tofile(args.output / "semantic_components.f32")
    vectors.astype("<f4").tofile(args.output / "semantic_vectors.f32")
    ids.astype("<i4").tofile(args.output / "semantic_passage_ids.i32")

    manifest = {
        "method": "TF-IDF (French stopwords, sublinear TF) + Latent Semantic Analysis (TruncatedSVD), non-generative, fully offline",
        "documents": len(docs),
        "search_filter_version": "editorial-footer-filter-v1",
        "features": len(terms),
        "dimensions": 64,
        "explained_variance_ratio": float(svd.explained_variance_ratio_.sum()),
        "files": {},
    }
    for filename in [
        "semantic_vocab.json",
        "semantic_components.f32",
        "semantic_vectors.f32",
        "semantic_passage_ids.i32",
    ]:
        path = args.output / filename
        manifest["files"][filename] = {"bytes": path.stat().st_size, "sha256": sha(path)}
    (args.output / "semantic_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
