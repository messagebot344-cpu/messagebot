# Message Bot V4 — IR Expert, 100 % hors ligne, zéro modèle IA

**Date :** 21 septembre 2026  
**Statut :** spécification de conception soumise à validation  
**Base :** Message Bot V3 FINAL consolidé  
**Cible :** Android + Windows, Flutter 3.35.4  


## Identité officielle et Avant-propos

Le nom public officiel du logiciel est **Message Bot**. Toute chaîne utilisateur, titre de fenêtre, écran d’accueil, barre latérale, entête d’impression/PDF, page À propos et documentation utilisateur doivent afficher **Message Bot**. Les anciens noms ne doivent plus apparaître dans l’interface livrée. Les identifiants techniques internes peuvent rester inchangés lorsqu’un renommage apporterait un risque de régression sans bénéfice utilisateur.

Une rubrique **Avant-propos** est obligatoire dans l’application. Elle affiche exactement les informations suivantes, sans les reformuler :

> Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI  
> 242 069101357  
> ebassombi@gmail.com

Ces informations doivent également figurer discrètement dans les documents imprimés/PDF produits par l’application. Cette identité éditoriale ne modifie en rien le corpus canonique, les prédications, les index ou les fonctions de recherche.

## 1. Intention

La V4 doit rendre *Message Bot* sensiblement plus puissant pour la recherche et l'étude, tout en conservant **toutes les fonctions V3**, le fonctionnement **100 % hors ligne**, et une contrainte renforcée : **aucun modèle IA, aucun modèle neuronal, aucun modèle latent de type LSA, aucune génération ou reformulation de texte**.

Le système reste un moteur documentaire. Il retrouve, classe, relie et expose uniquement des textes déjà présents dans le corpus canonique ou des données personnelles explicitement saisies par l'utilisateur.

La V4 adopte une **interface conversationnelle inspirée de ChatGPT**, mais ne devient pas un assistant génératif. La conversation est uniquement une présentation moderne du moteur de recherche d'information (*Information Retrieval*) explicable, déterministe et spécialisé dans le corpus : chaque « réponse » est un ensemble structuré de citations canoniques classées, jamais un texte rédigé par la machine.

## 2. Décisions non négociables

1. Toutes les fonctions V3 restent disponibles.
2. Lecture, recherche, concordance, chronologie, comparaison, passages similaires, collections, notes, favoris, signets et livre restent utilisables sans réseau.
3. Le texte canonique des prédications et du livre n'est jamais modifié par la V4.
4. Aucun texte doctrinal n'est généré, complété, résumé ou reformulé.
5. Aucun LLM, embedding neuronal, ONNX, service distant ou API réseau n'est requis.
6. Le LSA 64 dimensions de la V3 est retiré du chemin d'exécution V4.
7. Le classement V4 repose uniquement sur des algorithmes déterministes et des statistiques documentaires explicables.
8. Les notes personnelles sont toujours visuellement et techniquement séparées du corpus canonique.
9. `corpus.db` reste en lecture seule dans l'application ; `user.db` reste la base modifiable.
10. Toute mise à jour du corpus reste versionnée, vérifiée par empreinte et installée atomiquement.
11. La V4 doit rester utilisable sur l'appareil Android de référence à 3 Go de RAM minimum.
12. Aucun accès réseau ne doit être nécessaire après installation, y compris pour les fonctions nouvelles.
13. L’interface conversationnelle validée et sa maquette de référence sont obligatoires sur Android et Windows.
14. Tous les résultats pertinents d’une recherche sont présentés dans le message documentaire par ordre de pertinence ; le rendu peut être virtualisé mais pas tronqué fonctionnellement.
15. Les conversations et leur contexte structuré sont persistés uniquement dans `user.db`.
16. L’impression et l’export PDF fonctionnent localement pour un passage, une recherche complète et une conversation complète.

## 3. État V3 réellement observé

La V3 sépare déjà correctement plusieurs responsabilités :

- `QueryAnalyzer` détecte code de prédication, année, source et citation entre guillemets.
- `LexicalSearchEngine` lance des recherches FTS5 fortes et larges, plus les éditions alternatives et correspondances directes.
- `SemanticSearchEngine` s'appuie actuellement sur `SemanticIndex` TF-IDF + LSA 64D.
- `HybridRanker` fusionne lexical, sémantique et correspondances directes avec une variante de RRF.
- `SearchCoordinator` filtre ensuite source, année, doublons et résout la phrase pertinente.
- `StudyEngine`, `SimilarityEngine`, `ConcordanceEngine` et `ComparisonEngine` exposent les fonctions d'étude.
- Le corpus V3 contient les prédications, le livre *Exposé des Sept Âges de l'Église*, les phrases, les statistiques de termes et les relations de voisinage.

La V4 conserve cette modularité mais remplace la dépendance au LSA par plusieurs moteurs IR spécialisés.

## 4. Architecture cible

La recherche V4 suit cette chaîne :

```text
Requête utilisateur
  ↓
QueryParserV4
  ↓
Normalizer + Morphology + SafeAliases
  ↓
┌───────────────────────────────────────────────────────────────┐
│ DirectLookup │ ExactPhrase │ BM25 │ NEAR │ SentenceFTS      │
│ Prefix       │ Fuzzy      │ Filters │ AlternateEditions     │
└───────────────────────────────────────────────────────────────┘
  ↓
DeterministicHybridRanker
  ↓
Diversification + Deduplication
  ↓
CanonicalSentenceLocator
  ↓
PassageReference + SearchExplanation
  ↓
CorpusRepository → texte canonique
```

Les fonctions d'étude utilisent les mêmes primitives, mais ne passent pas nécessairement par le classement complet :

```text
Concordance → FTS/KWIC
Chronologie → occurrences normalisées par année
Passages similaires → voisins IR précalculés
Formulations parallèles → empreintes n-grammes
Références bibliques → parseur déterministe + index
Comparaison → texte canonique + diff local
```


## 4A. Contrat d’interface conversationnelle — référence visuelle obligatoire

La maquette validée le 21 septembre 2026 devient la **référence officielle de design V4**. L’implémentation Android et Windows doit reproduire sa hiérarchie, son organisation et son langage visuel aussi fidèlement que possible, sans sacrifier l’accessibilité, le responsive ou la fidélité documentaire.

Référence visuelle : `a_clean_high_resolution_ui_mockup_composite_image.png`.

### 4A.1 Principe

La recherche est présentée sous forme de conversation :

- la requête utilisateur apparaît comme un message envoyé ;
- le moteur renvoie un **message documentaire** « Message Bot » ;
- ce message contient **tous les résultats dépassant le seuil de pertinence**, classés du plus pertinent au moins pertinent ;
- aucun résultat pertinent ne doit être masqué derrière un bouton « voir plus » ;
- l’interface peut virtualiser/lazy-render les cartes pendant le défilement pour préserver la mémoire ;
- chaque résultat reste une citation exacte du corpus et peut être ouvert au passage source.

### 4A.2 Démarrage et champ de recherche

Sur une nouvelle conversation vide :

- le logo/livre et le nom « Message Bot » occupent la zone centrale ;
- le message « Toute Sa Parole. Toujours avec vous. Hors ligne. » est visible ;
- le champ de recherche est centré dans l’écran ;
- un indicateur « 100 % hors ligne » et « Aucune IA générative » est visible.

Dès le premier message :

- la zone de saisie se fixe en bas de la conversation ;
- la conversation devient scrollable ;
- `Entrée`/bouton Envoyer lance la recherche ;
- le champ reste disponible pour une recherche suivante dans le même fil.

### 4A.3 Structure d’un message résultat

Chaque réponse documentaire affiche :

1. le nombre total de passages pertinents trouvés ;
2. le périmètre de recherche ;
3. les filtres actifs sous forme de chips supprimables ;
4. toutes les cartes de résultat, numérotées `1..N`, dans l’ordre de pertinence ;
5. pour chaque résultat :
   - rang ;
   - libellé qualitatif de pertinence (`Très pertinent`, `Pertinent`, `Correspondance partielle`) ;
   - phrase clé/citation mise en évidence ;
   - extrait contextuel suffisamment large ;
   - titre de la source ;
   - code de prédication si applicable ;
   - date/année si disponible ;
   - page source ;
   - indication « Livre » ou « édition alternative » si nécessaire ;
   - actions `Développer`, `Ouvrir`, `Comparer`, `Passages similaires`, `Ajouter à une collection`, `Copier`, `Imprimer`.

Aucun pourcentage de « confiance » n’est affiché comme s’il s’agissait d’une probabilité. Les niveaux de pertinence reposent sur des seuils de score documentaires reproductibles.

### 4A.4 Développement du passage

Une carte affiche par défaut un extrait autour de la phrase trouvée. `Développer` étend la carte **dans la conversation** et montre le passage complet. `Ouvrir` navigue vers le lecteur canonique exactement au bon passage.

### 4A.5 Continuité de conversation sans IA

Les messages suivants peuvent hériter uniquement de **filtres structurés et explicites** : thème/termes, période, type de source, prédication ou livre.

Exemple :

```text
Message 1 : mariage
Message 2 : après 1960
Message 3 : uniquement dans les prédications
```

Le système conserve alors visiblement :

```text
Sujet : mariage • Période : 1960–1965 • Source : prédications
```

Chaque filtre est supprimable individuellement. Aucun contexte implicite non représenté dans les filtres structurés n’est appliqué. Une requête manifestement complète peut remplacer le sujet précédent tout en gardant uniquement les filtres explicitement compatibles.

### 4A.6 Conversations locales

Les conversations sont enregistrées automatiquement dans `user.db`. Elles ne quittent jamais l’appareil. Une conversation conserve au minimum :

- `id` stable ;
- titre local déterministe issu de la première recherche, modifiable manuellement ;
- date de création et dernière modification ;
- état épinglé ;
- messages utilisateur ;
- filtres structurés de chaque recherche ;
- ordre des résultats et identifiants de passages ;
- cartes développées ;
- position de défilement/reprise lorsque possible.

La barre latérale Windows affiche `Nouvelle conversation`, puis les conversations récentes regroupées par `Aujourd’hui`, `7 derniers jours`, `30 derniers jours`, `Plus ancien`, avec `Renommer`, `Épingler`, `Supprimer` et recherche locale dans les conversations.

Sur Android, un bouton ouvre ce même historique dans un drawer/panneau adapté au petit écran.

### 4A.7 Navigation globale

La V4 conserve toutes les fonctions V3/V4 et les rend accessibles depuis la navigation principale :

- Accueil / Nouvelle conversation ;
- Bibliothèque ;
- Conversations ;
- Collections ;
- Notes ;
- Concordance ;
- Chronologie ;
- Comparer ;
- Références bibliques ;
- Réglages.

Sur Windows large, cette navigation est une barre latérale fixe bleu nuit conforme à la maquette. Sur mobile, elle est adaptée en navigation inférieure + drawer/panneau secondaire afin de ne pas réduire la zone de lecture.

### 4A.8 Panneau de détails Windows

Sur les grands écrans, sélectionner une carte peut ouvrir un panneau droit affichant :

- référence complète ;
- page et paragraphe/ordinal ;
- niveau de pertinence ;
- contexte plus large ;
- actions `Voir le passage complet` et `Ouvrir dans le lecteur` ;
- section Impression/Export.

Sur mobile, les mêmes informations s’ouvrent dans une page/bottom sheet dédiée.

### 4A.9 Impression et export PDF

Trois niveaux d’impression sont obligatoires :

1. **Ce passage** ;
2. **Tous les résultats de cette recherche**, dans leur ordre de pertinence ;
3. **Toute la conversation d’étude**.

Le flux comprend `Aperçu avant impression`, `Imprimer` et `Enregistrer en PDF`. Le document imprimé doit contenir : titre « Message Bot », requête, filtres, citations, rangs, titres des sources, codes/dates/pages et date d’impression. Les notes personnelles ne sont incluses que sur choix explicite et sont visuellement marquées `NOTE PERSONNELLE`, distinctes du corpus.

L’impression n’utilise aucun service réseau.

### 4A.10 Identité visuelle

La référence visuelle fixe :

- bleu nuit pour la navigation principale ;
- bleu franc pour les actions et messages utilisateur ;
- surfaces de contenu claires et aérées ;
- cartes de résultats bordées, avec rang visible ;
- surlignage discret des mots correspondants ;
- pictogramme livre comme marque principale ;
- badges « 100 % hors ligne » et « Aucune IA générative » ;
- responsive Android/Windows ;
- thème sombre conservé, en traduisant cette même hiérarchie visuelle.

La maquette est un contrat de hiérarchie et de composition, pas une permission pour sacrifier contraste, taille minimale des zones tactiles ou navigation clavier Windows.

## 5. Suppression du modèle LSA du runtime

### 5.1 Éléments retirés du chemin principal

La V4 ne doit plus charger :

- `semantic_vocab.json`
- `semantic_components.f32`
- `semantic_vectors.f32`
- `semantic_passage_ids.i32`

`SemanticIndex` et `SemanticSearchEngine` ne participent plus à la recherche V4.

Les anciens assets peuvent être supprimés du paquet V4 final après validation de non-régression. La migration ne supprime aucun texte canonique.

### 5.2 Compatibilité transitoire

Pendant le développement, la V3 peut rester disponible derrière un moteur de référence utilisé uniquement par les tests comparatifs hors application. Le binaire V4 final ne doit pas dépendre de ce moteur.

## 6. Normalisation documentaire

Un composant unique `TextNormalizer` devient l'autorité pour la recherche.

Il doit :

- convertir en minuscules pour l'index de recherche ;
- normaliser les apostrophes typographiques ;
- gérer accents et diacritiques sans modifier le texte affiché ;
- normaliser `œ → oe`, `æ → ae` ;
- conserver les chiffres utiles aux codes et références ;
- filtrer les mots fonctionnels uniquement pour certaines voies de classement ;
- produire une liste de tokens stable et reproductible ;
- fournir une variante accent-insensitive et une variante exacte.

Le texte canonique reste stocké séparément et n'est jamais reconstruit depuis le texte normalisé.

## 7. Analyse de requête V4

`QueryAnalyzer` évolue en `QueryParserV4` avec une grammaire déterministe.

### 7.1 Formes reconnues

- texte libre : `foi parfaite`
- phrase exacte : `"Dieu dans la simplicité"`
- code : `65-1207`
- année : `1963`
- période : `après 1960`, `avant 1964`, `1960..1965`
- source : `dans:predications`, `dans:livre`
- inclusion obligatoire : `+foi`
- exclusion : `-guerison`
- opérateurs explicites : `AND`, `OR`
- recherche interne : contexte fourni par l'écran de lecture

### 7.2 Règles

La syntaxe avancée ne doit pas empêcher une requête naturelle simple de fonctionner.

Les erreurs de syntaxe doivent retomber sur une recherche texte libre, jamais faire planter la recherche.

### 7.3 Résultat du parseur

```dart
class QueryIntentV4 {
  final String raw;
  final String normalized;
  final String? exactPhrase;
  final String? sermonCode;
  final int? yearMin;
  final int? yearMax;
  final SourceFilter sourceFilter;
  final Set<String> requiredTerms;
  final Set<String> excludedTerms;
  final List<List<String>> orGroups;
  final QueryKind kind;
}
```

## 8. Moteurs de récupération déterministes

### 8.1 Direct lookup

Priorité maximale aux :

- codes de prédication ;
- titres exacts ;
- titres commençant par la requête ;
- titres du livre/chapitre.

### 8.2 Citation exacte

Une phrase entre guillemets utilise FTS5 phrase query et reçoit la priorité la plus forte après un code/titre exact.

La carte de résultat doit indiquer `Citation exacte trouvée`.

### 8.3 BM25

FTS5/BM25 reste le moteur lexical principal.

Deux variantes sont conservées :

- `strong` : couverture élevée / AND ;
- `broad` : couverture partielle / OR.

Le score brut BM25 n'est jamais présenté comme une probabilité.

### 8.4 Proximité FTS5 NEAR

Pour 2 à 6 termes significatifs, le moteur construit des requêtes `NEAR(...)` avec plusieurs fenêtres :

- fenêtre courte : forte priorité ;
- fenêtre moyenne : priorité intermédiaire ;
- présence dispersée : BM25 standard.

Le passage où les termes sont regroupés doit battre celui où ils sont dispersés, à pertinence lexicale comparable.

### 8.5 Index phrase

Créer `sentences_search` + `sentences_fts` pour indexer les phrases des éditions principales et du livre.

Le texte canonique de phrase n'est pas dupliqué comme autorité d'affichage : `sentences` conserve les offsets dans `passages.text_display`.

`sentences_search` contient uniquement la représentation normalisée destinée à l'index.

Le pipeline :

1. rechercher les passages ;
2. rechercher les phrases ;
3. fusionner les preuves ;
4. récupérer la phrase canonique à partir des offsets.

### 8.6 Préfixes

FTS5 doit utiliser un index de préfixes adapté aux mesures du corpus, par exemple `prefix='2 3 4'` si le benchmark confirme son intérêt.

Aucune valeur n'est figée sans mesure de taille et de vitesse.

### 8.7 Recherche floue

La tolérance aux fautes se fait en deux étapes :

1. génération d'un petit ensemble de candidats depuis un index trigramme des termes du corpus ;
2. classement par distance de Damerau-Levenshtein normalisée.

La correction ne remplace jamais silencieusement la requête.

UI :

```text
Résultats pour « bapteme »
Terme proche détecté : « baptême »
```

Le terme original reste visible.

## 9. Morphologie et variantes sûres

La V4 ajoute un `MorphologyEngine` déterministe.

Il gère :

- variantes d'accents ;
- pluriel/singulier simple ;
- élisions françaises ;
- familles verbales ou nominales explicitement validées ;
- variantes typographiques fréquentes.

Le moteur ne doit pas inventer des relations doctrinales.

Deux catégories de liens existent :

### 9.1 Alias sûrs

Peuvent être appliqués automatiquement :

- orthographe/diacritique ;
- formes grammaticales manifestement équivalentes ;
- variantes éditoriales documentées.

### 9.2 Termes associés

Ne sont pas injectés automatiquement dans la recherche principale.

Ils apparaissent sous :

`Élargir la recherche avec…`

L'utilisateur choisit explicitement.

## 10. Thésaurus local contrôlé

Créer des tables :

```sql
search_terms(term_id, canonical_term, term_type)
search_aliases(term_id, alias, alias_type, confidence_class)
term_associations(term_a, term_b, association_score, support_count)
```

`search_aliases` est versionné avec le corpus.

`term_associations` est produit statistiquement depuis le corpus par cooccurrence ; il sert uniquement aux suggestions d'exploration.

## 11. Termes associés sans IA

Le pipeline de préparation calcule des associations par :

- cooccurrence dans une fenêtre de tokens ;
- fréquence conditionnelle ;
- Dice ou PMI filtré par support minimal.

Les associations avec faible support sont exclues.

L'interface les présente comme :

`Termes souvent rencontrés près de « mariage »`

et jamais comme synonymes ou équivalences doctrinales.

## 12. Classement V4 explicable

`HybridRanker` devient `DeterministicHybridRanker`.

### 12.1 Signaux

- correspondance code/titre ;
- phrase exacte ;
- BM25 strong ;
- BM25 broad ;
- NEAR court ;
- NEAR moyen ;
- phrase FTS ;
- couverture des termes ;
- nombre de termes rares ;
- édition principale ;
- source demandée ;
- correction floue éventuelle ;
- exclusion de termes ;
- pénalité de quasi-doublon.

### 12.2 Fusion

La première implémentation utilise RRF pondéré, car elle est stable quand les échelles de score diffèrent.

Les poids sont constants, documentés et couverts par tests.

Ils pourront être calibrés sur le jeu de requêtes métier, sans apprentissage automatique.

### 12.3 Seuil de résultat

Le système n'utilise plus un seuil LSA.

Il retourne `aucun résultat suffisamment pertinent` si :

- aucune correspondance directe ;
- aucun résultat exact/NEAR/strong ;
- couverture lexicale trop faible ;
- les seuls candidats viennent d'expansions faibles ou floues.

Les règles doivent être testables et explicables.

## 13. « Pourquoi ce résultat ? »

Chaque `PassageReference` reçoit un `SearchExplanation` structuré.

Exemples de preuves :

- `Titre exact`
- `Citation exacte`
- `5/6 termes présents`
- `4 termes dans la même phrase`
- `Terme rare : adoption`
- `Variante orthographique : bapteme → baptême`
- `Édition principale`

Aucune phrase doctrinale n'est produite.

L'UI affiche ces preuves dans un panneau repliable.

## 14. Déduplication et diversification

La V4 conserve la logique des éditions V3 et l'améliore.

Règles :

1. une édition principale est préférée ;
2. une édition alternative identique/quasi identique ne prend pas une place séparée ;
3. une édition alternative substantiellement différente peut apparaître ;
4. les dix premiers résultats ne doivent pas être saturés par plusieurs passages consécutifs de la même prédication si d'autres documents pertinents existent.

La diversification est déterministe et ne modifie pas les scores bruts conservés pour explication.

## 15. Passages similaires sans modèle

Les relations V3 basées sur LSA sont remplacées par `passage_neighbors_ir`.

### 15.1 Représentation sparse

Pour chaque passage canonique :

- top termes TF-IDF ;
- termes rares ;
- bigrammes/trigrammes discriminants ;
- empreintes de shingles ;
- statistiques de longueur.

Créer :

```sql
passage_terms(passage_id, term_id, tfidf_weight, term_rank)
passage_ngrams(passage_id, ngram_hash, n, weight)
passage_neighbors_ir(source_passage_id, neighbor_passage_id, score, relation_scope, method_version)
```

### 15.2 Similarité

Le score de préparation combine :

- cosine sparse TF-IDF ;
- Jaccard pondéré des termes forts ;
- n-grammes communs ;
- bonus d'expressions communes ;
- pénalité pour contenus quasi identiques si l'objectif est la diversité.

Le calcul lourd est hors application.

Le téléphone ne lit que les voisins précalculés.

### 15.3 Migration

`passage_neighbors` V3 reste présent pendant la construction de validation, puis est remplacé dans le paquet final V4 si les tests de couverture passent.

## 16. Formulations parallèles

Ajouter un moteur distinct des « passages similaires ».

Objectif : retrouver des formulations textuellement proches ou répétées.

Préparation :

- shingles de 5 à 12 tokens ;
- empreintes roulantes ;
- suppression des shingles trop fréquents ;
- index inversé `shingle → passages`.

Tables :

```sql
parallel_phrases(
  source_passage_id,
  target_passage_id,
  shared_token_count,
  longest_shared_run,
  similarity_score
)
```

UI : `Formulations parallèles`.

Le résultat montre les textes côte à côte avec les segments réellement communs surlignés.

## 17. Références bibliques explicites

Créer un parseur déterministe qui reconnaît uniquement les références explicitement présentes dans le corpus.

Exemples :

- `Jean 3:16`
- `Jean 3.16`
- `Jn 3:16` si l'abréviation est explicitement supportée par le dictionnaire
- plages de versets documentées

Le parseur n'infère jamais une référence absente du texte.

Tables :

```sql
bible_books(book_id, canonical_name, normalized_name)
bible_book_aliases(book_id, alias)
scripture_references(
  reference_id,
  passage_id,
  book_id,
  chapter,
  verse_start,
  verse_end,
  raw_reference,
  start_offset,
  end_offset
)
```

Fonctions :

- toutes les références d'une prédication ;
- toutes les occurrences de `Jean 3:16` ;
- filtrage par livre biblique ;
- chronologie d'une référence explicite.

Aucun texte biblique externe n'est ajouté par cette fonction.

## 18. Concordance KWIC

La concordance V4 ajoute un mode *Key Word In Context*.

Pour chaque occurrence :

```text
… quelques mots avant [TERME] quelques mots après …
```

La fenêtre est construite depuis `text_display`, pas depuis une reformulation.

Fonctions :

- pagination ;
- filtre source ;
- filtre année ;
- tri chronologique ou documentaire ;
- ouverture exacte du passage.

## 19. Concordance croisée

Ajouter :

- `A ET B`
- `A OU B`
- `A SANS B`
- distance maximale optionnelle entre A et B.

Exemple : `foi ET guérison`.

La vue montre :

- nombre de passages ;
- nombre de prédications ;
- occurrences par année ;
- passages sources.

Aucune conclusion n'est calculée.

## 20. Chronologie quantitative normalisée

La chronologie V4 conserve les résultats existants et ajoute :

- nombre brut d'occurrences ;
- nombre de documents concernés ;
- occurrences pour 100 000 tokens par année.

La normalisation évite qu'une année très volumineuse paraisse automatiquement plus importante.

Tables de préparation :

```sql
corpus_year_stats(year, document_count, token_count)
term_year_stats(term_id, year, document_count, occurrence_count)
```

L'UI doit toujours distinguer `occurrences brutes` et `occurrences normalisées`.

## 21. Recherche dans les notes personnelles

`user.db` reçoit un FTS5 séparé pour les données saisies par l'utilisateur.

Indexables :

- notes ;
- titres de collections ;
- éventuels libellés utilisateur.

La recherche globale propose trois scopes visuellement distincts :

- `Corpus`
- `Mes notes`
- `Tout`

Une note n'est jamais affichée comme citation du corpus.

## 22. Recherche interne à une prédication ou un livre

La fonction V3 est conservée et passe au moteur V4 avec restriction de source avant classement.

La recherche interne supporte :

- exact ;
- proximité ;
- phrase ;
- fuzzy ;
- navigation occurrence suivante/précédente.

## 23. Index FTS et schéma V4

### 23.1 `passages_fts_v4`

Le nouvel index doit être construit à partir du texte normalisé de recherche, avec options mesurées pour :

- unicode61 ;
- remove_diacritics ;
- préfixes ;
- external/contentless si cela réduit réellement la taille sans dégrader l'usage.

Le choix final de tokenizer et prefix est décidé par benchmark, mais reste purement algorithmique.

### 23.2 `sentences_fts`

Index des phrases, lié aux offsets canoniques.

### 23.3 `terms_trigram_fts`

Index de vocabulaire destiné à la récupération des candidats flous.

## 24. Performance et mémoire

### 24.1 Objectifs

- recherche chaude : cible < 1 s sur appareil de référence ;
- ouverture résultat : perceptuellement immédiate ;
- KWIC 100 occurrences : cible < 300 ms à chaud ;
- passages similaires : lecture des voisins précalculés, cible < 100 ms ;
- aucun chargement d'un gros tableau vectoriel en RAM.

### 24.2 Mémoire

La V4 supprime les tableaux Float32 LSA du runtime.

Les structures en mémoire doivent rester bornées :

- cache de termes/fuzzy limité ;
- cache LRU de résultats ;
- chargement paginé des concordances ;
- pas de chargement global des 1,57 M phrases.

### 24.3 Benchmarks obligatoires

Mesurer :

- cold start ;
- hot search ;
- requête exacte ;
- requête longue ;
- typo ;
- filtre année ;
- concordance ;
- recherche notes ;
- mémoire de pointe.

## 25. Taille du paquet

La suppression des assets LSA libère de l'espace.

Les nouveaux index ne doivent pas annuler cet avantage sans justification mesurée.

Le pipeline produit un rapport :

```json
{
  "canonical_db_bytes": 0,
  "fts_bytes": 0,
  "sentence_index_bytes": 0,
  "fuzzy_index_bytes": 0,
  "neighbors_ir_bytes": 0,
  "scripture_index_bytes": 0,
  "final_pack_bytes": 0
}
```

## 26. Installation et intégrité

`CorpusInstaller` V3 est conservé.

Le paquet V4 doit vérifier :

1. version du manifeste ;
2. taille ;
3. SHA-256 par morceau ;
4. SHA-256 final ;
5. `PRAGMA quick_check` ;
6. version de schéma ;
7. présence des tables V4 obligatoires.

Le remplacement reste atomique : temporaire → validation → sauvegarde → bascule.

En cas d'échec, restauration du dernier corpus valide.

## 27. Garantie 100 % hors ligne

### 27.1 Dépendances

Aucune dépendance réseau n'est ajoutée.

La CI effectue un scan des imports et dépendances pour détecter :

- `http` ;
- `dio` ;
- WebSocket ;
- sockets ;
- clients cloud ;
- SDK d'IA.

### 27.2 Android

Le manifeste release ne doit pas demander la permission `android.permission.INTERNET`.

Si Flutter ou un outil de développement en ajoute une au manifeste debug, le build release doit être vérifié séparément.

### 27.3 Tests mode avion

La recette manuelle Android et Windows inclut :

- installation ;
- lancement sans réseau ;
- recherche ;
- lecture ;
- étude ;
- notes ;
- redémarrage.

## 28. UI V4

Toutes les pages V3 restent présentes.

Ajouts :

### Recherche

- panneau de filtres avancés ;
- badge `Exact`, `Proximité`, `Titre`, `Variante`, etc. ;
- bouton `Pourquoi ce résultat ?` ;
- suggestions `Élargir avec…` ;
- indication d'une correction orthographique proposée.

### Étudier

Nouvelles entrées :

- `Formulations parallèles`
- `Références bibliques`
- `Concordance croisée`
- `Termes associés`

### Concordance

- mode liste ;
- mode KWIC ;
- filtres ;
- export local de références si déjà permis par les règles de copie.

### Chronologie

- bascule `Brut / pour 100 000 mots` ;
- clic sur une année → passages exacts.

### Recherche personnelle

- scope `Corpus / Mes notes / Tout` ;
- styles distincts.

## 29. Compatibilité fonctionnelle V3

La V4 ne peut être déclarée valide si une de ces fonctions régresse :

- accueil ;
- recherche simple ;
- recherche titre/code ;
- recherche par question naturelle ;
- bibliothèque ;
- lecture intégrale ;
- ouverture au passage ;
- favoris ;
- historique ;
- thème clair/sombre ;
- taille du texte ;
- reprise de lecture ;
- éditions alternatives ;
- livre séparé ;
- concordance ;
- chronologie ;
- passages similaires ;
- comparaison ;
- collections ;
- notes ;
- signets de passage ;
- intégrité du corpus ;
- fonctionnement hors ligne.

## 30. Migration V3 → V4

### 30.1 Données personnelles

`user.db` est conservé.

Les migrations sont additives et versionnées.

Aucune collection, note, position de lecture, favori ou historique ne doit être supprimé.

### 30.2 Corpus

Le corpus canonique V3 est la source de la V4.

Les nouveaux index sont reconstruits hors application.

Un test compare les empreintes du texte d'affichage V3 et V4 : elles doivent être identiques pour les passages existants.

### 30.3 Identifiants

Les identifiants existants de prédications, éditions, passages, sources et chapitres restent stables.

Les nouveaux objets reçoivent des identifiants séparés et ne renumérotent pas les entités V3.

## 31. Pipeline de préparation V4

Le pipeline Python est décomposé en étapes reproductibles :

1. copier/ouvrir le corpus V3 validé ;
2. vérifier l'intégrité canonique ;
3. construire normalisation V4 ;
4. reconstruire `passages_fts_v4` ;
5. construire `sentences_search` + `sentences_fts` ;
6. construire vocabulaire/fuzzy ;
7. construire familles morphologiques/alias sûrs ;
8. calculer associations de termes ;
9. construire top termes TF-IDF sparse ;
10. calculer voisins IR ;
11. calculer formulations parallèles ;
12. extraire références bibliques explicites ;
13. construire statistiques annuelles ;
14. exécuter contrôles d'intégrité ;
15. produire manifeste et rapports ;
16. découper le corpus en morceaux ;
17. vérifier la reconstruction depuis les morceaux.

Chaque étape doit pouvoir échouer explicitement sans produire un paquet marqué valide.

## 32. Tests unitaires

### QueryParserV4

- citation exacte ;
- code ;
- année ;
- période ;
- source ;
- exclusion ;
- syntaxe invalide → fallback texte libre.

### TextNormalizer

- accents ;
- apostrophes ;
- ligatures ;
- chiffres ;
- stabilité.

### MorphologyEngine

- variantes sûres ;
- aucune expansion doctrinale implicite.

### FuzzyTermMatcher

- faute simple ;
- transposition ;
- accent manquant ;
- terme trop éloigné rejeté.

### DeterministicHybridRanker

- exact > proximity > broad ;
- direct title/code prioritaire ;
- exclusion respectée ;
- édition principale préférée ;
- diversification.

### CanonicalSentenceLocator

- la phrase retournée est une sous-chaîne exacte de `text_display`.

### SimilarityEngineV4

- voisins issus de `passage_neighbors_ir` ;
- aucun accès aux assets LSA.

### ScriptureReferenceParser

- références reconnues ;
- variantes ;
- faux positifs rejetés.

### KWIC

- fenêtre exacte ;
- terme surligné ;
- texte provenant du canon.

## 33. Tests d'intégration

Scénarios minimum :

1. recherche exacte ;
2. recherche avec faute ;
3. recherche par proximité ;
4. recherche conceptuelle avec vocabulaire présent ;
5. requête hors corpus ;
6. filtre année ;
7. filtre livre ;
8. édition alternative ;
9. passage similaire ;
10. formulation parallèle ;
11. référence biblique ;
12. concordance KWIC ;
13. note personnelle recherchable ;
14. ouverture exacte dans lecteur ;
15. redémarrage sans perte user.db.

## 34. Jeu de référence de pertinence

Conserver le critère REC-04 du cahier et créer un jeu versionné de 50 à 100 requêtes validées métier.

Catégories :

- citations exactes ;
- formulations proches ;
- concepts avec vocabulaire commun ;
- titres ;
- codes ;
- dates ;
- fautes ;
- références bibliques ;
- requêtes ambiguës ;
- requêtes sans réponse.

Comparer :

- V3 lexical seul ;
- V3 complet ;
- V4 IR Expert.

La V4 n'est pas acceptée si elle améliore les nouvelles fonctions mais dégrade matériellement les requêtes de base déjà correctes.

## 35. Mesures de réussite

La V4 est considérée prête lorsque :

1. toutes les fonctions V3 passent leurs tests de non-régression ;
2. aucune dépendance LSA/IA n'est nécessaire au runtime ;
3. recherche exacte, proximité, phrase, fuzzy et filtres sont opérationnels ;
4. `Pourquoi ce résultat ?` reflète réellement les preuves du classement ;
5. passages similaires fonctionnent via IR sparse précalculé ;
6. formulations parallèles fonctionnent ;
7. références bibliques explicites sont indexées ;
8. KWIC et concordance croisée fonctionnent ;
9. notes personnelles sont recherchables séparément ;
10. texte canonique V3/V4 est invariant ;
11. corpus V4 passe `integrity_check` et `quick_check` ;
12. le paquet se reconstruit depuis ses morceaux avec SHA-256 exact ;
13. aucune permission réseau n'est requise en release ;
14. les tests Flutter et builds Android/Windows passent dans l'environnement Flutter de référence ;
15. la recette hors ligne passe sur appareils réels.

## 36. Fichiers Flutter prévus

Créations principales :

```text
lib/src/search_v4/query_parser_v4.dart
lib/src/search_v4/text_normalizer.dart
lib/src/search_v4/morphology_engine.dart
lib/src/search_v4/fuzzy_term_matcher.dart
lib/src/search_v4/retrieval_bundle.dart
lib/src/search_v4/exact_phrase_engine.dart
lib/src/search_v4/proximity_search_engine.dart
lib/src/search_v4/sentence_search_engine.dart
lib/src/search_v4/deterministic_hybrid_ranker.dart
lib/src/search_v4/search_explanation.dart
lib/src/search_v4/search_coordinator_v4.dart
lib/src/study_v4/parallel_phrase_engine.dart
lib/src/study_v4/scripture_reference_engine.dart
lib/src/study_v4/kwic_engine.dart
lib/src/study_v4/cross_concordance_engine.dart
lib/src/study_v4/term_association_engine.dart
lib/src/personal/user_search_engine.dart
```

Modifications principales :

```text
lib/src/app_scope.dart
lib/src/services/corpus_repository.dart
lib/src/services/search_service.dart
lib/src/study/similarity_engine.dart
lib/src/study/study_engine.dart
lib/src/screens/search_screen.dart
lib/src/screens/search_results_screen.dart
lib/src/screens/study_screen.dart
lib/src/screens/concordance_screen.dart
lib/src/screens/timeline_screen.dart
lib/src/screens/reader_screen.dart
lib/src/personal/user_database.dart
lib/src/personal/personal_library.dart
```

## 37. Outils de préparation prévus

```text
tools/build_v4_corpus.py
tools/v4_text_normalization.py
tools/v4_fuzzy_index.py
tools/v4_morphology.py
tools/v4_term_associations.py
tools/v4_sparse_neighbors.py
tools/v4_parallel_phrases.py
tools/v4_scripture_refs.py
tools/v4_year_stats.py
tools/test_v4_corpus.py
tools/validate_v4_release.py
```

Les fichiers peuvent être regroupés si le résultat reste plus clair et testable ; aucune classe monolithique ne doit remplacer la modularité V3.

## 38. Stratégie de livraison

La V4 doit être livrée en étapes internes testables :

1. moteur lexical V4 + query parser ;
2. fuzzy/morphologie ;
3. phrase/proximité + explications ;
4. voisinage IR sans LSA ;
5. formulations parallèles ;
6. références bibliques ;
7. KWIC/concordance croisée/chronologie normalisée ;
8. recherche user.db ;
9. UI ;
10. migration et recette globale ;
11. packaging final.

Chaque étape conserve la possibilité de revenir à la dernière version verte du moteur V4 pendant le développement.

## 39. Limites assumées

Sans modèle sémantique, la V4 ne prétend pas reconnaître de façon fiable deux passages conceptuellement proches qui n'ont aucun vocabulaire, aucune variante morphologique, aucune expression ni aucun lien lexical en commun.

Cette limite est volontaire. La V4 privilégie :

- exactitude ;
- explicabilité ;
- reproductibilité ;
- fonctionnement hors ligne ;
- absence totale de modèle IA ;
- fidélité documentaire.

Les suggestions de termes associés et le thésaurus contrôlé réduisent cette limite sans introduire de modèle opaque.

## 40. Conclusion de conception

La V4 transforme *Message Bot* en moteur documentaire expert entièrement déterministe.

La puissance supplémentaire ne vient pas d'un modèle IA, mais de la combinaison coordonnée de :

- FTS5/BM25 ;
- phrases exactes ;
- proximité ;
- index de phrases ;
- recherche floue ;
- morphologie ;
- thésaurus contrôlé ;
- statistiques de cooccurrence ;
- TF-IDF sparse ;
- n-grammes et shingles ;
- références bibliques explicites ;
- concordance KWIC ;
- chronologie normalisée ;
- classement et explications déterministes.

Le texte affiché reste toujours celui du corpus canonique ou celui explicitement saisi par l'utilisateur dans ses notes.
