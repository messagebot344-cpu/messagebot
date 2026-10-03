import '../models/models.dart';
import '../search_v4/text_normalizer.dart';
import '../services/corpus_repository.dart';

class SimilarityResult {
  const SimilarityResult({required this.passage, required this.score, required this.relationScope});
  final StudyPassage passage;
  final double score;
  final String relationScope;
}

/// V4 deterministic sparse similarity. It never reads the V3 LSA neighbor table.
/// Candidates come from the local FTS5 index, then are re-ranked by token overlap.
class SimilarityEngine {
  const SimilarityEngine(this.repository, {this.normalizer = const TextNormalizer()});

  final CorpusRepository repository;
  final TextNormalizer normalizer;

  List<SimilarityResult> similarPassages(
    int passageId, {
    int limit = 20,
    String? relationScope,
  }) {
    final source = repository.studyDetailsForPassageIds([passageId])[passageId];
    if (source == null) return const [];

    final frequencies = <String, int>{};
    for (final token in normalizer.tokens(source.passage.text)) {
      if (token.length < 4) continue;
      frequencies[token] = (frequencies[token] ?? 0) + 1;
    }
    final terms = frequencies.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final queryTerms = terms.take(12).map((e) => e.key).toList(growable: false);
    if (queryTerms.isEmpty) return const [];

    final fts = queryTerms.map((e) => '"${e.replaceAll('"', '""')}"').join(' OR ');
    final candidates = repository.lexicalSearchAll(fts, limit: 260)
        .where((e) => e.passageId != passageId)
        .toList(growable: false);
    final details = repository.studyDetailsForPassageIds(candidates.map((e) => e.passageId));
    final sourceTokens = normalizer.tokens(source.passage.text).toSet();
    if (sourceTokens.isEmpty) return const [];

    final results = <SimilarityResult>[];
    for (final candidate in candidates) {
      final detail = details[candidate.passageId];
      if (detail == null) continue;
      final scope = detail.source.id == source.source.id ? 'same_source' : 'other_source';
      if (relationScope != null && scope != relationScope) continue;
      final targetTokens = normalizer.tokens(detail.passage.text).toSet();
      if (targetTokens.isEmpty) continue;
      final intersection = sourceTokens.intersection(targetTokens).length;
      final union = sourceTokens.union(targetTokens).length;
      if (intersection == 0 || union == 0) continue;
      final score = intersection / union;
      results.add(SimilarityResult(passage: detail, score: score, relationScope: scope));
    }
    results.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.passage.passage.id.compareTo(b.passage.passage.id);
    });
    return results.take(limit).toList(growable: false);
  }
}
