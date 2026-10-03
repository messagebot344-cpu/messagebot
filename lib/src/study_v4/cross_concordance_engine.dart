import '../models/models.dart';
import '../services/corpus_repository.dart';

class CrossConcordanceEngine {
  const CrossConcordanceEngine(this.repository);
  final CorpusRepository repository;

  List<StudyPassage> passagesContainingAll(List<String> terms, {int limit = 300}) {
    final clean = terms.map((e) => e.trim()).where((e) => e.length >= 2).take(6).toList(growable: false);
    if (clean.isEmpty) return const [];
    Set<int>? ids;
    for (final term in clean) {
      final current = repository.concordancePassageIds(term, limit: 2000).toSet();
      ids = ids == null ? current : ids.intersection(current);
      if (ids.isEmpty) break;
    }
    final ordered = (ids ?? const <int>{}).take(limit).toList(growable: false)..sort();
    final details = repository.studyDetailsForPassageIds(ordered);
    return ordered.where(details.containsKey).map((id) => details[id]!).toList(growable: false);
  }
}
