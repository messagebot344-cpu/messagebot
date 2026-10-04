# Study Pack pipeline

Ce dossier construit les données pédagogiques **hors du runtime Flutter**.

Principes :

- corpus.db reste read-only et canonique ;
- study_packs.db est séparé ;
- aucun texte de prédication n'est reformulé pour fabriquer une preuve ;
- les paragraphes d'étude sont des références passage_id + offsets + hash ;
- une question non démontrable ne peut pas devenir published ;
- aucune Bible n'est inventée : les questions dépendant du texte biblique restent bloquées tant qu'un Bible Pack vérifié n'est pas présent.

## Fondation

Créer une base vide liée à un corpus :

```bash
python tools/study_pipeline/create_study_pack_db.py /tmp/study_packs.db \
  --corpus-version "..." \
  --corpus-canonical-sha256 "..." \
  --packset-version "prototype-1"
```

Dériver les paragraphes d'une prédication :

```bash
python tools/study_pipeline/derive_paragraphs.py corpus.db /tmp/study_packs.db \
  --sermon-code 47-0412 \
  --pack-version 1
```

La dérivation ne stocke dans study_packs.db que les identifiants, offsets, pages, tailles et SHA-256. Le texte affiché reste lu depuis corpus.db.
