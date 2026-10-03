import '../models/models.dart';
import '../search/hybrid_ranker.dart';
import '../search/lexical_search_engine.dart';
import '../search/query_analyzer.dart';
import '../search/search_contracts.dart';
import '../search/search_coordinator.dart';
import '../search/semantic_search_engine.dart';
import '../search/sentence_locator.dart';
import 'corpus_repository.dart';
import 'semantic_index.dart';

/// Search façade. Ranking returns references only; canonical text is resolved
/// from [CorpusRepository] afterwards. No search component can generate prose.
class SearchService {
  SearchService({required this.repository, required this.semanticIndex})
      : coordinator = SearchCoordinator(
          repository: repository,
          queryAnalyzer: QueryAnalyzer(),
          lexicalEngine: LexicalSearchEngine(repository),
          semanticEngine: SemanticSearchEngine(semanticIndex),
          ranker: const HybridRanker(),
          sentenceLocator: SentenceLocator(semanticIndex),
        );

  final CorpusRepository repository;
  final SemanticIndex semanticIndex;
  final SearchCoordinator coordinator;

  Future<List<SearchHit>> search(String query, {int limit = 10}) async {
    final documents = await searchDocuments(query, limit: limit);
    return documents
        .where((hit) => hit.studyPassage.sermon != null && hit.studyPassage.edition != null)
        .map((hit) => SearchHit(
              passage: hit.studyPassage.passage,
              sermon: hit.studyPassage.sermon!,
              edition: hit.studyPassage.edition!,
              score: hit.score,
              highlightSentence: hit.highlightSentence,
            ))
        .toList(growable: false);
  }

  Future<List<DocumentSearchHit>> searchDocuments(String query, {int limit = 10}) async {
    final references = await coordinator.search(query, limit: limit);
    return resolveDocumentReferences(references, query: query);
  }

  List<DocumentSearchHit> resolveDocumentReferences(
    Iterable<PassageReference> references, {
    String query = '',
  }) {
    final refs = references.toList(growable: false);
    if (refs.isEmpty) return const [];
    final details = repository.studyDetailsForPassageIds(refs.map((e) => e.passageId));
    final hits = <DocumentSearchHit>[];
    for (final ref in refs) {
      final detail = details[ref.passageId];
      if (detail == null) continue;
      final sentence = ref.sentence;
      final highlight = sentence != null &&
              sentence.startOffset >= 0 &&
              sentence.endOffset <= detail.passage.text.length &&
              sentence.startOffset < sentence.endOffset
          ? detail.passage.text.substring(sentence.startOffset, sentence.endOffset)
          : semanticIndex.bestSentence(detail.passage.text, query);
      hits.add(DocumentSearchHit(
        studyPassage: detail,
        score: ref.score,
        highlightSentence: highlight,
      ));
    }
    return hits;
  }

  List<SearchHit> resolveReferences(Iterable<PassageReference> references) {
    return resolveDocumentReferences(references)
        .where((hit) => hit.studyPassage.sermon != null && hit.studyPassage.edition != null)
        .map((hit) => SearchHit(
              passage: hit.studyPassage.passage,
              sermon: hit.studyPassage.sermon!,
              edition: hit.studyPassage.edition!,
              score: hit.score,
              highlightSentence: hit.highlightSentence,
            ))
        .toList(growable: false);
  }
}
