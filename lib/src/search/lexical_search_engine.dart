import '../models/models.dart';
import '../services/corpus_repository.dart';
import 'search_contracts.dart';

class LexicalSearchBundle {
  const LexicalSearchBundle({
    required this.strong,
    required this.broad,
    required this.alternateStrong,
    required this.alternateBroad,
    required this.direct,
  });

  final List<RankedPassage> strong;
  final List<RankedPassage> broad;
  final List<RankedPassage> alternateStrong;
  final List<RankedPassage> alternateBroad;
  final List<int> direct;
}

class LexicalSearchEngine {
  const LexicalSearchEngine(this.repository);

  final CorpusRepository repository;

  LexicalSearchBundle search(QueryIntent intent, List<String> tokens) {
    final direct = <int>{
      if (intent.sourceFilter != SourceFilter.books)
        ...repository.titleOrCodeMatches(intent.sermonCode ?? intent.raw, limit: 30),
      ...repository.sourceTitleMatches(
        intent.raw,
        sourceType: switch (intent.sourceFilter) {
          SourceFilter.sermons => CorpusSourceType.sermon,
          SourceFilter.books => CorpusSourceType.book,
          SourceFilter.all => null,
        },
        limit: 30,
      ),
    }.toList(growable: false);

    if (tokens.isEmpty) {
      return LexicalSearchBundle(
        strong: const [],
        broad: const [],
        alternateStrong: const [],
        alternateBroad: const [],
        direct: direct,
      );
    }

    final escaped = tokens
        .take(16)
        .map((token) => '"${token.replaceAll('"', '""')}"')
        .toList(growable: false);
    final broad = escaped.join(' OR ');
    final strong = intent.exactPhrase != null
        ? '"${intent.exactPhrase!.replaceAll('"', '""')}"'
        : escaped.join(' AND ');

    final List<RankedPassage> strongHits;
    final List<RankedPassage> broadHits;
    switch (intent.sourceFilter) {
      case SourceFilter.books:
        strongHits = repository.lexicalSearchBooks(strong, limit: 100);
        broadHits = repository.lexicalSearchBooks(broad, limit: 120);
        break;
      case SourceFilter.sermons:
        strongHits = repository.lexicalSearch(strong, limit: 100);
        broadHits = repository.lexicalSearch(broad, limit: 120);
        break;
      case SourceFilter.all:
        strongHits = repository.lexicalSearchAll(strong, limit: 100);
        broadHits = repository.lexicalSearchAll(broad, limit: 120);
        break;
    }

    return LexicalSearchBundle(
      strong: strongHits,
      broad: broadHits,
      alternateStrong: intent.sourceFilter == SourceFilter.books
          ? const []
          : repository.lexicalSearchAlternates(strong, limit: 60),
      alternateBroad: intent.sourceFilter == SourceFilter.books
          ? const []
          : repository.lexicalSearchAlternates(broad, limit: 80),
      direct: direct,
    );
  }
}
