import 'search_contracts.dart';

class QueryAnalyzer {
  static final RegExp _sermonCode = RegExp(r'\b(?:\d{2}-\d{4}[A-Z]?|\d{2}-\d{3,4}[A-Z]?)\b', caseSensitive: false);
  static final RegExp _year = RegExp(r'\b(19\d{2}|20\d{2})\b');

  QueryIntent analyze(String raw) {
    final trimmed = raw.trim();
    final normalized = _normalize(trimmed);
    if (normalized.isEmpty) {
      return const QueryIntent(raw: '', normalized: '', kind: QueryKind.empty);
    }

    final codeMatch = _sermonCode.firstMatch(trimmed.toUpperCase());
    final exactPhrase = _extractQuotedPhrase(trimmed);
    final years = _year
        .allMatches(trimmed)
        .map((m) => int.parse(m.group(1)!))
        .toList(growable: false);
    final lower = normalized.toLowerCase();
    final sourceFilter = lower.contains('livre') || lower.contains('expose') || lower.contains('exposé')
        ? SourceFilter.books
        : lower.contains('predication') || lower.contains('prédication')
            ? SourceFilter.sermons
            : SourceFilter.all;

    int? yearMin;
    int? yearMax;
    if (years.isNotEmpty) {
      final y = years.first;
      final after = RegExp(r'\b(apres|après|depuis|a partir de|à partir de)\b').hasMatch(lower);
      final before = RegExp(r'\b(avant|jusqu(?:a|à))\b').hasMatch(lower);
      if (after) {
        yearMin = y;
      } else if (before) {
        yearMax = y;
      } else {
        yearMin = y;
        yearMax = y;
      }
    }

    final kind = exactPhrase != null
        ? QueryKind.exact
        : codeMatch != null && normalized.replaceAll(codeMatch.group(0)!.toLowerCase(), '').trim().isEmpty
            ? QueryKind.sermonCode
            : codeMatch != null || years.isNotEmpty || sourceFilter != SourceFilter.all
                ? QueryKind.mixed
                : _looksConceptual(trimmed)
                    ? QueryKind.conceptual
                    : QueryKind.lexical;

    return QueryIntent(
      raw: trimmed,
      normalized: normalized,
      kind: kind,
      exactPhrase: exactPhrase,
      sermonCode: codeMatch?.group(0)?.toUpperCase(),
      yearMin: yearMin,
      yearMax: yearMax,
      sourceFilter: sourceFilter,
    );
  }

  String? _extractQuotedPhrase(String input) {
    final match = RegExp(r'["“”«]\s*([^"“”»]+?)\s*["“”»]').firstMatch(input);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool _looksConceptual(String input) {
    final words = input.trim().split(RegExp(r'\s+'));
    if (words.length >= 6) return true;
    return RegExp(r"^(que|qu'|comment|pourquoi|ou|où|quel|quelle|quels|quelles)\\b", caseSensitive: false)
        .hasMatch(input.trim());
  }

  String _normalize(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
}
