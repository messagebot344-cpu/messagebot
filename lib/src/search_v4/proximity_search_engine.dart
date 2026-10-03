import '../services/corpus_repository.dart';
import 'query_parser_v4.dart';

class ProximitySearchEngine {
  const ProximitySearchEngine(this.repository);
  final CorpusRepository repository;

  List<RankedPassage> search(QuerySpecV4 query, {int limit = 2000}) {
    final tokens = query.subjectTerms.take(8).toList(growable: false);
    if (tokens.length < 2) return const [];
    final escaped = tokens.map((e) => '"${e.replaceAll('"', '""')}"').join(' ');
    final fts = 'NEAR($escaped, 12)';
    if (query.filters.sourceType == 'book') return repository.lexicalSearchBooks(fts, limit: limit);
    if (query.filters.sourceType == 'sermon') return repository.lexicalSearch(fts, limit: limit);
    return repository.lexicalSearchAll(fts, limit: limit);
  }
}
