# Corrections appliquées après l’audit V1

## P0 / reproductibilité

- Flutter de référence figé à `3.35.4` dans GitHub Actions, `.flutter-version` et `.fvmrc`.
- Dépendances directes Flutter figées à des versions exactes.
- Scripts Windows durcis : contrôle de version, validation du corpus, génération des plateformes, analyse et tests.
- Deux nouveaux tests de politique d’éditions et un test de rejet hors vocabulaire ajoutés.

> Limite : `pubspec.lock`, `android/` et `windows/` doivent encore être générés par un vrai SDK Flutter 3.35.4. Ils ne sont pas fabriqués manuellement afin d’éviter des fichiers natifs non vérifiés.

## P1 / qualité de recherche

- Reconstruction FTS5 après suppression **uniquement dans l’index** des pieds de page et coordonnées éditoriales connus.
- 1 386 passages affectés ; 820 820 caractères retirés de la représentation de recherche ; `text_display` inchangé.
- 17 passages devenus vides côté recherche car ils étaient entièrement éditoriaux.
- Index sémantique reconstruit avec le même filtre.
- Éditions alternatives intégrées comme secours lexical à poids faible ; le primaire reste prioritaire.
- Déduplication : une édition alternative n’est pas montrée si une édition principale de la même prédication est déjà candidate.

## P1 / fidélité du corpus

- Validation SQLite V2 : 39 303 passages / 39 303 lignes FTS / intégrité `ok`.
- Smoke tests : `foi` et `bapteme` présents ; `ordinateur AND quantique` absent ; `shekinahgospelmissions` absent de FTS.
- Vérification directe de 100 passages tirés de manière déterministe contre leurs pages du PDF source : **100/100 concordants**.

## P2 / documentation et mentions

- Page À propos enrichie avec politique de fidélité, droits applicables et licences logicielles.
- Rapports V2 actualisés et versionnés.
