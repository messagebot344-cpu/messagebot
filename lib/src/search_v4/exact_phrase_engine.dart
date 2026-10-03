import '../services/corpus_repository.dart';
import 'query_parser_v4.dart';

class ExactPhraseEngine {
  const ExactPhraseEngine(this.repository);
  final CorpusRepository repository;

  List<RankedPassage> search(QuerySpecV4 query, {int limit = 2000}) {
    final phrase = (query.exactPhrase ?? query.effectiveText).trim();
    if (phrase.length < 2) return const [];
    final fts = '"${phrase.replaceAll('"', '""')}"';
    return _searchBySource(fts, query.filters.sourceType, limit);
  }

  List<RankedPassage> _searchBySource(String fts, String? source, int limit) {
    if (source == 'book') return repository.lexicalSearchBooks(fts, limit: limit);
    if (source == 'sermon') return repository.lexicalSearch(fts, limit: limit);
    return repository.lexicalSearchAll(fts, limit: limit);
  }
}
