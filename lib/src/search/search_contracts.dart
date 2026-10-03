enum SourceFilter { all, sermons, books }

enum QueryKind { empty, exact, sermonCode, lexical, conceptual, mixed }

class QueryIntent {
  const QueryIntent({
    required this.raw,
    required this.normalized,
    required this.kind,
    this.exactPhrase,
    this.sermonCode,
    this.yearMin,
    this.yearMax,
    this.sourceFilter = SourceFilter.all,
  });

  final String raw;
  final String normalized;
  final QueryKind kind;
  final String? exactPhrase;
  final String? sermonCode;
  final int? yearMin;
  final int? yearMax;
  final SourceFilter sourceFilter;

  bool get isEmpty => kind == QueryKind.empty || normalized.isEmpty;
}

class SearchEvidence {
  const SearchEvidence({
    this.direct = false,
    this.exact = false,
    this.lexicalStrongRank,
    this.lexicalBroadRank,
    this.semanticRank,
    this.semanticScore,
    this.alternateEdition = false,
    this.termCoverage,
  });

  final bool direct;
  final bool exact;
  final int? lexicalStrongRank;
  final int? lexicalBroadRank;
  final int? semanticRank;
  final double? semanticScore;
  final bool alternateEdition;
  final double? termCoverage;
}

class SentenceReference {
  const SentenceReference({
    required this.passageId,
    required this.startOffset,
    required this.endOffset,
    required this.ordinal,
  });

  final int passageId;
  final int startOffset;
  final int endOffset;
  final int ordinal;
}

class PassageReference {
  const PassageReference({
    required this.passageId,
    required this.editionId,
    required this.sermonId,
    required this.score,
    required this.evidence,
    this.sentence,
  });

  final int passageId;
  final String editionId;
  final int sermonId;
  final double score;
  final SearchEvidence evidence;
  final SentenceReference? sentence;
}
