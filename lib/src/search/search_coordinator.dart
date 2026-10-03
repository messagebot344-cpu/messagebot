import '../models/models.dart';
import '../services/corpus_repository.dart';
import 'hybrid_ranker.dart';
import 'lexical_search_engine.dart';
import 'query_analyzer.dart';
import 'search_contracts.dart';
import 'semantic_search_engine.dart';
import 'sentence_locator.dart';

class SearchCoordinator {
  SearchCoordinator({
    required this.repository,
    required this.queryAnalyzer,
    required this.lexicalEngine,
    required this.semanticEngine,
    required this.ranker,
    required this.sentenceLocator,
  });

  final CorpusRepository repository;
  final QueryAnalyzer queryAnalyzer;
  final LexicalSearchEngine lexicalEngine;
  final SemanticSearchEngine semanticEngine;
  final HybridRanker ranker;
  final SentenceLocator sentenceLocator;

  Future<List<PassageReference>> search(String query, {int limit = 10}) async {
    final intent = queryAnalyzer.analyze(query);
    if (intent.isEmpty || limit <= 0) return const [];

    final tokens = semanticEngine.tokens(intent.exactPhrase ?? intent.raw).take(16).toList(growable: false);
    final lexical = lexicalEngine.search(intent, tokens);
    if (tokens.isEmpty && lexical.direct.isNotEmpty) {
      return _resolveDirect(intent, lexical.direct, limit);
    }

    final semantic = semanticEngine.search(intent.raw, limit: 120);
    final ranked = ranker.rank(
      intent: intent,
      lexical: lexical,
      semantic: semantic,
      knownTokenCount: semanticEngine.knownTokenCount(intent.raw),
      tokenCount: tokens.length,
      tokenCoverage: semanticEngine.knownTokenCoverage(intent.raw),
    );
    if (ranked.isEmpty) return const [];

    final candidates = ranked.take(limit * 10).toList(growable: false);
    final details = repository.studyDetailsForPassageIds(candidates.map((e) => e.passageId));
    final primarySermons = <int>{};
    for (final item in candidates) {
      final detail = details[item.passageId];
      if (detail?.edition?.isPrimary == true && detail!.sermon != null) {
        primarySermons.add(detail.sermon!.id);
      }
    }

    final result = <PassageReference>[];
    final seenPassages = <int>{};
    for (final item in candidates) {
      final detail = details[item.passageId];
      if (detail == null || !seenPassages.add(item.passageId)) continue;
      if (!_matchesSource(intent, detail)) continue;
      if (!_matchesYear(intent, detail)) continue;
      if (detail.edition != null &&
          !detail.edition!.isPrimary &&
          detail.sermon != null &&
          primarySermons.contains(detail.sermon!.id)) {
        continue;
      }
      result.add(_referenceFor(item.passageId, item.score, item.evidence, detail, intent.raw));
      if (result.length >= limit) break;
    }
    return result;
  }

  List<PassageReference> _resolveDirect(QueryIntent intent, List<int> ids, int limit) {
    final details = repository.studyDetailsForPassageIds(ids.take(limit * 3));
    final result = <PassageReference>[];
    for (final id in ids) {
      final detail = details[id];
      if (detail == null || !_matchesSource(intent, detail) || !_matchesYear(intent, detail)) continue;
      result.add(_referenceFor(
        id,
        1,
        const SearchEvidence(direct: true),
        detail,
        intent.raw,
      ));
      if (result.length >= limit) break;
    }
    return result;
  }

  PassageReference _referenceFor(
    int passageId,
    double score,
    SearchEvidence evidence,
    StudyPassage detail,
    String query,
  ) {
    return PassageReference(
      passageId: passageId,
      editionId: detail.edition?.id ?? detail.source.id,
      sermonId: detail.sermon?.id ?? 0,
      score: score,
      evidence: evidence,
      sentence: sentenceLocator.locate(passageId, detail.passage.text, query),
    );
  }

  bool _matchesSource(QueryIntent intent, StudyPassage detail) {
    return switch (intent.sourceFilter) {
      SourceFilter.all => true,
      SourceFilter.sermons => detail.source.type == CorpusSourceType.sermon,
      SourceFilter.books => detail.source.type == CorpusSourceType.book,
    };
  }

  bool _matchesYear(QueryIntent intent, StudyPassage detail) {
    if (intent.yearMin == null && intent.yearMax == null) return true;
    final year = detail.sermon?.year;
    if (year == null) return false;
    if (intent.yearMin != null && year < intent.yearMin!) return false;
    if (intent.yearMax != null && year > intent.yearMax!) return false;
    return true;
  }
}
