import '../conversation/conversation_models.dart';
import 'text_normalizer.dart';

class QuerySpecV4 {
  const QuerySpecV4({
    required this.raw,
    required this.normalized,
    required this.subjectTerms,
    required this.filters,
    this.exactPhrase,
    this.sermonCode,
  });

  final String raw;
  final String normalized;
  final List<String> subjectTerms;
  final ConversationFilterSet filters;
  final String? exactPhrase;
  final String? sermonCode;

  bool get isEmpty => normalized.isEmpty;
  String get effectiveText => subjectTerms.isEmpty ? normalized : subjectTerms.join(' ');
}

class QueryParserV4 {
  const QueryParserV4({this.normalizer = const TextNormalizer()});

  final TextNormalizer normalizer;

  static final RegExp _year = RegExp(r'\b(19\d{2}|20\d{2})\b');
  static final RegExp _code = RegExp(r'\b\d{2}-\d{3,4}[A-Z]?\b', caseSensitive: false);
  static final RegExp _quoted = RegExp(r'["«“]([^"»”]{2,})["»”]');

  QuerySpecV4 parse(String raw, {ConversationFilterSet inherited = const ConversationFilterSet()}) {
    final clean = raw.trim();
    final normalized = normalizer.normalize(clean);
    if (normalized.isEmpty) {
      return QuerySpecV4(raw: clean, normalized: '', subjectTerms: const [], filters: inherited);
    }

    final exact = _quoted.firstMatch(clean)?.group(1)?.trim();
    final code = _code.firstMatch(clean.toUpperCase())?.group(0)?.toUpperCase();
    final years = _year.allMatches(normalized).map((e) => int.parse(e.group(1)!)).toList(growable: false);
    int? yearMin = inherited.yearMin;
    int? yearMax = inherited.yearMax;
    if (years.isNotEmpty) {
      final y = years.first;
      if (RegExp(r'\b(apres|depuis|a partir de)\b').hasMatch(normalized)) {
        yearMin = y;
        if (!RegExp(r'\bavant\b').hasMatch(normalized)) yearMax = inherited.yearMax;
      } else if (RegExp(r'\b(avant|jusqu a)\b').hasMatch(normalized)) {
        yearMax = y;
      } else {
        yearMin = y;
        yearMax = y;
      }
    }

    String? sourceType = inherited.sourceType;
    if (RegExp(r'\b(livre|livres|expose|exposes)\b').hasMatch(normalized)) sourceType = 'book';
    if (RegExp(r'\b(predication|predications|sermon|sermons)\b').hasMatch(normalized)) sourceType = 'sermon';
    if (RegExp(r'\b(tout le corpus|toutes les sources)\b').hasMatch(normalized)) sourceType = null;

    final rawTokens = normalizer.tokens(exact ?? clean);
    final filtered = rawTokens.where((token) => !_looksLikeFilterToken(token, years)).toList(growable: false);
    final isFilterOnly = filtered.isEmpty && (years.isNotEmpty || sourceType != inherited.sourceType);
    final subjects = isFilterOnly ? inherited.subjectTerms : (filtered.isEmpty ? inherited.subjectTerms : filtered.take(16).toList(growable: false));

    return QuerySpecV4(
      raw: clean,
      normalized: normalized,
      subjectTerms: subjects,
      exactPhrase: exact,
      sermonCode: code,
      filters: ConversationFilterSet(
        subjectTerms: subjects,
        yearMin: yearMin,
        yearMax: yearMax,
        sourceType: sourceType,
        sourceId: inherited.sourceId,
      ),
    );
  }

  bool _looksLikeFilterToken(String token, List<int> years) {
    if (years.any((y) => token == '$y')) return true;
    return const <String>{'apres','avant','depuis','partir','annee','annees','predication','predications','sermon','sermons','livre','livres','uniquement','seulement','corpus'}.contains(token);
  }
}
