import '../conversation/conversation_models.dart';
import '../models/models.dart';
import '../offline_ai/offline_ai_citation_ranker.dart';
import '../offline_ai/offline_ai_semantic_router.dart';
import '../search/search_contracts.dart';
import '../search_v4/curated_reference_index.dart';
import '../search_v4/search_coordinator_v4.dart';
import '../search_v4/search_explanation.dart';
import 'corpus_repository.dart';

class ResolvedV4Hit {
  const ResolvedV4Hit({required this.hit, required this.explanation});
  final DocumentSearchHit hit;
  final SearchExplanationV4 explanation;
}

class ResolvedSearchOutcomeV4 {
  const ResolvedSearchOutcomeV4({required this.raw, required this.filters, required this.hits, required this.fuzzySuggestions});
  final String raw;
  final ConversationFilterSet filters;
  final List<ResolvedV4Hit> hits;
  final List<String> fuzzySuggestions;
}

class SearchServiceV4 {
  factory SearchServiceV4({
    required CorpusRepository repository,
    CuratedReferenceIndex? curatedReferenceIndex,
    OfflineAiSemanticRouter? offlineAiRouter,
    OfflineAiCitationRanker? offlineAiCitationRanker,
  }) {
    final router = offlineAiRouter ??
        (curatedReferenceIndex == null
            ? null
            : OfflineAiSemanticRouter.fromIndex(curatedReferenceIndex));
    final citationRanker = offlineAiCitationRanker ??
        (curatedReferenceIndex == null
            ? null
            : OfflineAiCitationRanker.fromIndex(curatedReferenceIndex));
    return SearchServiceV4._(
      repository: repository,
      offlineAiRouter: router,
      offlineAiCitationRanker: citationRanker,
      coordinator: SearchCoordinatorV4(
        repository: repository,
        curatedReferenceIndex: curatedReferenceIndex,
        offlineAiRouter: router,
        offlineAiCitationRanker: citationRanker,
      ),
    );
  }

  const SearchServiceV4._({
    required this.repository,
    required this.coordinator,
    required this.offlineAiRouter,
    required this.offlineAiCitationRanker,
  });

  final CorpusRepository repository;
  final SearchCoordinatorV4 coordinator;
  final OfflineAiSemanticRouter? offlineAiRouter;
  final OfflineAiCitationRanker? offlineAiCitationRanker;

  bool get offlineAiReady =>
      offlineAiRouter != null && offlineAiCitationRanker != null;

  int get offlineAiCitationCount =>
      offlineAiCitationRanker?.activeReferenceCount ?? 0;

  Future<ResolvedSearchOutcomeV4> searchOutcome(
    String query, {
    ConversationFilterSet inherited = const ConversationFilterSet(),
    int maxResults = 120,
  }) async {
    final outcome = await coordinator.search(
      query,
      inherited: inherited,
      maxResults: maxResults,
    );
    final details = outcome.details.isNotEmpty
        ? outcome.details
        : repository.studyDetailsForPassageIds(
            outcome.references.map((e) => e.passageId),
          );
    final values = <ResolvedV4Hit>[];
    for (final ref in outcome.references) {
      final detail = details[ref.passageId];
      if (detail == null) continue;
      final sentence = ref.sentence;
      final validSentence = sentence != null &&
          sentence.startOffset >= 0 &&
          sentence.endOffset <= detail.passage.text.length &&
          sentence.startOffset < sentence.endOffset;
      final highlight = validSentence
          ? detail.passage.text.substring(sentence.startOffset, sentence.endOffset)
          : _fallbackHighlight(detail.passage.text);
      values.add(ResolvedV4Hit(
        hit: DocumentSearchHit(
          studyPassage: detail,
          score: ref.score,
          highlightSentence: highlight,
          highlightStartOffset: validSentence ? sentence.startOffset : null,
          highlightEndOffset: validSentence ? sentence.endOffset : null,
          highlightOrdinal: validSentence ? sentence.ordinal : null,
        ),
        explanation: outcome.explanations[ref.passageId] ?? const SearchExplanationV4(),
      ));
    }
    return ResolvedSearchOutcomeV4(
      raw: query,
      filters: outcome.query.filters,
      hits: values,
      fuzzySuggestions: outcome.fuzzySuggestions,
    );
  }

  Future<List<DocumentSearchHit>> searchDocuments(String query, {int limit = 100}) async {
    final outcome = await searchOutcome(query, maxResults: limit);
    return outcome.hits.map((e) => e.hit).toList(growable: false);
  }

  Future<List<SearchHit>> search(String query, {int limit = 100}) async {
    final docs = await searchDocuments(query, limit: limit);
    return docs.where((e) => e.studyPassage.sermon != null && e.studyPassage.edition != null).map((e) => SearchHit(
      passage: e.studyPassage.passage,
      sermon: e.studyPassage.sermon!,
      edition: e.studyPassage.edition!,
      score: e.score,
      highlightSentence: e.highlightSentence,
    )).toList(growable: false);
  }

  List<DocumentSearchHit> resolvePersisted(Iterable<PersistedHitRef> refs, {String query = ''}) {
    final list = refs.toList(growable: false)..sort((a, b) => a.rank.compareTo(b.rank));
    final details = repository.studyDetailsForPassageIds(list.map((e) => e.passageId));
    return list.where((e) => details.containsKey(e.passageId)).map((e) {
      final detail = details[e.passageId]!;
      final persistedSentence = e.hasAnswerSpan
          ? SentenceReference(
              passageId: e.passageId,
              startOffset: e.answerStartOffset!,
              endOffset: e.answerEndOffset!,
              ordinal: e.answerOrdinal ?? 0,
            )
          : null;
      return _buildHit(
        detail,
        e.score,
        query: query,
        sentence: persistedSentence,
      );
    }).toList(growable: false);
  }

  List<DocumentSearchHit> resolveDocumentReferences(Iterable<PassageReference> references, {String query = ''}) {
    final refs = references.toList(growable: false);
    final details = repository.studyDetailsForPassageIds(refs.map((e) => e.passageId));
    return refs.where((e) => details.containsKey(e.passageId)).map((e) {
      final detail = details[e.passageId]!;
      return _buildHit(
        detail,
        e.score,
        query: query,
        sentence: e.sentence,
      );
    }).toList(growable: false);
  }

  DocumentSearchHit _buildHit(
    StudyPassage detail,
    double score, {
    String query = '',
    SentenceReference? sentence,
  }) {
    final resolved = sentence ??
        coordinator.sentenceLocator.locate(
          detail.passage.id,
          detail.passage.text,
          query,
        );
    final valid = resolved != null &&
        resolved.startOffset >= 0 &&
        resolved.endOffset <= detail.passage.text.length &&
        resolved.startOffset < resolved.endOffset;
    return DocumentSearchHit(
      studyPassage: detail,
      score: score,
      highlightSentence: valid
          ? detail.passage.text.substring(
              resolved.startOffset,
              resolved.endOffset,
            )
          : _bestSentence(detail.passage.text, query),
      highlightStartOffset: valid ? resolved.startOffset : null,
      highlightEndOffset: valid ? resolved.endOffset : null,
      highlightOrdinal: valid ? resolved.ordinal : null,
    );
  }

  String _fallbackHighlight(String text) {
    final clean = text.trim();
    return clean.length <= 300 ? clean : '${clean.substring(0, 300)}…';
  }

  String _bestSentence(String text, String query) {
    final terms = query.toLowerCase().split(RegExp(r'\s+')).where((e) => e.length >= 3).toSet();
    if (terms.isEmpty) return _fallbackHighlight(text);
    final parts = text.split(RegExp(r'(?<=[.!?…])\s+|\n+'));
    String best = parts.isEmpty ? text : parts.first;
    var score = -1;
    for (final part in parts) {
      final lower = part.toLowerCase();
      final current = terms.where(lower.contains).length;
      if (current > score) {
        score = current;
        best = part;
      }
    }
    final clean = best.trim();
    return clean.length <= 420 ? clean : '${clean.substring(0, 420)}…';
  }
}
