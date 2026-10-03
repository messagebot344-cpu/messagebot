# Le Grenier du Message V3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer la V2 en moteur documentaire V3 hors ligne avec architecture de recherche modulaire, outils d’étude, base personnelle séparée et corpus enrichi, tout en garantissant que tout texte doctrinal affiché provient du corpus canonique.

**Architecture:** La V3 sépare lecture canonique, recherche lexicale, recherche sémantique, analyse de requête, classement, localisation de phrase, étude et données personnelles. Le corpus reste un paquet SQLite en lecture seule ; les données utilisateur vont dans `user.db`. Le LSA V2 reste le moteur sémantique de référence tant qu’un embedding candidat n’a pas remporté le benchmark prévu par la spécification.

**Tech Stack:** Flutter/Dart, sqlite3 + FTS5, Python 3, scikit-learn/numpy pour la préparation du corpus, SHA-256, assets binaires locaux, aucune dépendance réseau.

**Spec:** `docs/superpowers/specs/2026-09-20-le-grenier-v3-design.md`

## Global Constraints

- Android et Windows ; fonctions principales 100 % hors ligne.
- Cible Android : 3 Go de RAM minimum.
- Aucun LLM conversationnel, aucune réponse générée, aucune reformulation doctrinale.
- Tout texte doctrinal affiché doit être résolu depuis le corpus canonique après classement.
- `corpus.db` reste en lecture seule au runtime ; `user.db` contient les données personnelles.
- L’Exposé des Sept Âges de l’Église est une source de type livre et ne modifie pas le nombre de prédications.
- Le choix définitif du modèle d’embedding reste différé jusqu’au benchmark 50–100 requêtes métier.
- Le projet doit rester sans dépendance réseau.

## Review Focus

- Une requête exacte ou un code de prédication doit rester prioritaire sur une proximité sémantique approximative.
- Une phrase mise en évidence doit être un sous-texte exact du passage canonique, offsets compris.
- Une édition alternative ne doit pas noyer les résultats lorsque l’édition principale contient déjà le même contenu.
- Une mise à jour ou réinstallation du corpus ne doit jamais supprimer `user.db` ni ouvrir une base temporaire incomplète.
- Une requête hors corpus doit pouvoir retourner zéro résultat au lieu de forcer une correspondance sémantique faible.

---

### Task 1: Contrats V3 de recherche et analyse déterministe de requête

**Files:**
- Create: `lib/src/search/query_analyzer.dart`
- Create: `lib/src/search/search_contracts.dart`
- Create: `test/query_analyzer_test.dart`
- Modify: `lib/src/models/models.dart`

**Interfaces:**
- Consumes: texte utilisateur brut et identifiants existants de passage/édition/prédication.
- Produces: `QueryIntent analyzeQuery(String raw)` et `PassageReference` sans texte doctrinal libre.

- [ ] **Step 1: Write the failing test**

```dart
final analyzer = QueryAnalyzer();
expect(analyzer.analyze('65-1206').sermonCode, '65-1206');
expect(analyzer.analyze('"Dieu dans la simplicité"').exactPhrase, 'Dieu dans la simplicité');
expect(analyzer.analyze('mariage après 1960').yearMin, 1960);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/query_analyzer_test.dart`
Expected: FAIL because `QueryAnalyzer` and V3 contracts do not exist. If Flutter SDK is unavailable in this environment, record that limitation and run `python tools/v3_static_contract_test.py --phase query` expecting failure until files exist.

- [ ] **Step 3: Write minimal implementation**

Create immutable value objects `QueryIntent`, `PassageReference`, `SentenceReference`, `SearchEvidence` and deterministic parsing for quoted phrases, sermon codes, source filters and year bounds. No method returns generated prose.

- [ ] **Step 4: Run test to verify it passes**

Run the same executable verification as Step 2.
Expected: PASS for code, exact phrase, year filter and empty query cases.

- [ ] **Step 5: Commit**

```bash
git add lib/src/search lib/src/models/models.dart test/query_analyzer_test.dart tools/v3_static_contract_test.py
git commit -m "feat: add V3 search contracts and query analyzer"
```

### Task 2: Extraire SearchService en moteurs spécialisés sans régression V2

**Files:**
- Create: `lib/src/search/lexical_search_engine.dart`
- Create: `lib/src/search/semantic_search_engine.dart`
- Create: `lib/src/search/hybrid_ranker.dart`
- Create: `lib/src/search/sentence_locator.dart`
- Create: `lib/src/search/search_coordinator.dart`
- Modify: `lib/src/services/search_service.dart`
- Modify: `lib/src/services/corpus_repository.dart`
- Modify: `test/search_service_test.dart`
- Create: `test/hybrid_ranker_test.dart`
- Create: `test/sentence_locator_test.dart`

**Interfaces:**
- Consumes: `QueryIntent`, lexical candidates, semantic candidates and canonical metadata.
- Produces: `List<PassageReference>` puis résolution canonique en `SearchHit` par le service de compatibilité V2.

- [ ] **Step 1: Write failing tests** for exact/direct priority, RRF ordering, alternative-edition deduplication, semantic-only weak rejection, and exact sentence substring.
- [ ] **Step 2: Run tests** and observe failure because the specialized engines do not exist.
- [ ] **Step 3: Implement minimal engines**. `SemanticSearchEngine` adapts `SemanticIndex`; `LexicalSearchEngine` adapts repository FTS; `HybridRanker` owns weights and confidence; `SentenceLocator` returns offsets/text slices only; `SearchCoordinator` orchestrates. Keep `SearchService.search()` as compatibility façade.
- [ ] **Step 4: Run targeted tests and full test suite**; static fallback checks module boundaries when Flutter is unavailable.
- [ ] **Step 5: Commit** with `feat: modularize V3 hybrid search`.

### Task 3: Enrichir le paquet canonique V3 — sources, livre, phrases, voisins et concordance

**Files:**
- Create: `tools/build_v3_corpus.py`
- Create: `tools/test_v3_corpus.py`
- Modify: `assets/corpus/manifest.json`
- Replace: `assets/corpus/db_parts/corpus.db.part*`
- Regenerate: `assets/corpus/semantic_*`
- Create: `reports/v3_corpus_build.json`
- Create: `reports/v3_corpus_validation.json`

**Interfaces:**
- Consumes: V2 `corpus.db`, PDF source, V2 semantic representation.
- Produces: schema version 3 with `sources`, `sentences`, `passage_neighbors`, `term_stats`, `source_metadata`, livre Exposé, FTS rebuilt, metadata and hashes.

- [ ] **Step 1: Write failing corpus validator** asserting source counts, sentence offset fidelity, book source presence, sermon count still 1211, FTS parity, neighbor referential integrity, and SHA manifest parity.
- [ ] **Step 2: Run validator** against V2 and confirm failure on missing V3 tables/book.
- [ ] **Step 3: Implement builder** that copies V2 DB, adds V3 tables, extracts pages 49668–50044 using Poppler text with chapter boundaries from PDF bookmarks, segments canonical sentences by offsets, computes LSA cosine neighbors for primary sermon and book passages, builds term statistics, rebuilds FTS, updates corpus metadata, rebuilds LSA assets including searchable book passages, VACUUMs and packages parts.
- [ ] **Step 4: Run validator**; expected `integrity_check=ok`, exact sentence offsets, book source present, sermon count unchanged, hashes matching manifest.
- [ ] **Step 5: Commit** with `feat: build V3 canonical corpus and study indexes`.

### Task 4: Séparer les données personnelles dans user.db avec migration V2

**Files:**
- Create: `lib/src/personal/personal_library.dart`
- Create: `lib/src/personal/user_database.dart`
- Create: `test/personal_library_test.dart`
- Modify: `lib/src/services/preferences_service.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/src/app_scope.dart`

**Interfaces:**
- Consumes: application-support directory and legacy SharedPreferences keys.
- Produces: `PersonalLibrary` APIs for favorites, passage bookmarks, collections, notes, reading/search/study history. Appearance preferences may remain in SharedPreferences.

- [ ] **Step 1: Write failing tests** for schema creation, one-time import, duplicate-safe migration, collection/note separation, persistence after corpus path change.
- [ ] **Step 2: Run tests/static fallback** and confirm failure before implementation.
- [ ] **Step 3: Implement SQLite user database** with schema version, transactions and migration marker; never attach or mutate `corpus.db`.
- [ ] **Step 4: Run tests/full checks**.
- [ ] **Step 5: Commit** with `feat: add separate personal study database`.

### Task 5: Implémenter SimilarityEngine, ConcordanceEngine et StudyEngine

**Files:**
- Create: `lib/src/study/similarity_engine.dart`
- Create: `lib/src/study/concordance_engine.dart`
- Create: `lib/src/study/study_engine.dart`
- Create: `lib/src/study/comparison_engine.dart`
- Create: `test/study_engine_test.dart`
- Modify: `lib/src/services/corpus_repository.dart`

**Interfaces:**
- Consumes: V3 tables `passage_neighbors`, `term_stats`, `sentences`, sources and canonical passages.
- Produces: IDs/scores/metadata and deterministic text diffs; no doctrinal summary strings.

- [ ] **Step 1: Write failing tests** for neighbors, concordance counts, chronological ordering, passage diff and source-type filtering.
- [ ] **Step 2: Run and confirm failure**.
- [ ] **Step 3: Implement engines** and repository queries, returning canonical references.
- [ ] **Step 4: Run tests/static + database smoke tests**.
- [ ] **Step 5: Commit** with `feat: add V3 study engines`.

### Task 6: Ajouter l’espace Étudier, comparaisons, collections et lecteur enrichi

**Files:**
- Create: `lib/src/screens/search_screen.dart`
- Create: `lib/src/screens/study_screen.dart`
- Create: `lib/src/screens/concordance_screen.dart`
- Create: `lib/src/screens/timeline_screen.dart`
- Create: `lib/src/screens/similar_passages_screen.dart`
- Create: `lib/src/screens/comparison_screen.dart`
- Create: `lib/src/screens/collections_screen.dart`
- Modify: `lib/src/screens/shell_screen.dart`
- Modify: `lib/src/screens/reader_screen.dart`
- Modify: `lib/src/screens/library_screen.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Modify: `lib/src/app_scope.dart`

**Interfaces:**
- Consumes: SearchCoordinator/SearchService, StudyEngine, PersonalLibrary, Canonical corpus repository.
- Produces: navigation `Accueil / Rechercher / Bibliothèque / Étudier / Favoris`, study workflows, passage bookmarks/collections, source filters, edition comparison and in-sermon search.

- [ ] **Step 1: Write widget/static contract tests** requiring five destinations, canonical-only result rendering, personal-note labels and book filter.
- [ ] **Step 2: Run and observe failure**.
- [ ] **Step 3: Implement responsive screens**; Windows uses rail/two-pane where practical; mobile uses bottom navigation and stacked comparison.
- [ ] **Step 4: Run tests/static UI checks**.
- [ ] **Step 5: Commit** with `feat: add V3 study workspace and reader tools`.

### Task 7: Renforcer installation atomique et manifestes de packs

**Files:**
- Create: `assets/corpus/packs_manifest.json`
- Modify: `lib/src/services/corpus_installer.dart`
- Create: `test/corpus_installer_contract_test.dart`
- Modify: `tools/static_project_check.py`

**Interfaces:**
- Consumes: core corpus manifest and semantic pack manifest.
- Produces: validated installed paths, last-known-good corpus semantics, explicit degraded semantic mode when semantic assets are unavailable.

- [ ] **Step 1: Write failing tests/static checks** for `.tmp` isolation, backup-before-swap, schema check, unchanged user.db, and no network dependency.
- [ ] **Step 2: Run and confirm failure**.
- [ ] **Step 3: Implement staged core install** using temp file, part hashes, global hash streaming, SQLite quick check through repository open, atomic rename with `.bak` rollback; semantic pack verification remains asset-based and search falls back lexical if loading fails.
- [ ] **Step 4: Run checks**.
- [ ] **Step 5: Commit** with `feat: harden V3 offline pack installation`.

### Task 8: Recette automatisée, documentation et ZIP V3

**Files:**
- Create: `tools/validate_v3_release.py`
- Create: `reports/v3_release_validation.json`
- Modify: `README.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`
- Modify: `.github/workflows/flutter_ci.yml`
- Create: `docs/V3_VALIDATION.md`

**Interfaces:**
- Consumes: project tree, manifests, packaged database, V3 source contracts.
- Produces: machine-readable validation report and distributable ZIP.

- [ ] **Step 1: Write failing validation assertions** for V3 schema/data invariants, no network deps, no free-text answer API, book/source counts, user DB separation, test-file presence and Flutter 3.35.4 pin.
- [ ] **Step 2: Run before final docs/report and confirm expected failures**.
- [ ] **Step 3: Implement validator/docs/CI**; CI runs `flutter pub get`, `flutter analyze`, `flutter test`, Android build and Windows build in appropriate jobs with Flutter 3.35.4.
- [ ] **Step 4: Run `python tools/validate_v3_release.py` and `python tools/static_project_check.py`**, plus `flutter analyze/test` only if SDK exists. Package ZIP and verify it with `unzip -t`.
- [ ] **Step 5: Commit** with `chore: validate and package Le Grenier du Message V3`.
