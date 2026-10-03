import '../models/models.dart';
import '../services/corpus_repository.dart';
import '../search_v4/text_normalizer.dart';

class ParallelPhraseResult {
  const ParallelPhraseResult({required this.passage, required this.score});
  final StudyPassage passage;
  final double score;
}

class ParallelPhraseEngine {
  const ParallelPhraseEngine(this.repository, {this.normalizer = const TextNormalizer()});
  final CorpusRepository repository;
  final TextNormalizer normalizer;

  List<ParallelPhraseResult> find(int passageId, {int limit = 30}) {
    final source = repository.studyDetailsForPassageIds([passageId])[passageId];
    if (source == null) return const [];
    final terms = normalizer.tokens(source.passage.text).where((e) => e.length >= 4).toSet().take(8).toList(growable: false);
    if (terms.isEmpty) return const [];
    final query = terms.map((e) => '"$e"').join(' OR ');
    final candidates = repository.lexicalSearchAll(query, limit: 240).where((e) => e.passageId != passageId).toList(growable: false);
    final details = repository.studyDetailsForPassageIds(candidates.map((e) => e.passageId));
    final sourceBigrams = _bigrams(source.passage.text);
    final results = <ParallelPhraseResult>[];
    for (final candidate in candidates) {
      final item = details[candidate.passageId];
      if (item == null) continue;
      final other = _bigrams(item.passage.text);
      final union = sourceBigrams.union(other);
      if (union.isEmpty) continue;
      final score = sourceBigrams.intersection(other).length / union.length;
      if (score >= 0.04) results.add(ParallelPhraseResult(passage: item, score: score));
    }
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(limit).toList(growable: false);
  }

  Set<String> _bigrams(String text) {
    final tokens = normalizer.tokens(text).take(160).toList(growable: false);
    final result = <String>{};
    for (var i = 0; i + 1 < tokens.length; i++) {
      result.add('${tokens[i]} ${tokens[i + 1]}');
    }
    return result;
  }
}
