# Audit technique — moteur d’étude certifiante

**Projet :** Le Grenier du Message — V4 IR Expert  
**Date :** 4 octobre 2026  
**Branche :** feature/certifying-study-engine  
**Statut :** audit préalable à l’architecture ; aucune implémentation du moteur de certification dans ce document.

## 1. Résumé exécutif

Le dépôt possède déjà une base très solide pour construire un moteur d’étude certifiante 100 % hors connexion : corpus SQLite canonique, moteur IR déterministe, lecteur avec navigation exacte par passage/offset, base utilisateur locale, notes, signets, collections, surlignages persistants, impression PDF et CI Android/Windows.

La mission ne doit cependant pas être implémentée comme un simple quiz au-dessus de l’existant. Trois écarts structurants doivent être résolus avant toute génération industrielle :

1. **Les passages SQLite ne sont pas des paragraphes pédagogiques.** Le corpus est découpé en blocs de 1 800 à 4 800 caractères, souvent composés de plusieurs blocs/paragraphes canoniques joints par doubles sauts de ligne.
2. **Le dépôt ne contient pas de texte biblique local structuré.** Il possède un détecteur de références bibliques dans le texte des prédications, mais aucune table ou ressource de versets vérifiée permettant de citer le texte biblique.
3. **La progression utilisateur actuelle ne mesure pas une étude réelle.** Le lecteur mémorise une position de lecture par édition, mais il n’existe pas encore de progression par paragraphe, sections pédagogiques, exercices, examens ou certifications.

L’architecture proposée doit donc ajouter une couche d’étude **séparée du corpus canonique** afin de ne jamais modifier le texte source ni son hash.

---

## 2. Technologies et runtime actuels

### Application

- Flutter, package : le_grenier_du_message
- Version actuelle : 4.0.0+4
- Dart SDK : >= 3.4.0 < 4.0.0
- Flutter CI : 3.35.4 stable
- Plateformes validées : Android ARM64 et Windows x64
- SQLite local via sqlite3 / sqlite3_flutter_libs
- SharedPreferences pour certains réglages historiques
- PDF local via pdf + printing
- Navigation de lecture via scrollable_positioned_list
- Aucun package HTTP/cloud dans le runtime V4

### Garanties runtime V4 existantes

Le garde-fou tools/v4_runtime_guard.py interdit notamment :

- chargement du modèle LSA historique au runtime ;
- client HTTP/Dio dans le graphe V4 ;
- assets sémantiques LSA flottants ;
- permission INTERNET dans le manifeste release.

Conséquence : le futur moteur d’étude doit rester utilisable localement. Toute génération par IA doit être une étape de construction externe, jamais une dépendance obligatoire au runtime Flutter.

---

## 3. Corpus principal

### Packaging

Le corpus est fourni sous forme de base SQLite reconstruite localement :

- fichier logique : corpus.db
- taille : 320 528 384 octets
- découpage Flutter : 39 parties
- empreinte SHA-256 : a485c3831209ec1c788b09918db003693b3745d02a9890053c3a2da12710f5ee
- hash canonique des textes : fff2085e1d6ec5ec18e40273fb83a19cbee01fbad1171d98f00208b0dec00611
- schéma corpus : V4

CorpusInstaller reconstruit les morceaux, vérifie taille, SHA-256, PRAGMA quick_check et version du schéma, puis effectue un swap last-known-good. Le dépôt ne dépend donc pas d’un téléchargement réseau au démarrage.

### Inventaire validé

D’après assets/corpus/manifest.json :

- 1 211 prédications uniques
- 1 421 éditions
- 39 679 passages
- 31 437 passages d’éditions principales
- 50 044 pages du PDF source
- 1 source de type livre
- 376 passages de livre
- 1 572 065 unités de type sentence
- 210 prédications possèdent plusieurs éditions

La source livre intégrée est l’Exposé des Sept Âges de l’Église.

### Structure source

Les prédications sont issues d’un PDF source de 50 044 pages. Le pipeline extrait les éditions et construit les sermons à partir des signets du PDF.

Le rapport reports/sermons.json contient notamment :

- sermon_code
- title
- edition_ids
- edition_count
- primary_edition_id

Exemple constaté :

- code : 47-0412
- titre : La Foi Est l'Assurance
- édition principale : 47-0412__std__p00003

### Métadonnées de date

La table sermons expose actuellement :

- id
- code
- title
- year
- edition_count
- primary_edition_id

Le jour et le mois ne sont pas stockés comme champs structurés. Une date exacte peut être dérivée uniquement lorsque le code suit réellement le motif YY-MMDD avec un mois/jour valide. Certains codes tels que 48-0000 ne permettent pas de produire une date exacte.

**Règle future :** ne jamais inventer une date. Stocker une précision de date : exact / année seulement / inconnue.

---

## 4. Granularité des textes et paragraphes

Le pipeline historique tools/corpus_pipeline/build_database.py découpe le texte canonique avec les contraintes suivantes :

- TARGET_CHARS = 3 600
- MIN_CHARS = 1 800
- MAX_CHARS = 4 800

Les blocs extraits d’une page sont conservés et joints par deux sauts de ligne dans text_display.

La table passages contient :

- id
- edition_id
- sermon_id
- ordinal
- source_page_start
- source_page_end
- text_display
- ainsi que les extensions V3/V4 : source_id, source_type, book_chapter_id

Conclusion importante : **un passage SQLite n’est pas équivalent à un paragraphe de brochure.**

Cependant, les doubles sauts de ligne préservés dans text_display permettent de dériver des unités plus fines sans modifier le corpus. Pour la certification, il faudra créer des « study paragraphs » avec offsets exacts dans le passage canonique.

La table sentences, créée à partir des éditions principales et du livre, stocke déjà :

- sentence_id
- passage_id
- ordinal
- start_offset
- end_offset

Elle peut servir pour la preuve fine, mais ne remplace pas le découpage en paragraphes/segments d’étude.

---

## 5. Moteur IR V4

Le runtime utilise SearchServiceV4 + SearchCoordinatorV4.

Fonctions observées :

- FTS5 / BM25
- phrase exacte
- proximité
- préfixes
- morphologie sûre
- variantes orthographiques
- expansion conceptuelle déterministe
- filtres par année/source
- suppression des éditions alternatives lorsqu’une édition principale pertinente existe
- explication de la raison du classement
- localisation d’une phrase canonique exacte par offsets

Le résultat documentaire DocumentSearchHit conserve :

- StudyPassage
- score
- highlightSentence
- highlightStartOffset
- highlightEndOffset

Cette architecture est directement réutilisable comme couche de recherche de preuves pour les Study Packs.

### Autorité documentaire

Le moteur ne produit pas de réponse doctrinale générative. Il renvoie des passages du corpus avec leur score et leurs preuves. C’est compatible avec l’exigence « le corpus est la source d’autorité ».

---

## 6. Références bibliques : état réel du dépôt

Le fichier lib/src/study_v4/scripture_reference_engine.dart fournit :

- une regex de détection des noms de livres bibliques en français ;
- extraction de références telles que Jean 3:16 ;
- recherche des occurrences de cette chaîne dans passages.text_display.

### Limite critique

Aucune ressource Bible distincte n’a été trouvée dans :

- assets
- corpus.db tel qu’exposé par les repositories/outils
- dépendances Flutter
- arborescence du projet

Il n’existe actuellement ni BibleProvider, ni bible_books, ni bible_verses, ni pack de traduction biblique versionné.

Donc l’application sait actuellement répondre à :

> « Où cette référence biblique apparaît-elle dans le corpus ? »

mais pas de manière sourcée à :

> « Quel est le texte canonique de ce verset dans la traduction biblique de l’application ? »

### Conséquence pour la mission

Avant de publier des questions exigeant le contenu textuel d’un verset, il faudra intégrer un **Bible Pack local vérifié**, avec :

- traduction clairement identifiée ;
- licence/source autorisant l’embarquement ;
- hash du texte ;
- livres/chapitres/versets structurés ;
- version ;
- validation de référence.

Sans ce pack, les questions bibliques devront se limiter à ce que la prédication elle-même cite ou affirme explicitement. Le pipeline devra placer toute question dépendant d’un texte biblique absent en needs_review/rejected.

---

## 7. Lecteur de prédications

ReaderScreen :

- charge les éditions d’une prédication ;
- reprend la position par édition ;
- utilise ScrollablePositionedList ;
- peut changer d’édition ;
- permet de rechercher dans la prédication ;
- gère les favoris ;
- permet signet, collection, passages similaires, comparaison d’éditions et copie ;
- peut ouvrir précisément un passage et des offsets.

La position enregistrée est actuellement un ordinal de passage, pas une progression d’étude par paragraphe.

Passage_navigation permet déjà d’ouvrir une prédication à :

- passage_id exact ;
- ordinal ;
- highlightStartOffset ;
- highlightEndOffset.

Cette capacité est idéale pour le bouton « Voir dans la prédication » exigé par le futur moteur d’étude.

---

## 8. Surlignages et notes

user.db est distinct du corpus canonique.

Le schéma utilisateur est actuellement V5. Il contient notamment :

- favorites
- passage_bookmarks
- collections
- collection_items
- user_notes
- reading_positions
- search_history
- study_history
- comparison_history
- conversations
- conversation_turns
- conversation_hits
- conversation_ui_state
- passage_highlights

Les surlignages stockent :

- passage_id
- start_offset
- end_offset
- highlighted_text
- created_at
- updated_at

Le texte canonique n’est pas réécrit.

Le lecteur permet désormais :

- sélectionner un extrait ;
- le surligner ;
- le retirer ;
- consulter l’historique ;
- rouvrir exactement le passage.

La future section « Mes passages importants » peut donc être construite sans duplication en filtrant passage_highlights selon les passage_id de la prédication.

Les notes personnelles existent déjà par passage et sont indexées FTS localement.

---

## 9. Progression actuelle

La seule progression de lecture existante est reading_positions :

- edition_id
- ordinal
- updated_at

Elle permet une reprise de position, mais ne permet pas de prouver qu’une section a été réellement lue.

Il n’existe actuellement aucune table pour :

- pourcentage de lecture d’une prédication ;
- paragraphes vus/lus ;
- temps d’étude actif ;
- sections pédagogiques terminées ;
- réponses formatives ;
- tentatives d’examen ;
- scores par catégorie ;
- certifications.

Une migration user.db sera donc nécessaire pendant l’implémentation.

---

## 10. Synchronisation

Le runtime V4 est volontairement 100 % hors ligne et ne contient actuellement aucun client réseau.

Aucun mécanisme de synchronisation distante opérationnel des données utilisateur n’a été identifié dans ce dépôt.

La nouvelle architecture doit donc être :

1. entièrement fonctionnelle sans synchronisation ;
2. conçue avec des identifiants stables et timestamps permettant une future synchronisation ;
3. ne pas introduire un service cloud obligatoire.

---

## 11. Performance et chargement

Points favorables :

- corpus ouvert en read-only ;
- FTS5 local ;
- caches de sermons ;
- accès par IDs ;
- assets vérifiés puis installés localement ;
- UI récente utilisant le rendu paresseux pour les longues listes ;
- aucune analyse globale requise au démarrage.

Point à préserver : le futur système ne doit jamais charger ou analyser 1 211 Study Packs au bootstrap.

---

## 12. Tests et CI existants

La CI actuelle exécute :

1. v4_runtime_guard.py
2. validate_v4_release.py
3. flutter analyze
4. flutter test
5. build Android ARM64
6. validation APK Android 15, signature et alignement 16 KB
7. build Windows x64

Le dernier produit avant cette branche possède une suite Flutter verte comprenant les tests de :

- navigation exacte par passage ;
- offsets ;
- moteur d’étude documentaire ;
- persistance user.db ;
- migration V4 → V5 ;
- surlignages ;
- UI Grenier ;
- PDF.

La branche de certification doit étendre cette CI, pas la contourner.

---

## 13. Risques identifiés

### R1 — Confondre passages techniques et paragraphes

Risque critique. Une certification basée uniquement sur les 39 679 passages serait trop grossière.

**Réponse :** dériver des study paragraphs canoniques par offsets, sans toucher corpus.db.

### R2 — Inventer une Bible qui n’est pas dans le dépôt

Risque critique documentaire.

**Réponse :** Bible Pack local obligatoire avant toute question nécessitant le texte d’un verset.

### R3 — Génération automatique non vérifiée

Un LLM peut produire une question plausible mais non démontrable.

**Réponse :** aucune proposition ne devient published sans validation mécanique + règles de preuve ; les classes ambiguës doivent nécessiter revue humaine.

### R4 — Faire gonfler corpus.db

Le hash canonique est une garantie de release.

**Réponse :** Study Packs dans une base séparée, versionnée et remplaçable.

### R5 — Certification trop facile à mémoriser

**Réponse :** banque importante, quotas par catégorie, randomisation, exclusion des questions récentes et distracteurs validés.

### R6 — Progression artificielle

Ouvrir un écran ne prouve pas une lecture.

**Réponse :** progression par unités réellement parcourues + temps actif + contrôle de section.

### R7 — Questions libres impossibles à noter sérieusement offline

**Réponse :** distinguer questions formatives et questions certifiantes ; n’auto-noter que les formats dont le barème est vérifiable localement, ou fournir une rubrique structurée strictement validée.

---

## 14. Conclusion d’audit

Le projet est techniquement prêt pour accueillir un moteur générique d’étude certifiante, mais la bonne architecture doit :

- préserver corpus.db comme autorité canonique immuable ;
- créer une granularité pédagogique dérivée et traçable ;
- stocker les Study Packs dans un paquet indépendant ;
- étendre user.db pour la progression et la certification ;
- ajouter un vrai Bible Pack avant toute comparaison biblique textuelle ;
- utiliser V4 IR Expert comme moteur de preuve, pas comme générateur de vérité ;
- pré-générer et valider les packs avant distribution ;
- commencer par un prototype multi-profils de prédications, puis industrialiser.

Cet audit sert de base à la spécification technique associée.


---

## 15. Tranche de correction 25 % — 4 octobre 2026

Première tranche appliquée après audit :

- correction du filtre des fins éditoriales du pipeline Study Pack et restauration des marqueurs manquants ;
- réévaluation de l’éligibilité à l’examen au moment exact où une tentative démarre ;
- liaison stricte entre les questions tirées et les scores soumis ;
- calcul du résultat final par le moteur de scoring, sans paramètre `passed` fourni par l’appelant ;
- réévaluation de l’éligibilité avant émission du certificat ;
- ajout du hash canonique du corpus et du pourcentage de lecture dans la matière d’intégrité du certificat ;
- fermeture des ressources SQLite partiellement ouvertes lorsqu’un bootstrap échoue ou que le widget est démonté.

Cette tranche ne publie encore aucun Study Pack et ne branche pas encore le parcours de certification à l’interface. Ces étapes restent volontairement bloquées jusqu’à validation du pipeline et du prototype sur corpus réel.


## 16. Tranche de correction 50 % — packaging et intégration runtime

La deuxième tranche ajoute :

- un paquet Study Pack local reproductible, strictement lié à
  `corpus_version` et `canonical_text_sha256` ;
- installation atomique et validation SHA-256/SQLite avant ouverture ;
- exposition de `StudyPackRepository` et `StudyProgressRepository` dans
  `AppScope` ;
- accès « Étudier & obtenir la certification » depuis chaque lecteur de
  prédication ;
- écran d’accueil d’étude avec progression, sections, temps actif et état
  d’éligibilité à l’examen ;
- lecteur certifiant basé sur le texte canonique exact, avec vérification du
  hash de chaque paragraphe avant affichage ;
- progression pondérée par caractères, visibilité réelle du viewport et temps
  actif uniquement lorsque l’application est au premier plan ;
- progression de section calculée à partir des paragraphes réellement lus ;
- extension du garde-fou offline aux écrans et services de certification ;
- tests de contrat du packaging et du branchement runtime.

Le paquet fondation ne publie volontairement aucune question ni certification.
Les Study Packs pédagogiques ne pourront être marqués `published` qu’après la
phase de génération/validation documentaire.
