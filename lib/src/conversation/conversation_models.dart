class ConversationFilterSet {
  const ConversationFilterSet({
    this.subjectTerms = const <String>[],
    this.yearMin,
    this.yearMax,
    this.sourceType,
    this.sourceId,
  });

  final List<String> subjectTerms;
  final int? yearMin;
  final int? yearMax;
  final String? sourceType;
  final String? sourceId;

  bool get isEmpty => subjectTerms.isEmpty && yearMin == null && yearMax == null && sourceType == null && sourceId == null;

  ConversationFilterSet copyWith({
    List<String>? subjectTerms,
    int? yearMin,
    int? yearMax,
    String? sourceType,
    String? sourceId,
    bool clearYearMin = false,
    bool clearYearMax = false,
    bool clearSourceType = false,
    bool clearSourceId = false,
  }) {
    return ConversationFilterSet(
      subjectTerms: subjectTerms ?? this.subjectTerms,
      yearMin: clearYearMin ? null : (yearMin ?? this.yearMin),
      yearMax: clearYearMax ? null : (yearMax ?? this.yearMax),
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
    );
  }

  String get subjectLabel => subjectTerms.join(' ');
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.pinned,
  });

  final int id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final bool pinned;
}

class PersistedHitRef {
  const PersistedHitRef({
    required this.passageId,
    required this.rank,
    required this.score,
    this.expanded = false,
    this.answerStartOffset,
    this.answerEndOffset,
    this.answerOrdinal,
  });

  final int passageId;
  final int rank;
  final double score;
  final bool expanded;
  final int? answerStartOffset;
  final int? answerEndOffset;
  final int? answerOrdinal;

  bool get hasAnswerSpan =>
      answerStartOffset != null &&
      answerEndOffset != null &&
      answerStartOffset! >= 0 &&
      answerEndOffset! > answerStartOffset!;
}

class ConversationTurnRecord {
  const ConversationTurnRecord({
    required this.id,
    required this.conversationId,
    required this.query,
    required this.filters,
    required this.createdAt,
    required this.hits,
  });

  final int id;
  final int conversationId;
  final String query;
  final ConversationFilterSet filters;
  final int createdAt;
  final List<PersistedHitRef> hits;
}
