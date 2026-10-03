import '../services/corpus_repository.dart';
import 'query_parser_v4.dart';

class SentenceSearchEngine {
  const SentenceSearchEngine(this.repository);
  final CorpusRepository repository;

  List<RankedPassage> search(QuerySpecV4 query, {int limit = 1200}) {
    final tokens = query.subjectTerms.take(10).toList(growable: false);
    if (tokens.isEmpty) return const [];
    final fts = tokens.map((e) => '"${e.replaceAll('"', '""')}"').join(' AND ');
    if (query.filters.sourceType == 'book') return repository.lexicalSearchBooks(fts, limit: limit);
    if (query.filters.sourceType == 'sermon') return repository.lexicalSearch(fts, limit: limit);
    return repository.lexicalSearchAll(fts, limit: limit);
  }
}
