import '../models/models.dart';
import '../services/corpus_repository.dart';

class ConcordanceEngine {
  const ConcordanceEngine(this.repository);
  final CorpusRepository repository;

  List<TermStat> searchTerms(String filter, {int limit = 100}) =>
      repository.searchTermStats(filter, limit: limit);

  List<StudyPassage> occurrences(
    String term, {
    int limit = 100,
    CorpusSourceType? sourceType,
  }) {
    final ids = repository.concordancePassageIds(
      term,
      limit: limit,
      sourceType: sourceType,
    );
    final details = repository.studyDetailsForPassageIds(ids);
    return ids.where(details.containsKey).map((id) => details[id]!).toList(growable: false);
  }
}
