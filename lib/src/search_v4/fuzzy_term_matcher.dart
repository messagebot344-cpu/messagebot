import '../models/models.dart';
import 'text_normalizer.dart';

class FuzzySuggestion {
  const FuzzySuggestion({required this.original, required this.term, required this.distance});
  final String original;
  final String term;
  final int distance;
}

class FuzzyTermMatcher {
  const FuzzyTermMatcher({this.normalizer = const TextNormalizer()});

  final TextNormalizer normalizer;

  FuzzySuggestion? best(String raw, Iterable<TermStat> candidates) {
    final source = normalizer.normalize(raw);
    if (source.length < 4) return null;
    FuzzySuggestion? best;
    for (final item in candidates) {
      final candidate = normalizer.normalize(item.term);
      if (candidate.isEmpty || (candidate.length - source.length).abs() > 2) continue;
      final distance = damerauLevenshtein(source, candidate, maxDistance: source.length <= 6 ? 1 : 2);
      if (distance < 0 || distance == 0) continue;
      final value = FuzzySuggestion(original: source, term: candidate, distance: distance);
      if (best == null || value.distance < best.distance || (value.distance == best.distance && item.totalOccurrences > _frequencyOf(best.term, candidates))) {
        best = value;
      }
    }
    return best;
  }

  int _frequencyOf(String term, Iterable<TermStat> values) {
    for (final item in values) {
      if (normalizer.normalize(item.term) == term) return item.totalOccurrences;
    }
    return 0;
  }

  int damerauLevenshtein(String a, String b, {int maxDistance = 2}) {
    if ((a.length - b.length).abs() > maxDistance) return -1;
    final d = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      var rowMin = maxDistance + 1;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var value = _min3(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
        if (i > 1 && j > 1 && a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) && a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          final transpose = d[i - 2][j - 2] + 1;
          if (transpose < value) value = transpose;
        }
        d[i][j] = value;
        if (value < rowMin) rowMin = value;
      }
      if (rowMin > maxDistance) return -1;
    }
    final result = d[a.length][b.length];
    return result <= maxDistance ? result : -1;
  }

  int _min3(int a, int b, int c) {
    var m = a < b ? a : b;
    if (c < m) m = c;
    return m;
  }
}
