import '../services/corpus_repository.dart';
import '../search_v4/text_normalizer.dart';

class AssociatedTerm {
  const AssociatedTerm(this.term, this.count);
  final String term;
  final int count;
}

class TermAssociationEngine {
  const TermAssociationEngine(this.repository, {this.normalizer = const TextNormalizer()});
  final CorpusRepository repository;
  final TextNormalizer normalizer;

  List<AssociatedTerm> related(
    String term, {
    int limit = 30,
    int passageLimit = 300,
  }) {
    final ids = repository.concordancePassageIds(term, limit: passageLimit);
    final details = repository.studyDetailsForPassageIds(ids);
    final counts = <String, int>{};
    final source = normalizer.normalize(term);
    for (final item in details.values) {
      for (final token in normalizer.tokens(item.passage.text)) {
        if (token == source || token.length < 4) continue;
        counts[token] = (counts[token] ?? 0) + 1;
      }
    }
    final values = counts.entries.map((e) => AssociatedTerm(e.key, e.value)).toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.term.compareTo(b.term);
      });
    return values.take(limit).toList(growable: false);
  }
}
