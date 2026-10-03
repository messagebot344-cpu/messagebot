# Le Grenier du Message — Spécification de conception V3

**Date :** 20 septembre 2026  
**Statut :** conception approuvée en conversation, à relire par le porteur du projet avant plan d’implémentation  
**Base :** V2 consolidée  
**Plateformes :** Android et Windows  
**Mode :** 100 % hors ligne pour les fonctions principales  
**Principe non négociable :** zéro génération de texte doctrinal ou de réponse synthétique

## 1. Objet

La V3 doit transformer *Le Grenier du Message* en un moteur documentaire et un environnement d’étude beaucoup plus puissants, tout en conservant une fidélité absolue au corpus canonique.

L’application doit permettre de :

1. retrouver un passage même lorsque l’utilisateur ne connaît pas les mots exacts employés dans la prédication ;
2. retrouver avec priorité les citations exactes lorsqu’elles existent ;
3. explorer les passages proches, les occurrences, les prédications et les périodes ;
4. comparer des passages et des éditions sans produire d’interprétation doctrinale ;
5. organiser une étude personnelle locale avec signets, collections et notes ;
6. intégrer proprement plusieurs types de sources, notamment les prédications et l’*Exposé des Sept Âges de l’Église* ;
7. fonctionner efficacement sur un téléphone Android de **3 Go de RAM minimum** et sur Windows ;
8. rendre techniquement impossible qu’un moteur sémantique rédige une réponse à la place du corpus.

## 2. Décisions de conception approuvées

### 2.1 Fidélité absolue

La V3 reste dans le mode **A — fidélité absolue** :

- aucun LLM conversationnel ;
- aucune réponse générée ;
- aucune reformulation doctrinale ;
- aucun résumé automatique présenté comme enseignement ;
- aucun correctif automatique du texte canonique ;
- les moteurs intelligents peuvent seulement produire des identifiants, scores, métadonnées, classements ou relations entre éléments du corpus ;
- tout texte doctrinal présenté à l’utilisateur doit être lu depuis la source canonique validée.

### 2.2 Priorités fonctionnelles

Les trois priorités sont retenues simultanément :

1. **Recherche extrêmement précise** ;
2. **Étude approfondie** ;
3. **Intégration cohérente recherche + étude**.

### 2.3 Cible matérielle

La cible Android de référence est un appareil disposant de **3 Go de RAM minimum**. Les objectifs de performance définitifs devront être mesurés sur un appareil réel représentatif de cette cible.

## 3. État de départ V2

La V2 consolidée sert de base technique. Elle contient notamment :

- 1 211 prédications distinctes ;
- 1 421 éditions physiques ;
- 210 prédications comportant deux éditions ;
- 39 303 passages SQLite ;
- 31 437 passages de l’édition principale dans l’index sémantique ;
- recherche lexicale SQLite FTS5 ;
- moteur TF-IDF + LSA 64 dimensions ;
- recherche des éditions alternatives en secours lexical ;
- fusion de résultats ;
- sélection d’une phrase existante ;
- favoris, historique, thème, taille de texte et reprise de lecture ;
- base canonique vérifiée par SHA-256 et ouverte en lecture seule ;
- fonctionnement prévu hors ligne ;
- application Flutter commune Android/Windows.

Le LSA actuel est conservé comme **baseline mesurable** et comme solution de repli pendant la transition, mais il ne doit pas être considéré comme le moteur sémantique définitif de la V3 sans comparaison expérimentale.

## 4. Objectifs et non-objectifs

### 4.1 Objectifs

La V3 doit :

- mieux comprendre la proximité de sens entre une requête et le corpus ;
- préserver la supériorité des correspondances exactes et lexicales lorsqu’elles sont fortes ;
- réduire les faux positifs ;
- regrouper les doublons et quasi-doublons ;
- retrouver une phrase précise à l’intérieur d’un passage ;
- proposer des passages similaires instantanément ;
- permettre la concordance, la chronologie et la comparaison ;
- isoler les données personnelles des données canoniques ;
- permettre des mises à jour de packs indépendants ;
- rester robuste après interruption, manque d’espace ou mise à jour partielle.

### 4.2 Non-objectifs

La V3 ne doit pas :

- produire une réponse doctrinale ;
- interpréter les changements d’enseignement entre dates ;
- déclarer que deux citations « signifient la même chose » ;
- corriger le texte canonique ;
- imposer un thème doctrinal comme vérité ;
- exiger un compte, un serveur, une API ou une connexion Internet pour lire, rechercher ou étudier ;
- mélanger artificiellement les livres/exposés avec le nombre de prédications.

## 5. Invariants de sécurité documentaire

Ces invariants doivent être imposés par l’architecture et testés automatiquement.

### INV-01 — Texte canonique immuable

`corpus.db` est en lecture seule pendant l’utilisation normale. Les passages affichés et copiés proviennent directement des champs canoniques validés.

### INV-02 — Aucun moteur de recherche ne retourne de texte libre

Les interfaces de recherche retournent des références structurées, par exemple :

```text
PassageReference(
  sourceId,
  editionId,
  passageId,
  sentenceId?,
  score,
  evidence
)
```

Elles ne retournent jamais une chaîne de caractères représentant une réponse générée.

### INV-03 — Le texte affiché est résolu après le classement

L’interface récupère le texte seulement après avoir reçu un `passageId` ou `sentenceId`, via `CanonicalCorpus`.

### INV-04 — Notes utilisateur clairement séparées

Une note personnelle doit être stockée dans `user.db` et visuellement identifiée comme « Note personnelle ». Elle ne doit jamais être fusionnée avec le texte canonique.

### INV-05 — Index de recherche séparés

Les formes normalisées, tokens, embeddings, clusters et thèmes servent à retrouver des sources. Ils ne remplacent jamais `text_display`.

## 6. Architecture logique cible

La logique V3 est divisée en modules spécialisés afin d’éviter que `SearchService` concentre progressivement toutes les responsabilités.

### 6.1 `CanonicalCorpus`

Responsabilités :

- lecture du texte canonique ;
- accès aux prédications, éditions, passages, phrases et métadonnées ;
- résolution des pages source ;
- exposition d’identifiants stables ;
- aucun classement et aucune donnée personnelle.

### 6.2 `LexicalSearchEngine`

Responsabilités :

- recherche exacte ;
- FTS5/BM25 ;
- proximité lexicale ;
- recherche par titre ;
- recherche par numéro/code ;
- recherche de termes ou expressions ;
- correspondance dans les éditions alternatives.

### 6.3 `SemanticSearchEngine`

Responsabilités :

- encoder localement la requête en vecteur ;
- charger ou mapper les vecteurs précalculés ;
- sélectionner les clusters candidats ;
- calculer les similarités ;
- retourner des identifiants et scores seulement.

### 6.4 `QueryAnalyzer`

Responsabilités :

- normalisation Unicode et accents ;
- détection d’une citation exacte ;
- détection d’un code de prédication ;
- détection d’un titre probable ;
- extraction de filtres explicites comme année ou type de source ;
- estimation du type de requête : exacte, lexicale, conceptuelle, mixte.

Il s’agit d’un composant déterministe ou statistique non génératif.

### 6.5 `HybridRanker`

Responsabilités :

- fusionner les candidats ;
- appliquer Reciprocal Rank Fusion ou une variante documentée ;
- utiliser les signaux lexicaux, sémantiques, titres, numéros, proximité et couverture ;
- pénaliser les doublons ;
- privilégier l’édition canonique lorsqu’elle est suffisante ;
- appliquer le seuil de confiance calibré.

### 6.6 `SentenceLocator`

Responsabilités :

- trouver la phrase exacte la plus pertinente dans les meilleurs passages ;
- travailler sur des offsets canoniques ;
- garantir que la phrase surlignée est un sous-texte exact du passage canonique.

### 6.7 `SimilarityEngine`

Responsabilités :

- fournir les voisins précalculés d’un passage ;
- distinguer même prédication / autres prédications ;
- filtrer les quasi-doublons ;
- ne jamais déclarer une équivalence doctrinale.

### 6.8 `ConcordanceEngine`

Responsabilités :

- statistiques de termes et expressions ;
- nombre d’occurrences ;
- nombre de prédications concernées ;
- navigation vers les occurrences ;
- filtres chronologiques.

### 6.9 `StudyEngine`

Responsabilités :

- chronologie de résultats ;
- comparaison de passages ;
- comparaison d’éditions ;
- exploration de thèmes de recherche ;
- orchestration des outils d’étude sans écrire de synthèse.

### 6.10 `PersonalLibrary`

Responsabilités :

- favoris ;
- signets de passages ;
- collections ;
- notes personnelles ;
- historique ;
- progression de lecture ;
- dernières études et comparaisons.

### 6.11 `CorpusInstaller`

Responsabilités :

- installation en streaming ;
- vérification SHA-256 progressive ;
- contrôle de compatibilité de schéma ;
- installation atomique ;
- reprise après interruption ;
- conservation du dernier pack valide.

### 6.12 `Reader`

Responsabilités :

- rendu du texte canonique ;
- navigation au passage ;
- taille de texte ;
- thème ;
- sélection/copie ;
- signet de passage ;
- accès aux outils d’étude sans modifier le texte.

## 7. Pipeline de recherche V3

Le pipeline complet est :

```text
Requête utilisateur
  ↓
QueryAnalyzer
  ↓
Exact / titre / numéro / FTS5-BM25 / embedding local
  ↓
Candidats indépendants
  ↓
HybridRanker
  ↓
Déduplication et diversité
  ↓
Top 20–50 passages
  ↓
SentenceLocator
  ↓
Seuil de confiance
  ↓
PassageReference + SentenceReference
  ↓
CanonicalCorpus
  ↓
Texte exact affiché
```

### 7.1 Priorité des requêtes exactes

Lorsqu’une expression exacte ou un code fiable est détecté, la correspondance exacte doit conserver une priorité supérieure à une proximité sémantique approximative.

### 7.2 Recherche lexicale

FTS5 reste la base lexicale. La V3 ajoute :

- requêtes exactes protégées ;
- AND/OR adaptés au nombre de termes ;
- proximité de tokens ;
- pondération des termes rares ;
- filtres année/source/édition ;
- contrôle de couverture des mots significatifs.

### 7.3 Recherche sémantique

Le moteur LSA V2 est comparé à un ou plusieurs modèles d’embedding compacts. Le modèle final n’est retenu qu’après mesures.

Critères de sélection :

- pertinence sur le jeu de référence ;
- qualité en français ;
- poids du modèle ;
- RAM ;
- latence d’encodage ;
- licence de redistribution ;
- support Android et Windows ;
- possibilité de quantification ;
- absence de fonction générative nécessaire.

Cible indicative : 256 à 384 dimensions et modèle quantifié idéalement inférieur ou égal à 80 Mo. Cette cible est un budget d’ingénierie, pas une contrainte absolue avant benchmark.

### 7.4 Recherche vectorielle hiérarchique

Les vecteurs de passages sont précalculés sur poste de préparation.

Le runtime utilise deux niveaux :

1. comparaison avec les centroïdes de clusters ;
2. comparaison fine uniquement dans les meilleurs clusters.

L’objectif est d’éviter de charger ou comparer inutilement tout le corpus pour chaque requête.

### 7.5 Recherche phrase après passage

La V3 ne fait pas une recherche globale coûteuse parmi toutes les phrases.

Elle :

1. sélectionne les meilleurs passages ;
2. charge les phrases de ces passages ;
3. classe les phrases candidates ;
4. retourne l’offset exact de la meilleure phrase.

## 8. Données et schéma cible

### 8.1 `corpus.db`

Base canonique en lecture seule.

Tables principales prévues :

- `sources`
- `sermons`
- `editions`
- `passages`
- `sentences`
- `passage_search`
- `source_metadata`
- `passage_neighbors`
- `term_stats`
- `expression_stats`
- `semantic_clusters`
- `corpus_metadata`

Les champs exacts seront détaillés dans le plan d’implémentation et les migrations.

### 8.2 Table `sentences`

Chaque phrase contient au minimum :

- `sentence_id`
- `passage_id`
- `ordinal`
- `start_offset`
- `end_offset`

Le texte n’est pas dupliqué si les offsets permettent de le reconstruire exactement depuis le passage canonique.

### 8.3 `user.db`

Base locale modifiable séparée de `corpus.db`.

Tables prévues :

- `favorites`
- `passage_bookmarks`
- `collections`
- `collection_items`
- `user_notes`
- `reading_positions`
- `search_history`
- `study_history`
- `comparison_history`
- `user_preferences`

Une mise à jour du corpus ne doit jamais supprimer ou écraser `user.db`.

## 9. Gestion des éditions multiples

Pour les prédications possédant plusieurs éditions :

1. une édition canonique de recherche est désignée explicitement ;
2. les éditions alternatives restent accessibles ;
3. une édition alternative peut remonter si elle apporte un résultat absent de l’édition canonique ;
4. les doublons ou quasi-doublons sont regroupés ;
5. l’interface indique le nombre d’éditions disponibles ;
6. le mode comparaison affiche les deux textes sans synthèse.

Le critère de sélection de l’édition canonique doit être documenté et reproductible, pas déduit implicitement d’un préfixe de nom de fichier.

## 10. Passages similaires

Les voisins sont précalculés sur poste de préparation.

Pour chaque passage canonique, on stocke un nombre limité de voisins utiles avec :

- `source_passage_id`
- `neighbor_passage_id`
- `similarity_score`
- `relation_scope` : même prédication / autre prédication
- `model_version`

L’interface emploie la formulation neutre **« Passages similaires »** ou **« Passages proches dans le corpus »**.

Elle n’emploie pas de formulation interprétative telle que « même doctrine » ou « même enseignement ».

## 11. Concordance et expressions

La concordance expose :

- terme ;
- fréquence totale ;
- nombre de prédications ;
- distribution par année ;
- accès aux occurrences ;
- expressions fréquentes associées.

La V3 réutilise FTS5 et des tables d’agrégats pour éviter une duplication massive de chaque occurrence.

Les statistiques détaillées doivent être calculables à la demande.

## 12. Chronologie

La chronologie ne conclut pas qu’un enseignement « évolue » ou « change ».

Elle affiche seulement :

- date/année ;
- prédication ;
- passage exact ;
- score ou critère de correspondance ;
- filtres de période.

L’utilisateur reste responsable de l’interprétation.

## 13. Comparaison

### 13.1 Comparaison de passages

La V3 permet de sélectionner deux passages et de les afficher côte à côte sur Windows ou successivement sur mobile.

Elle peut calculer :

- mots communs ;
- différences textuelles ;
- similarité numérique ;
- positions communes.

Elle ne doit pas produire une conclusion doctrinale.

### 13.2 Comparaison d’éditions

Le mode édition affiche :

- édition A ;
- édition B ;
- différences de ponctuation ;
- différences de mots ;
- blocs absents/ajoutés ;
- pages source.

Les différences doivent être calculées sur le texte réel sans correction silencieuse.

## 14. Thèmes de recherche

Des catégories automatiques ou semi-automatiques peuvent être générées pendant la préparation du corpus.

Contraintes :

- nommées **« Thèmes de recherche »** ;
- utilisées comme aides de navigation ;
- jamais présentées comme classification doctrinale officielle ;
- chaque thème mène vers des passages exacts ;
- les règles/modèles ayant produit les thèmes sont versionnés.

## 15. Collections et étude personnelle

L’utilisateur peut créer des collections locales telles que « Mariage », « Foi » ou « Baptême ».

Une collection peut contenir :

- passage exact ;
- référence ;
- page ;
- date ;
- note personnelle facultative ;
- ordre manuel.

Les notes personnelles sont explicitement séparées du corpus par le stockage et par l’interface.

## 16. Sources multiples

La V3 introduit `CorpusSource`.

Types initiaux :

- `SermonSource`
- `BookSource`

L’*Exposé des Sept Âges de l’Église* est intégré comme `BookSource`, avec chapitres et passages propres. Il n’est pas comptabilisé dans les 1 211 prédications.

La recherche globale offre :

- Tout ;
- Prédications ;
- Livres / Exposés.

## 17. Packs de données

Le paquet V3 est séparé en composants versionnés.

### 17.1 `core-corpus`

Contient :

- texte canonique ;
- métadonnées ;
- FTS ;
- phrases ;
- identifiants.

### 17.2 `semantic-pack`

Contient :

- version du modèle ;
- vecteurs ;
- clusters ;
- centroïdes ;
- voisins précalculés ;
- éventuelles données de reranking.

### 17.3 `book-pack`

Contient les livres/exposés supplémentaires quand ils ne sont pas inclus dans le pack principal.

### 17.4 Manifeste

Chaque pack comporte :

- version ;
- version de schéma ;
- taille ;
- SHA-256 ;
- dépendances de compatibilité ;
- date de génération ;
- version du pipeline ;
- statistiques.

## 18. Installation et mise à jour atomiques

La V3 installe les packs en streaming.

Processus :

1. écrire dans un emplacement temporaire ;
2. calculer l’empreinte au fil de la copie ;
3. vérifier taille et SHA-256 ;
4. vérifier la compatibilité de schéma ;
5. ouvrir la base et exécuter un contrôle rapide d’intégrité ;
6. effectuer un renommage/remplacement atomique ;
7. ne supprimer l’ancienne version qu’après succès.

En cas de fermeture ou d’erreur, la dernière version valide reste disponible.

## 19. Gestion mémoire

Règles :

- le corpus textuel complet n’est jamais chargé en RAM ;
- SQLite reste disque-first ;
- les embeddings de passages sont mappés ou chargés de façon compacte ;
- le modèle sémantique n’est chargé que lorsqu’il est nécessaire ;
- les données de phrases ne sont chargées que pour les meilleurs candidats ;
- les longues prédications sont rendues progressivement ;
- les caches ont des limites explicites et sont évictables.

Les budgets RAM exacts seront décidés après instrumentation sur l’appareil Android 3 Go de référence.

## 20. Interface cible

Navigation principale V3 :

1. **Accueil**
2. **Rechercher**
3. **Bibliothèque**
4. **Étudier**
5. **Favoris**

### 20.1 Espace Étudier

Contient :

- Concordance ;
- Chronologie ;
- Collections ;
- Comparaisons ;
- Passages similaires ;
- Historique d’étude.

### 20.2 Lecteur

Ajouts :

- recherche dans la prédication ;
- signet de passage ;
- ajouter à une collection ;
- passages similaires ;
- comparer ;
- sélectionner une édition ;
- ouvrir la page/source associée quand disponible.

### 20.3 Windows

Utiliser les grands écrans pour :

- navigation latérale ;
- comparaison côte à côte ;
- panneau de résultats + lecteur ;
- raccourcis clavier ;
- navigation accessible au clavier.

## 21. Performance

Les objectifs restent compatibles avec le cahier des charges :

- premier écran utilisable rapidement ;
- recherche chaude ciblée sous une seconde sur l’appareil de référence ;
- mesure de la médiane et du P95 ;
- pas de blocage UI pendant l’encodage ou la recherche ;
- pas de chargement massif en mémoire.

Les cibles définitives sont validées par benchmark réel, pas uniquement par estimation de développement.

## 22. Jeu de référence et choix du modèle

Avant de figer le nouveau moteur sémantique, constituer **50 à 100 requêtes réelles** réparties au minimum en catégories :

- citation exacte ;
- mots-clés ;
- formulation différente ;
- concept ;
- titre ;
- code/numéro ;
- mot rare ;
- question ambiguë ;
- requête sans réponse raisonnable ;
- requête ciblée sur une période ;
- requête ciblée sur une prédication.

Pour chaque requête, les validateurs métier définissent un ou plusieurs passages acceptables sans demander au moteur de produire une réponse.

Comparaison minimale :

1. V2 — FTS5 + LSA 64D ;
2. candidat embedding A ;
3. candidat embedding B si nécessaire ;
4. hybride V3 complet.

Mesures :

- Recall@5 ;
- MRR ;
- taux de faux positifs sur les requêtes sans réponse ;
- latence médiane ;
- P95 ;
- RAM maximale ;
- poids des packs.

Le critère REC-04 du cahier reste la base de recette. Un objectif interne supérieur peut être adopté après mesures, mais ne doit pas être déclaré atteint avant preuve.

## 23. Tests

### 23.1 Tests unitaires

Chaque module doit être testable indépendamment :

- analyse de requête ;
- requête exacte ;
- BM25/FTS ;
- fusion ;
- déduplication ;
- seuil ;
- offsets de phrase ;
- voisins ;
- migration utilisateur ;
- installation atomique.

### 23.2 Tests d’invariants

Tests obligatoires :

- toute phrase surlignée existe exactement dans le passage ;
- tout résultat résout vers un passage canonique existant ;
- aucun texte doctrinal n’est construit par concaténation générative ;
- `corpus.db` reste inchangé après une session normale ;
- `user.db` survit au remplacement du corpus ;
- une interruption d’installation conserve la version précédente ;
- les notes personnelles ne contaminent jamais la recherche canonique.

### 23.3 Tests fonctionnels

Scénarios :

- recherche exacte ;
- recherche conceptuelle ;
- recherche sans résultat ;
- ouverture au bon passage ;
- passages similaires ;
- comparaison ;
- collection ;
- reprise de lecture ;
- mode avion ;
- Windows clavier ;
- Android faible mémoire.

### 23.4 Tests de corpus

À chaque génération :

- `integrity_check` ;
- empreintes ;
- comptages ;
- recherche de caractères invalides ;
- échantillon de fidélité PDF → texte canonique ;
- validation des offsets de phrases ;
- validation des voisins ;
- contrôle du bruit éditorial dans l’index de recherche.

## 24. Gestion des erreurs

### 24.1 Pack manquant ou corrompu

L’application affiche un état technique clair et tente de revenir au dernier pack valide. Elle ne doit jamais ouvrir silencieusement une base partiellement installée.

### 24.2 Modèle sémantique indisponible

La recherche doit continuer en **mode lexical dégradé**. L’application ne doit pas devenir inutilisable parce que l’embedding ne peut pas être chargé.

### 24.3 Mémoire insuffisante

Le moteur libère les caches non essentiels et peut basculer vers lexical + recherche sémantique limitée. Aucun crash volontairement accepté comme comportement normal.

### 24.4 Aucun résultat fiable

Afficher explicitement qu’aucun passage suffisamment pertinent n’a été trouvé et proposer une reformulation ou un filtre différent. Ne jamais forcer un résultat faible.

## 25. Migration V2 → V3

La migration doit être progressive.

### Étape A — Refactor sans changement fonctionnel

Extraire les responsabilités actuelles de `SearchService` vers des interfaces séparées tout en conservant les résultats V2 comme référence.

### Étape B — `user.db`

Migrer favoris, historique, positions et préférences vers une base séparée, avec import unique depuis les mécanismes V2.

### Étape C — phrases et offsets

Ajouter la segmentation en phrases et tester la fidélité exacte.

### Étape D — benchmark embedding

Construire les candidats hors application, mesurer, puis choisir le modèle.

### Étape E — moteur hybride V3

Activer le nouveau classement derrière une interface stable.

### Étape F — étude avancée

Ajouter passages similaires, concordance, chronologie, comparaison et collections.

### Étape G — livres/exposés

Intégrer `BookSource` et l’*Exposé des Sept Âges de l’Église*.

Cette migration limite le risque de casser la V2 en tentant une réécriture complète d’un seul coup.

## 26. Critères d’acceptation V3

La V3 ne peut être qualifiée de prête que si :

1. le texte canonique reste inchangé ;
2. toute phrase clé est un extrait exact ;
3. aucune fonction ne produit de réponse doctrinale générée ;
4. Android et Windows compilent et passent les tests ;
5. le mode avion est validé ;
6. la migration des données personnelles est testée ;
7. une interruption de mise à jour ne détruit pas le corpus valide ;
8. le moteur V3 atteint au minimum le seuil REC-04 sur le jeu métier approuvé ;
9. les performances sont mesurées sur le téléphone 3 Go de référence et le PC Windows de référence ;
10. les fonctionnalités d’étude ne confondent jamais métadonnées, scores, thèmes ou notes avec le texte canonique ;
11. l’*Exposé des Sept Âges de l’Église* est traité comme source de type livre et ne modifie pas le nombre de prédications ;
12. les licences du modèle sémantique et des bibliothèques autorisent la distribution prévue.

## 27. Risques et mesures de maîtrise

| Risque | Mesure |
|---|---|
| Modèle sémantique trop lourd | quantification, benchmark, fallback lexical |
| Mauvais résultats conceptuels | jeu métier 50–100 requêtes, comparaison de modèles |
| Faux sentiment d’interprétation | terminologie neutre, aucun texte généré |
| Doublons entre éditions | clustering/déduplication et regroupement d’éditions |
| Corpus trop volumineux | packs séparés, SQLite disque-first, vecteurs compacts |
| Mise à jour interrompue | installation temporaire + vérification + swap atomique |
| Perte de notes/favoris | `user.db` séparée et migration testée |
| Phrase surlignée incorrecte | offsets exacts + invariant automatisé |
| Régression V2 | baseline V2 conservée et tests de non-régression |
| Licence modèle incompatible | validation de licence avant sélection définitive |

## 28. Décisions différées explicitement

Ces points ne sont **pas** figés par cette spécification et doivent être tranchés par benchmark ou planification :

- nom exact du modèle d’embedding ;
- dimensions définitives ;
- format de quantification ;
- nombre exact de clusters ;
- nombre de voisins pré-calculés par passage ;
- poids exact des signaux de ranking ;
- seuil exact de confiance ;
- budget RAM chiffré final ;
- limites exactes de cache ;
- seuil interne supérieur éventuel à REC-04.

Leur décision dépend des mesures sur le vrai corpus et les appareils de référence.

## 29. Résultat attendu

La V3 doit se comporter comme un **moteur documentaire spécialisé de haute précision** : elle retrouve, classe, relie, compare et expose les sources, mais ne remplace jamais les sources par sa propre formulation.

Le principe architectural final est :

```text
Question
  → analyse technique
  → récupération lexicale et sémantique
  → classement
  → identifiants de sources
  → texte canonique exact
  → contexte, référence et page
```

et jamais :

```text
Question
  → génération d’une réponse doctrinale
```
