import '../models/models.dart';
import '../services/corpus_repository.dart';
import '../search_v4/text_normalizer.dart';

class KwicOccurrence {
  const KwicOccurrence({required this.passage, required this.context});
  final StudyPassage passage;
  final String context;
}

class KwicEngine {
  const KwicEngine(this.repository, {this.normalizer = const TextNormalizer()});
  final CorpusRepository repository;
  final TextNormalizer normalizer;

  List<KwicOccurrence> search(String term, {int limit = 300, int contextChars = 90}) {
    final clean = normalizer.normalize(term);
    if (clean.isEmpty) return const [];
    final ids = repository.concordancePassageIds(clean, limit: limit);
    final details = repository.studyDetailsForPassageIds(ids);
    final result = <KwicOccurrence>[];
    for (final id in ids) {
      final item = details[id];
      if (item == null) continue;
      final lower = normalizer.normalize(item.passage.text);
      var index = lower.indexOf(clean);
      if (index < 0 || index >= item.passage.text.length) index = 0;
      final start = (index - contextChars).clamp(0, item.passage.text.length).toInt();
      final end = (index + clean.length + contextChars).clamp(0, item.passage.text.length).toInt();
      result.add(KwicOccurrence(passage: item, context: item.passage.text.substring(start, end).trim()));
    }
    return result;
  }
}
