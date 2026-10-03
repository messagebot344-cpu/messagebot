# Validation Message Bot V4

Le paquet V4 migre le corpus de schéma 3 vers schéma 4 sans modifier le texte canonique des 39 679 passages.

Contrôles inclus :

- `python tools/v4_runtime_guard.py` : aucune dépendance LSA dans le chemin d’exécution V4, aucun client réseau ajouté, branding public Message Bot, assets LSA exclus ;
- `python tools/validate_v4_release.py` : SHA-256 de chaque morceau, SHA-256 global, `PRAGMA quick_check`, schéma V4, nombre de passages et empreinte indépendante du texte canonique ;
- CI : `flutter pub get`, `flutter analyze`, `flutter test`, build Android release et build Windows release.

L’environnement de consolidation de ce ZIP ne contient pas le SDK Flutter/Dart. Les contrôles Python/SQLite sont donc exécutés localement ici, tandis que les contrôles Flutter sont préparés dans la CI GitHub.
