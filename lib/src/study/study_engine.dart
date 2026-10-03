import '../models/models.dart';
import '../services/corpus_repository.dart';
import 'comparison_engine.dart';
import 'concordance_engine.dart';
import 'similarity_engine.dart';

class StudyEngine {
  StudyEngine(this.repository)
      : similarity = SimilarityEngine(repository),
        concordance = ConcordanceEngine(repository),
        comparison = const ComparisonEngine();

  final CorpusRepository repository;
  final SimilarityEngine similarity;
  final ConcordanceEngine concordance;
  final ComparisonEngine comparison;

  List<StudyPassage> timeline(String term, {int limit = 200}) {
    final items = concordance.occurrences(
      term,
      limit: limit,
      sourceType: CorpusSourceType.sermon,
    ).toList(growable: false);
    final sorted = items.toList()
      ..sort((a, b) {
        final ay = a.sermon?.year ?? 9999;
        final by = b.sermon?.year ?? 9999;
        final yearCmp = ay.compareTo(by);
        if (yearCmp != 0) return yearCmp;
        final codeCmp = (a.sermon?.code ?? '').compareTo(b.sermon?.code ?? '');
        if (codeCmp != 0) return codeCmp;
        return a.passage.sourcePageStart.compareTo(b.passage.sourcePageStart);
      });
    return sorted;
  }
}
