# Message Bot V4 — Flutter Android + Windows

**Message Bot** est une application de recherche, lecture et étude documentaire conçue pour fonctionner **100 % hors ligne** sur le corpus canonique local.

## V4

- interface conversationnelle moderne : chaque réponse est un ensemble de passages canoniques classés, jamais un texte doctrinal généré ;
- moteur IR déterministe local : FTS5/BM25, citation exacte, proximité, préfixes, variantes morphologiques sûres et tolérance orthographique ;
- aucune IA générative, aucun service cloud et aucun modèle LSA chargé au runtime V4 ;
- conversations et filtres persistés dans `user.db` ;
- bibliothèque, lecteur, favoris, collections, notes et outils d’étude V3 conservés ;
- impression/PDF locale des résultats ;
- thème clair/sombre, interface responsive Android/Windows.

## Identité

Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI  
242 069101357  
ebassombi@gmail.com

## Vérification

Depuis la racine du projet :

```bash
python tools/v4_runtime_guard.py
python tools/validate_v4_release.py
flutter pub get
flutter analyze
flutter test
```

La CI GitHub reconstruit ensuite les plateformes Android/Windows, analyse, teste et compile les livrables.
