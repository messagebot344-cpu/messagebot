# Pipeline reproductible du corpus

Le traitement lourd est exécuté hors de Flutter. L’application ne reçoit qu’un paquet local validé.

## Étapes

1. Extraire les prédications et leurs éditions à partir des signets du PDF :

```bash
python extract_corpus.py /chemin/Le_20Grenier_20du_20Message.pdf /chemin/work
```

2. Construire SQLite et l’index lexical FTS5 :

```bash
python build_database.py /chemin/work /chemin/corpus.db
```

`build_database.py` conserve le texte canonique dans `text_display`. Pour l’index de recherche uniquement, `search_text.py` retire des blocs éditoriaux/distributifs connus afin qu’ils ne prennent pas la place des prédications dans les résultats.

3. Construire l’index sémantique local non génératif :

```bash
python build_semantic.py /chemin/corpus.db /chemin/semantic
```

4. Découper la base et préparer les assets Flutter :

```bash
python package_assets.py /chemin/corpus.db /chemin/semantic /chemin/projet/assets/corpus \
  --corpus-version 2019.06-source__app-2026.09.20-v2
```

5. Valider le livrable :

```bash
python ../validate_release.py /chemin/projet
```

6. Facultatif mais recommandé lors d’une reconstruction depuis le PDF source : vérifier un échantillon canonique :

```bash
python ../verify_canonical_sample.py /chemin/corpus.db /chemin/source.pdf /chemin/rapport.json --samples 100
```

## Mise à niveau d’une base V1 existante

`tools/upgrade_search_index_v2.py` reconstruit uniquement FTS5 sans modifier `text_display` :

```bash
python tools/upgrade_search_index_v2.py corpus_v1.db corpus_v2.db
```

L’index sémantique doit ensuite être régénéré avec `build_semantic.py` pour utiliser exactement la même représentation de recherche filtrée.
