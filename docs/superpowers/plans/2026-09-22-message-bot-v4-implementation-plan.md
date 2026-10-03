# Message Bot V4 — IR Expert + Interface conversationnelle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer la V3 en V4 entièrement hors ligne et sans modèle IA/LSA au runtime, avec moteur documentaire déterministe plus puissant et interface conversationnelle fidèle à la maquette validée, y compris impression et export PDF.

**Architecture:** Conserver `corpus.db` en lecture seule et `user.db` en lecture/écriture. Construire le moteur V4 autour de FTS5/BM25, phrase/proximité, morphologie, fuzzy, index sparse et preuves de classement, puis présenter ces résultats dans une couche conversationnelle qui ne persiste que des identifiants, filtres et métadonnées utilisateur. Le texte visible est toujours résolu depuis `CorpusRepository`, jamais généré ni copié dans les tables de conversation.

**Tech Stack:** Flutter 3.35.4 / Dart 3.x, Material 3, SQLite3 + FTS5, Python 3 pour la préparation du corpus, `pdf` + `printing` pour l’impression locale/PDF, aucun service réseau au runtime.

**Spec:** `docs/superpowers/specs/2026-09-21-le-grenier-v4-ir-expert-conversation-design.md`

## Global Constraints

### Branding contract — Message Bot

- Public product name everywhere: `Message Bot`.
- Add an `Avant-propos` entry/screen containing exactly:
  - `Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI`
  - `242 069101357`
  - `ebassombi@gmail.com`
- Print/PDF headers use `Message Bot`; footer/front matter includes the same author/contact block discreetly.
- Do not rename technical identifiers merely for cosmetics when that creates build risk.
- Release validation must fail if the old visible product name remains in user-facing text or if the required author/contact strings are absent.


- Android et Windows uniquement pour cette version.
- 100 % hors ligne au runtime : aucune API, aucun serveur, aucune permission réseau fonctionnelle.
- Aucun LLM, aucun embedding neuronal et aucun LSA dans le chemin principal V4.
- Aucun texte doctrinal généré, résumé ou reformulé par le logiciel.
- Le texte affiché provient exclusivement du corpus canonique et conserve les références source.
- Toutes les fonctions V3 restent disponibles : bibliothèque, lecteur, favoris, signets, collections, notes, recherche, concordance, chronologie, comparaison, passages similaires et livre.
- Interface conversationnelle fidèle à `docs/design/Message_Bot_V4_DESIGN_REFERENCE.png`.
- Tous les résultats dépassant le seuil de pertinence sont présentés dans l’ordre de pertinence ; le rendu peut être virtualisé mais pas fonctionnellement tronqué.
- Les conversations, filtres, états d’expansion et historiques sont stockés uniquement dans `user.db`.
- Impression locale/PDF pour un passage, tous les résultats d’une recherche et toute une conversation.
- Aucune régression de l’intégrité du corpus ; `integrity_check`, `quick_check` et SHA-256 restent obligatoires.

## Review Focus

1. Requête très courte ou seulement ponctuation : ne doit ni hériter de filtres incohérents ni produire un message vide persistant.
2. Conversation de plusieurs centaines de résultats : le scroll doit rester virtualisé, sans charger tous les textes complets en widgets lourds.
3. Migration `user.db` V3→V4 interrompue : favoris, notes, collections et positions de lecture doivent rester intacts et la migration doit être idempotente.
4. Impression d’une conversation contenant des notes : les notes ne doivent jamais être présentées comme du corpus et ne sont incluses que sur choix explicite.
5. Requête fuzzy ambiguë : la correction ne doit jamais remplacer silencieusement la requête ; la variante retenue doit être visible dans l’explication.

---

## File Structure Locked by This Plan

### Search V4

- `lib/src/search_v4/query_parser_v4.dart` — parse opérateurs, filtres et continuité structurée.
- `lib/src/search_v4/text_normalizer.dart` — normalisation déterministe commune Dart/Python.
- `lib/src/search_v4/morphology_engine.dart` — variantes morphologiques sûres.
- `lib/src/search_v4/fuzzy_term_matcher.dart` — trigram + Damerau-Levenshtein.
- `lib/src/search_v4/retrieval_bundle.dart` — conteneur des candidats et preuves.
- `lib/src/search_v4/search_explanation.dart` — raisons reproductibles de classement.
- `lib/src/search_v4/exact_phrase_engine.dart` — phrase exacte.
- `lib/src/search_v4/proximity_search_engine.dart` — FTS5 `NEAR`.
- `lib/src/search_v4/sentence_search_engine.dart` — recherche phrase-level.
- `lib/src/search_v4/deterministic_hybrid_ranker.dart` — fusion sans modèle latent.
- `lib/src/search_v4/search_coordinator_v4.dart` — orchestration et seuil final.

### Conversation / impression

- `lib/src/conversation/conversation_models.dart` — `Conversation`, `ConversationTurn`, `ConversationFilterSet`, `PersistedHit`.
- `lib/src/conversation/conversation_repository.dart` — CRUD et recherche locale des conversations.
- `lib/src/conversation/conversation_controller.dart` — continuité structurée et exécution des recherches.
- `lib/src/conversation/relevance_label.dart` — catégories qualitatives reproductibles.
- `lib/src/printing/print_models.dart` — DTOs d’impression.
- `lib/src/printing/print_document_builder.dart` — génération PDF locale.
- `lib/src/printing/print_service.dart` — aperçu/impression/enregistrement PDF.

### UI conversationnelle

- `lib/src/screens/conversation_shell_screen.dart`
- `lib/src/screens/conversation_screen.dart`
- `lib/src/screens/conversation_sidebar.dart`
- `lib/src/screens/conversation_composer.dart`
- `lib/src/screens/conversation_result_message.dart`
- `lib/src/screens/conversation_result_card.dart`
- `lib/src/screens/result_details_panel.dart`
- `lib/src/screens/print_preview_screen.dart`
- `lib/src/theme/grenier_theme.dart`

### Study V4

- `lib/src/study_v4/parallel_phrase_engine.dart`
- `lib/src/study_v4/scripture_reference_engine.dart`
- `lib/src/study_v4/kwic_engine.dart`
- `lib/src/study_v4/cross_concordance_engine.dart`
- `lib/src/study_v4/term_association_engine.dart`
- `lib/src/personal/user_search_engine.dart`

### Corpus pipeline

- `tools/build_v4_corpus.py`
- `tools/v4_text_normalization.py`
- `tools/v4_fuzzy_index.py`
- `tools/v4_morphology.py`
- `tools/v4_term_associations.py`
- `tools/v4_sparse_neighbors.py`
- `tools/v4_parallel_phrases.py`
- `tools/v4_scripture_refs.py`
- `tools/v4_year_stats.py`
- `tools/test_v4_corpus.py`
- `tools/validate_v4_release.py`

---

### Task 1: Conversation contracts and V4 user schema

**Files:**
- Create: `lib/src/conversation/conversation_models.dart`
- Create: `lib/src/conversation/relevance_label.dart`
- Modify: `lib/src/personal/user_database.dart`
- Modify: `lib/src/personal/personal_library.dart`
- Test: `test/conversation_persistence_test.dart`
- Test: `test/user_database_v4_migration_test.dart`

**Interfaces:**
- Produces: `ConversationFilterSet`, `ConversationSummary`, `ConversationTurnRecord`, `PersistedHitRef`, `RelevanceLabel`.
- Produces: `PersonalLibrary.createConversation`, `renameConversation`, `pinConversation`, `deleteConversation`, `appendConversationTurn`, `loadConversation`, `searchConversations`.
- Consumes: existing `UserDatabase.db` and V3 personal data tables.

- [ ] **Step 1: Write failing schema/migration tests**

```dart
test('V4 migration preserves V3 personal data and creates conversation tables', () {
  final db = UserDatabase.openPath(tempDbPath());
  db.db.execute("INSERT INTO favorites(source_key,created_at) VALUES('65-0221M',1)");
  db.ensureV4Schema();
  expect(db.db.select("SELECT source_key FROM favorites").single['source_key'], '65-0221M');
  expect(db.db.select("SELECT name FROM sqlite_master WHERE type='table' AND name='conversations'"), isNotEmpty);
  expect(db.meta('schema_version'), '4');
});
```

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/user_database_v4_migration_test.dart test/conversation_persistence_test.dart`
Expected: FAIL because `ensureV4Schema`, conversation tables and conversation APIs do not exist.

- [ ] **Step 3: Add immutable conversation models**

```dart
class ConversationFilterSet {
  const ConversationFilterSet({
    this.subjectTerms = const [],
    this.yearMin,
    this.yearMax,
    this.sourceType,
    this.sourceId,
  });
  final List<String> subjectTerms;
  final int? yearMin;
  final int? yearMax;
  final String? sourceType;
  final String? sourceId;
}

class PersistedHitRef {
  const PersistedHitRef({required this.passageId, required this.rank, required this.score});
  final int passageId;
  final int rank;
  final double score;
}
```

- [ ] **Step 4: Add V4 tables and idempotent migration**

Create `conversations`, `conversation_turns`, `conversation_filters`, `conversation_hits`, `conversation_ui_state`, plus FTS5 table `conversation_search_fts`. Use a single transaction; set `schema_version=4` only after success.

- [ ] **Step 5: Implement persistence APIs and verify GREEN**

Run: `flutter test test/user_database_v4_migration_test.dart test/conversation_persistence_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/conversation lib/src/personal test/conversation_persistence_test.dart test/user_database_v4_migration_test.dart
git commit -m "feat: add offline conversation persistence"
```

---

### Task 2: Deterministic query parser, normalization, morphology and fuzzy terms

**Files:**
- Create: `lib/src/search_v4/query_parser_v4.dart`
- Create: `lib/src/search_v4/text_normalizer.dart`
- Create: `lib/src/search_v4/morphology_engine.dart`
- Create: `lib/src/search_v4/fuzzy_term_matcher.dart`
- Test: `test/query_parser_v4_test.dart`
- Test: `test/fuzzy_term_matcher_test.dart`

**Interfaces:**
- Produces: `QuerySpecV4 parse(String raw, {ConversationFilterSet inherited = const ConversationFilterSet()})`.
- Produces: `List<String> MorphologyEngine.expandSafe(String token)`.
- Produces: `List<FuzzySuggestion> FuzzyTermMatcher.suggest(String token, {int limit = 5})`.

- [ ] **Step 1: Write failing parser tests**

```dart
test('inherits explicit period filter without inventing semantic context', () {
  final spec = parser.parse('uniquement dans les prédications', inherited: const ConversationFilterSet(subjectTerms: ['mariage'], yearMin: 1960));
  expect(spec.subjectTerms, ['mariage']);
  expect(spec.yearMin, 1960);
  expect(spec.sourceFilter, SourceFilterV4.sermons);
});

test('complete new subject replaces previous subject but keeps compatible explicit source filter', () {
  final spec = parser.parse('baptême au nom de Jésus-Christ', inherited: const ConversationFilterSet(subjectTerms: ['mariage'], sourceType: 'sermon'));
  expect(spec.subjectTerms, contains('baptême'));
  expect(spec.subjectTerms, isNot(contains('mariage')));
  expect(spec.sourceFilter, SourceFilterV4.sermons);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/query_parser_v4_test.dart test/fuzzy_term_matcher_test.dart`
Expected: FAIL because V4 parser/matcher do not exist.

- [ ] **Step 3: Implement deterministic parsing and safe morphology**

Recognize exact quotes, `AND`, `OR`, unary `-term`, source filters, year ranges, sermon codes, book/source filters and inherited structured filters. Never infer hidden context.

- [ ] **Step 4: Implement Damerau-Levenshtein matcher**

```dart
class FuzzySuggestion {
  const FuzzySuggestion(this.term, this.distance, this.trigramOverlap);
  final String term;
  final int distance;
  final double trigramOverlap;
}
```

Correction suggestions are metadata only; raw query text is never silently replaced.

- [ ] **Step 5: Verify GREEN**

Run: `flutter test test/query_parser_v4_test.dart test/fuzzy_term_matcher_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/search_v4 test/query_parser_v4_test.dart test/fuzzy_term_matcher_test.dart
git commit -m "feat: add deterministic V4 query parsing"
```

---

### Task 3: Build V4 corpus indexes without LSA dependency

**Files:**
- Create all Python files listed under `Corpus pipeline` above.
- Modify: `assets/corpus/manifest.json`
- Generate: V4 `corpus.db` parts in `assets/corpus/db_parts/`
- Test: `tools/test_v4_corpus.py`

**Interfaces:**
- Produces SQLite tables: `passages_fts_v4`, `sentences_fts`, `terms_trigram`, `term_aliases`, `term_associations`, `parallel_phrases`, `scripture_references`, `year_term_stats`, `passage_neighbors_v4`.
- Preserves all V3 canonical `passages.text_display` bytes and passage IDs.

- [ ] **Step 1: Write failing corpus contract tests**

```python
def test_v4_schema(conn):
    names = {r[0] for r in conn.execute("select name from sqlite_master")}
    required = {"passages_fts_v4", "sentences_fts", "parallel_phrases", "scripture_references", "passage_neighbors_v4"}
    assert required <= names


def test_canonical_text_unchanged(v3, v4):
    a = dict(v3.execute("select id,text_display from passages"))
    b = dict(v4.execute("select id,text_display from passages"))
    assert a == b
```

- [ ] **Step 2: Run RED against V3 corpus**

Run: `python tools/test_v4_corpus.py --db assets/corpus/corpus.db`
Expected: FAIL because V4 tables are absent.

- [ ] **Step 3: Implement V4 normalizer and index builders**

Use the canonical display text only as source; write normalized/index data to separate columns/tables. Sparse neighbors use weighted TF-IDF/Jaccard/n-grams; no LSA files are read.

- [ ] **Step 4: Build a fresh V4 database from V3 canonical DB**

Run: `python tools/build_v4_corpus.py --input assets/corpus/corpus.db --output build/v4/corpus.db`
Expected: exit 0 and build report with all V4 table counts.

- [ ] **Step 5: Run corpus verification**

Run: `python tools/test_v4_corpus.py --db build/v4/corpus.db --baseline assets/corpus/corpus.db`
Expected: PASS including canonical invariance, `integrity_check=ok`, `quick_check=ok`.

- [ ] **Step 6: Split DB and update manifest atomically**

Use the existing part-builder convention; verify every part SHA-256 before replacing assets.

- [ ] **Step 7: Commit**

```bash
git add tools assets/corpus reports
git commit -m "feat: build deterministic V4 corpus indexes"
```

---

### Task 4: V4 retrieval engines and explainable deterministic ranking

**Files:**
- Create: `lib/src/search_v4/retrieval_bundle.dart`
- Create: `lib/src/search_v4/search_explanation.dart`
- Create: `lib/src/search_v4/exact_phrase_engine.dart`
- Create: `lib/src/search_v4/proximity_search_engine.dart`
- Create: `lib/src/search_v4/sentence_search_engine.dart`
- Create: `lib/src/search_v4/deterministic_hybrid_ranker.dart`
- Create: `lib/src/search_v4/search_coordinator_v4.dart`
- Modify: `lib/src/services/corpus_repository.dart`
- Test: `test/search_v4_retrieval_test.dart`
- Test: `test/deterministic_hybrid_ranker_test.dart`

**Interfaces:**
- Produces `SearchOutcomeV4 { List<PassageReferenceV4> hits; QuerySpecV4 spec; List<FuzzySuggestion> suggestions; }`.
- `PassageReferenceV4` contains only IDs, score, `SearchExplanation`, and canonical sentence offsets.

- [ ] **Step 1: Write failing exact/proximity/ranking tests**

```dart
test('exact phrase outranks broad lexical match', () async {
  final outcome = await coordinator.search('"Dieu dans la simplicité"');
  expect(outcome.hits.first.explanation.exactPhrase, isTrue);
});

test('near terms outrank dispersed terms at comparable BM25', () async {
  final outcome = await coordinator.search('amour mari femme');
  expect(outcome.hits.first.explanation.nearDistance, lessThanOrEqualTo(12));
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/search_v4_retrieval_test.dart test/deterministic_hybrid_ranker_test.dart`
Expected: FAIL because V4 engines do not exist.

- [ ] **Step 3: Implement repository queries for FTS5/BM25/NEAR/sentence/trigram**

All SQL queries return passage IDs + numeric evidence only. Canonical text resolution remains in `CorpusRepository.studyDetailsForPassageIds`.

- [ ] **Step 4: Implement deterministic fusion**

Use documented weights from the spec and RRF/normalized evidence. Exact/direct evidence always dominates broad/fuzzy-only evidence. Apply source/year filters, deduplication and per-source diversification after scoring.

- [ ] **Step 5: Implement qualitative relevance labels**

```dart
enum RelevanceLabel { veryRelevant, relevant, partial }
```

Thresholds are deterministic and tested; never display probability percentages.

- [ ] **Step 6: Verify GREEN and full search suite**

Run: `flutter test test/search_v4_retrieval_test.dart test/deterministic_hybrid_ranker_test.dart test/search_service_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/search_v4 lib/src/services/corpus_repository.dart test
git commit -m "feat: add explainable deterministic V4 search"
```

---

### Task 5: Replace runtime LSA path while preserving V3 API compatibility

**Files:**
- Modify: `lib/src/services/search_service.dart`
- Modify: `lib/src/app_scope.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/src/services/semantic_index.dart`
- Modify: `pubspec.yaml`
- Test: `test/v4_no_model_runtime_test.dart`

**Interfaces:**
- `SearchService.searchDocuments(String query, {int? limit})` remains callable by legacy screens but delegates to V4.
- New `SearchService.searchAllRelevant(String query, {ConversationFilterSet filters})` returns full thresholded result set.

- [ ] **Step 1: Write failing no-model-runtime test**

```dart
test('V4 SearchService does not require SemanticIndex to search', () async {
  final service = SearchService.v4(repository: repository);
  final hits = await service.searchAllRelevant('foi');
  expect(hits, isNotEmpty);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/v4_no_model_runtime_test.dart`
Expected: FAIL because `SearchService.v4` does not exist and V3 constructor requires `SemanticIndex`.

- [ ] **Step 3: Implement V4 façade and remove LSA loading from startup path**

Keep legacy semantic asset classes only if needed for migration tooling; no runtime search path may instantiate or read them.

- [ ] **Step 4: Update copy in UI/about page**

Replace any claim about a “modèle sémantique local” with “moteur documentaire local déterministe”.

- [ ] **Step 5: Verify GREEN and grep guard**

Run: `flutter test test/v4_no_model_runtime_test.dart && python tools/v4_runtime_guard.py`
Expected: PASS; guard confirms no V4 runtime import/asset dependency on LSA.

- [ ] **Step 6: Commit**

```bash
git add lib pubspec.yaml tools/v4_runtime_guard.py test/v4_no_model_runtime_test.dart
git commit -m "refactor: remove LSA from V4 runtime"
```

---

### Task 6: V4 study engines and personal search

**Files:**
- Create: `lib/src/study_v4/parallel_phrase_engine.dart`
- Create: `lib/src/study_v4/scripture_reference_engine.dart`
- Create: `lib/src/study_v4/kwic_engine.dart`
- Create: `lib/src/study_v4/cross_concordance_engine.dart`
- Create: `lib/src/study_v4/term_association_engine.dart`
- Create: `lib/src/personal/user_search_engine.dart`
- Modify: `lib/src/study/study_engine.dart`
- Modify: `lib/src/study/similarity_engine.dart`
- Test: `test/study_v4_test.dart`
- Test: `test/user_search_engine_test.dart`

**Interfaces:**
- `KWICEngine.lines(term, filters)` returns canonical offsets and IDs, not copied prose persisted elsewhere.
- `ScriptureReferenceEngine.find('Jean 3:16')` returns passage IDs and parsed reference metadata.
- `SimilarityEngine` reads `passage_neighbors_v4`, never LSA neighbors.

- [ ] **Step 1: Write failing study tests**

```dart
test('KWIC keeps keyword inside canonical passage offsets', () {
  final lines = kwic.lines('foi', limit: 20);
  expect(lines, isNotEmpty);
  for (final line in lines) {
    expect(line.keyword.toLowerCase(), 'foi');
  }
});

test('scripture reference search finds explicit references only', () {
  final refs = scripture.find('Jean 3:16');
  expect(refs.every((r) => r.normalizedReference == 'Jean 3:16'), isTrue);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/study_v4_test.dart test/user_search_engine_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement engines and integrate StudyEngine**

Expose KWIC, cross-concordance, scripture references, parallel formulations, associated terms, normalized yearly frequency, and personal-note search as separate methods.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/study_v4_test.dart test/user_search_engine_test.dart test/study_engine_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/study_v4 lib/src/personal/user_search_engine.dart lib/src/study test
git commit -m "feat: add V4 offline study engines"
```

---

### Task 7: Conversation controller and structured filter inheritance

**Files:**
- Create: `lib/src/conversation/conversation_repository.dart`
- Create: `lib/src/conversation/conversation_controller.dart`
- Modify: `lib/src/app_scope.dart`
- Test: `test/conversation_controller_test.dart`

**Interfaces:**
- `Future<ConversationTurnRecord> send(String message)` persists user message, effective filters, ordered hit refs and UI state.
- `ConversationController.newConversation()`, `openConversation(id)`, `removeFilter(...)`.

- [ ] **Step 1: Write failing continuity tests**

```dart
test('second message inherits visible filters only', () async {
  await controller.send('mariage');
  await controller.send('après 1960');
  final turn = controller.current.turns.last;
  expect(turn.filters.subjectTerms, contains('mariage'));
  expect(turn.filters.yearMin, 1960);
});

test('empty message is not persisted', () async {
  final before = controller.current.turns.length;
  await controller.send('   ');
  expect(controller.current.turns.length, before);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/conversation_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement controller with transaction-safe persistence**

Search executes first; turn and ordered hit IDs persist in one `user.db` transaction only after a successful search. Filters are stored as structured rows/JSON, never inferred from previous prose.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/conversation_controller_test.dart test/conversation_persistence_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/conversation lib/src/app_scope.dart test/conversation_controller_test.dart
git commit -m "feat: add deterministic conversation controller"
```

---

### Task 8: Theme and responsive shell faithful to the reference design

**Files:**
- Create: `lib/src/theme/grenier_theme.dart`
- Create: `lib/src/screens/conversation_shell_screen.dart`
- Create: `lib/src/screens/conversation_sidebar.dart`
- Modify: `lib/src/app.dart`
- Modify: `lib/src/screens/shell_screen.dart`
- Test: `test/conversation_shell_golden_contract_test.dart`
- Test: `test/conversation_sidebar_test.dart`

**Interfaces:**
- Desktop width ≥ 1000 px: fixed navy sidebar + conversation + optional details pane.
- Mobile: bottom navigation + drawer/secondary sheet; conversation keeps full content width.

- [ ] **Step 1: Write failing widget contract tests**

```dart
testWidgets('desktop shell shows new conversation and recent conversations', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(testApp(const ConversationShellScreen()));
  expect(find.text('Nouvelle conversation'), findsOneWidget);
  expect(find.text('Conversations récentes'), findsOneWidget);
});

testWidgets('mobile shell does not keep desktop sidebar visible', (tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(testApp(const ConversationShellScreen()));
  expect(find.byKey(const Key('desktop-conversation-sidebar')), findsNothing);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/conversation_shell_golden_contract_test.dart test/conversation_sidebar_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement reference design tokens**

Use navy sidebar, blue action color, white/light neutral conversation canvas, rounded bordered result cards, compact chips and clear typography. Dark mode keeps the same information hierarchy.

- [ ] **Step 4: Implement sidebar groups and actions**

Today / 7 days / 30 days / Older; rename, pin, delete, local search. Keep Library, Conversations, Collections, Notes, Concordance, Chronology, Compare, Scripture References, Settings.

- [ ] **Step 5: Verify GREEN**

Run: `flutter test test/conversation_shell_golden_contract_test.dart test/conversation_sidebar_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/theme lib/src/screens/conversation_shell_screen.dart lib/src/screens/conversation_sidebar.dart lib/src/app.dart lib/src/screens/shell_screen.dart test
git commit -m "feat: add responsive conversational shell"
```

---

### Task 9: Conversation screen, all ranked results, expansion and details pane

**Files:**
- Create: `lib/src/screens/conversation_screen.dart`
- Create: `lib/src/screens/conversation_composer.dart`
- Create: `lib/src/screens/conversation_result_message.dart`
- Create: `lib/src/screens/conversation_result_card.dart`
- Create: `lib/src/screens/result_details_panel.dart`
- Modify: `lib/src/screens/search_results_screen.dart`
- Test: `test/conversation_results_test.dart`
- Test: `test/conversation_filter_chips_test.dart`

**Interfaces:**
- Every turn renders all persisted result IDs in ascending rank order using lazily built list items.
- Result card actions: expand, open, compare, similar, collection, copy, print.

- [ ] **Step 1: Write failing result-order and expansion tests**

```dart
testWidgets('renders every relevant result in rank order without a load-more button', (tester) async {
  await tester.pumpWidget(conversationFixture(hitCount: 37));
  expect(find.text('37 passages pertinents trouvés'), findsOneWidget);
  expect(find.text('Afficher 10 résultats de plus'), findsNothing);
  expect(find.byKey(const Key('result-rank-1')), findsOneWidget);
});

testWidgets('develop expands canonical passage inside conversation', (tester) async {
  await tester.pumpWidget(conversationFixture(hitCount: 1));
  await tester.tap(find.text('Développer'));
  await tester.pump();
  expect(find.byKey(const Key('expanded-canonical-passage')), findsOneWidget);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/conversation_results_test.dart test/conversation_filter_chips_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement new-conversation empty state and composer behavior**

Before first message: centered branding + centered composer. After first send: user bubble, documentary result message, composer pinned at bottom.

- [ ] **Step 4: Implement lazy all-results rendering**

Use `ListView.builder`/slivers. Resolve canonical text in bounded batches around visible ranges; never create all expanded bodies eagerly.

- [ ] **Step 5: Implement visible filter chips and details pane**

Desktop details pane shows source, page, paragraph/sentence metadata, relevance label, explanation evidence and print actions. Mobile opens the same data in a sheet/screen.

- [ ] **Step 6: Verify GREEN**

Run: `flutter test test/conversation_results_test.dart test/conversation_filter_chips_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/screens lib/src/conversation test/conversation_results_test.dart test/conversation_filter_chips_test.dart
git commit -m "feat: render ranked search as offline conversations"
```

---

### Task 10: Local PDF generation, print preview and printing

**Files:**
- Create: `lib/src/printing/print_models.dart`
- Create: `lib/src/printing/print_document_builder.dart`
- Create: `lib/src/printing/print_service.dart`
- Create: `lib/src/screens/print_preview_screen.dart`
- Modify: `pubspec.yaml`
- Test: `test/print_document_builder_test.dart`
- Test: `test/print_scope_test.dart`

**Interfaces:**
- `buildPassagePdf`, `buildTurnPdf`, `buildConversationPdf` return local PDF bytes.
- Personal notes are included only when `includePersonalNotes=true` and always labelled `NOTE PERSONNELLE`.

- [ ] **Step 1: Add pinned offline-capable dependencies**

```yaml
dependencies:
  pdf: 3.11.1
  printing: 5.13.4
```

- [ ] **Step 2: Write failing print tests**

```dart
test('turn PDF keeps result rank order and canonical references', () async {
  final bytes = await builder.buildTurnPdf(turnFixture());
  expect(bytes, isNotEmpty);
  expect(builder.debugSections, containsAllInOrder(['Recherche', 'Résultat 1', 'Résultat 2']));
});

test('personal notes are excluded by default', () async {
  await builder.buildConversationPdf(conversationWithNote(), includePersonalNotes: false);
  expect(builder.debugPlainText, isNot(contains('NOTE PERSONNELLE')));
});
```

- [ ] **Step 3: Run RED**

Run: `flutter test test/print_document_builder_test.dart test/print_scope_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement PDF builder and preview**

Header: Message Bot, date d’impression, query/filter block, each result rank + canonical citation + source/code/date/page. No relevance percentage.

- [ ] **Step 5: Implement print actions from card, turn and conversation**

Preview first; then `Printing.layoutPdf` for print and `Printing.sharePdf`/local file save route for PDF export as platform permits. No network call.

- [ ] **Step 6: Verify GREEN**

Run: `flutter test test/print_document_builder_test.dart test/print_scope_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/printing lib/src/screens/print_preview_screen.dart pubspec.yaml test
git commit -m "feat: add offline print and PDF export"
```

---

### Task 11: Surface V4 study features in the validated UI

**Files:**
- Modify: `lib/src/screens/study_screen.dart`
- Modify: `lib/src/screens/concordance_screen.dart`
- Modify: `lib/src/screens/timeline_screen.dart`
- Modify: `lib/src/screens/reader_screen.dart`
- Create: `lib/src/screens/scripture_references_screen.dart`
- Create: `lib/src/screens/kwic_screen.dart`
- Create: `lib/src/screens/cross_concordance_screen.dart`
- Create: `lib/src/screens/parallel_phrases_screen.dart`
- Create: `lib/src/screens/personal_search_screen.dart`
- Test: `test/v4_study_navigation_test.dart`

**Interfaces:**
- Every study result ultimately opens a canonical `StudyPassage` using existing `openStudyPassage`.
- Conversation sidebar routes to all new study tools.

- [ ] **Step 1: Write failing navigation tests**

```dart
testWidgets('study hub exposes V4 tools', (tester) async {
  await tester.pumpWidget(studyFixture());
  expect(find.text('Références bibliques'), findsOneWidget);
  expect(find.text('KWIC'), findsOneWidget);
  expect(find.text('Concordance croisée'), findsOneWidget);
  expect(find.text('Formulations parallèles'), findsOneWidget);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test/v4_study_navigation_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement screens using V4 engines**

No generated explanation prose. Labels describe only observable/statistical facts.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/v4_study_navigation_test.dart test/study_v4_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens test/v4_study_navigation_test.dart
git commit -m "feat: expose V4 study tools"
```

---

### Task 12: Release validation, offline guards and packaging

**Files:**
- Create: `tools/v4_runtime_guard.py`
- Create: `tools/validate_v4_release.py`
- Modify: `tools/static_project_check.py`
- Modify: `.github/workflows/flutter_ci.yml` if present
- Modify: `README.md`
- Create: `docs/V4_VALIDATION.md`
- Test: `tools/test_v4_corpus.py`

**Interfaces:**
- Release validator exits nonzero for network permissions/dependencies, LSA runtime imports, corpus mismatch, missing V4 tables, or canonical text change.

- [ ] **Step 1: Write failing runtime guard**

Guard scans runtime Dart and platform manifests. Fail on HTTP/network client packages, Internet permission, semantic/LSA runtime dependency from V4 search, or missing V4 assets.

- [ ] **Step 2: Run guard before cleanup**

Run: `python tools/v4_runtime_guard.py`
Expected: FAIL until V3 semantic startup/imports and any stale copy are removed from the V4 runtime path.

- [ ] **Step 3: Make guard green without weakening rules**

Remove stale runtime references; retain migration/build tooling only outside runtime imports.

- [ ] **Step 4: Run complete Python release validation**

Run: `python tools/validate_v4_release.py`
Expected: PASS with SQLite integrity, SHA-256, V4 tables, canonical invariance and offline guard.

- [ ] **Step 5: Run full Flutter suite**

Run: `flutter pub get && flutter analyze && flutter test`
Expected: all commands exit 0.

- [ ] **Step 6: Run target builds**

Run: `flutter build apk --release && flutter build windows --release`
Expected: both builds exit 0 on the Flutter 3.35.4 reference environment.

- [ ] **Step 7: Package from committed tree and revalidate extracted ZIP**

Create `Message_Bot_V4_FINAL_CONSOLIDE.zip`, extract to a clean directory, run `python tools/validate_v4_release.py` there, run ZIP integrity test, then calculate SHA-256.

- [ ] **Step 8: Commit**

```bash
git add tools docs README.md .github
git commit -m "chore: validate and package V4 release"
```

---

## Self-Review Results

- **Spec coverage:** Sections 4A, 5–31, 32–35 and 38 are mapped to Tasks 1–12. UI conversation + print are covered by Tasks 7–10; deterministic IR by Tasks 2–5; study functions by Tasks 6 and 11; migration and release by Tasks 1 and 12.
- **Placeholder scan:** No `TBD`, `TODO`, `FIXME` or “implement later” instructions are present.
- **Type consistency:** `ConversationFilterSet` is produced in Task 1 and consumed by Tasks 2, 5 and 7. `QuerySpecV4` is produced by Task 2 and consumed by Task 4. `SearchOutcomeV4` is produced by Task 4 and consumed by Task 7. Canonical text continues to be resolved through `CorpusRepository`.
- **Review Focus:** The five listed failure modes each have explicit tests in Tasks 1, 2, 7, 9 and 10.
- **Execution method:** Native inline execution is appropriate because no subagent execution tool is available in this harness; TDD is required for every task and a final self-review will be explicitly reported as weaker than an independent reviewer.
