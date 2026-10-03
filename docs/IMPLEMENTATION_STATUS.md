# État d’implémentation — Le Grenier du Message V3

| Domaine | État V3 | Implémentation / preuve |
|---|---|---|
| Prédications | Implémenté | 1 211 prédications / 1 421 éditions |
| *Exposé des Sept Âges de l’Église* | Implémenté comme livre séparé | 11 chapitres, 376 passages |
| Texte canonique | Conservé | `corpus.db` en lecture seule |
| Recherche lexicale | Implémenté | SQLite FTS5 / BM25 |
| Recherche sémantique | Implémenté, baseline | TF-IDF + LSA 64D, 31 813 documents |
| Fusion hybride | Implémenté | `HybridRanker` + `SearchCoordinator` |
| Analyse de requête | Implémenté | numéro, citation, années, type de source |
| Phrase clé exacte | Implémenté | offsets dans le passage canonique |
| Recherche globale prédications + livre | Implémenté | `searchDocuments` |
| Mode lexical de secours | Implémenté | le bootstrap continue si le pack sémantique échoue |
| Concordance | Implémenté | 59 248 statistiques de termes |
| Chronologie | Implémenté | passages de prédications triés par année/code |
| Passages similaires | Implémenté | 254 504 liens précalculés |
| Comparaison de passages | Implémenté | similarité lexicale et textes canoniques côte à côte |
| Comparaison d’éditions | Implémenté | accès depuis le lecteur pour les 210 prédications concernées |
| Collections | Implémenté | `user.db` local |
| Notes personnelles | Implémenté | affichage séparé du texte canonique |
| Signets par passage | Implémenté | `user.db` |
| Favoris | Implémenté | prédications et livres |
| Reprise de lecture | Implémenté | prédication/édition et livre |
| Recherche dans une prédication | Implémenté | lecteur V3 |
| Données personnelles séparées | Implémenté | `user.db`, migration V2 une fois |
| Installation atomique | Implémenté | `.tmp` → validations → `.bak` → swap/rollback |
| Intégrité SQLite | Implémenté | `integrity_check` hors app + `quick_check` avant swap |
| Zéro génération de texte | Contraint par architecture | moteurs retournent références/scores ; texte résolu dans le corpus |
| Dépendances réseau | Aucune détectée | contrôle statique automatisé |
| Android + Windows | Base Flutter commune | dossiers natifs générés par les scripts/CI avec Flutter 3.35.4 ; non présents dans ce ZIP avant exécution de Flutter |
| `flutter analyze` / `flutter test` local | Non exécuté dans cet environnement | SDK Flutter absent ; CI configurée |
| Builds release Android/Windows | Configurés en CI | doivent être exécutés sur runners Flutter |
| REC-04, 50–100 requêtes métier | Ouvert | validation métier nécessaire avant modèle final |
| Performances sur téléphone 3 Go | Ouvert | mesures appareil réel nécessaires |

## Corpus V3 mesuré

- PDF source : 50 044 pages.
- Prédications : 1 211 distinctes, 1 421 éditions.
- Livre séparé : *Exposé des Sept Âges de l’Église*.
- Passages : 39 679 au total, dont 376 livre.
- Phrases indexées par offsets : 1 572 065.
- Liens de similarité : 254 504.
- Termes de concordance : 59 248.
- Base SQLite : 320 520 192 octets.
- Assets DB : 39 morceaux.
- `PRAGMA integrity_check = ok` et `PRAGMA quick_check = ok` dans la recette V3.

## Ce qui reste volontairement ouvert

1. Exécuter `flutter analyze` et `flutter test` avec Flutter 3.35.4.
2. Produire et lancer l’APK release sur le téléphone Android de référence, cible minimale 3 Go RAM.
3. Produire et lancer le build Windows release.
4. Mesurer démarrage, recherche chaude médiane/P95 et consommation mémoire.
5. Constituer 50 à 100 requêtes métier de référence et mesurer le top-5.
6. Comparer le baseline LSA actuel à un embedding compact ONNX avant tout remplacement du moteur sémantique.
