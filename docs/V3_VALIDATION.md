# Validation V3

La V3 applique le principe **zéro génération de texte** : la recherche et les outils d’étude manipulent des identifiants, scores et métadonnées ; le texte affiché est résolu ensuite dans `corpus.db`.

## Contrôles exécutables sans Flutter

```bash
python tools/test_v3_corpus.py /chemin/vers/corpus_v3.db --manifest assets/corpus/manifest.json
python tools/v3_static_contract_test.py --phase all
python tools/static_project_check.py
python tools/validate_v3_release.py
```

`validate_v3_release.py` reconstruit temporairement la base depuis les 39 morceaux, vérifie leurs SHA-256, le SHA global, `PRAGMA integrity_check`, `PRAGMA quick_check`, le schéma V3, les tables d’étude, le livre, les assets sémantiques, l’absence de dépendances réseau et l’absence d’API `answer(...)` dans les moteurs.

## Contrôles Flutter obligatoires avant publication

Avec Flutter **3.35.4** :

```bash
flutter create --platforms=android,windows --org org.godfirst .
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```

La CI sépare Android/Linux et Windows afin que chaque plateforme soit construite sur son runner natif.

## Recette fonctionnelle à réaliser sur appareils réels

- mode avion : lecture, recherche, favoris, collections, concordance et passages similaires ;
- ouverture d’un résultat exactement au passage concerné ;
- vérification que la phrase surlignée est une sous-chaîne du passage ;
- reprise de lecture après fermeture forcée ;
- mise à jour du corpus sans perte de `user.db` ;
- corruption volontaire d’un fichier staged : l’ancien `corpus.db` doit rester utilisable ;
- comparaison des deux éditions d’un même sermon ;
- navigation du livre par chapitres ;
- temps médian et P95 des recherches sur téléphone 3 Go RAM ;
- jeu de 50 à 100 requêtes métier, avec mesure REC-04 top-5.

## Limitation connue de l’environnement de génération

Le SDK Flutter n’est pas présent dans l’environnement où ce ZIP V3 est assemblé. Les validations Python/statique y sont exécutées ; les commandes Flutter sont confiées à la CI et doivent être considérées **non exécutées localement** tant qu’un rapport de runner n’est pas disponible.
