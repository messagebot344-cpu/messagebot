enum StudyPackStatus { draft, generated, needsReview, validated, published, superseded, rejected }

enum StudyQuestionStatus { validated, needsReview, rejected }

enum StudyQuestionType {
  singleChoice,
  multipleChoice,
  trueFalseJustified,
  quoteToContext,
  quoteToScripture,
  reasoningOrder,
  fillBlank,
  bestInterpretation,
  badInterpretation,
  shortAnswer,
  caseStudy,
  synthesis,
}

enum StudyQuestionCategory {
  comprehension,
  context,
  reasoning,
  bible,
  doctrine,
  comparison,
  caseAnalysis,
}

enum StudyProgressStatus {
  notStarted,
  inProgress,
  readingCompleted,
  reviewRequired,
  examAvailable,
  examFailed,
  certified,
}

enum StudyParagraphState { unseen, seen, read }

enum StudySectionState { locked, available, inProgress, completed, needsReview }

class SermonStudyPackSummary {
  const SermonStudyPackSummary({
    required this.sermonId,
    required this.sermonCode,
    required this.title,
    required this.packVersion,
    required this.packSchemaVersion,
    required this.corpusVersion,
    required this.corpusCanonicalSha256,
    required this.primaryEditionId,
    required this.status,
    required this.sectionCount,
    required this.questionCount,
    required this.validatedQuestionCount,
    this.biblePackVersion,
  });

  final int sermonId;
  final String sermonCode;
  final String title;
  final int packVersion;
  final int packSchemaVersion;
  final String corpusVersion;
  final String corpusCanonicalSha256;
  final String primaryEditionId;
  final String? biblePackVersion;
  final StudyPackStatus status;
  final int sectionCount;
  final int questionCount;
  final int validatedQuestionCount;

  bool get isPublished => status == StudyPackStatus.published;
}

class StudyParagraph {
  const StudyParagraph({
    required this.paragraphKey,
    required this.sermonId,
    required this.editionId,
    required this.passageId,
    required this.globalOrdinal,
    required this.startOffset,
    required this.endOffset,
    required this.sourcePageStart,
    required this.sourcePageEnd,
    required this.textSha256,
    required this.characterCount,
    this.printedParagraphNumber,
  });

  final String paragraphKey;
  final int sermonId;
  final String editionId;
  final int passageId;
  final int globalOrdinal;
  final int startOffset;
  final int endOffset;
  final int sourcePageStart;
  final int sourcePageEnd;
  final String textSha256;
  final int characterCount;
  final String? printedParagraphNumber;
}

class StudySection {
  const StudySection({
    required this.id,
    required this.sermonId,
    required this.packVersion,
    required this.ordinal,
    required this.title,
    required this.kind,
    required this.requiredForExam,
    required this.minimumReadingPercent,
    required this.paragraphKeys,
  });

  final int id;
  final int sermonId;
  final int packVersion;
  final int ordinal;
  final String title;
  final String kind;
  final bool requiredForExam;
  final double minimumReadingPercent;
  final List<String> paragraphKeys;
}

class StudySourceEvidence {
  const StudySourceEvidence({
    required this.id,
    required this.sourceKind,
    required this.evidenceRole,
    this.sermonId,
    this.editionId,
    this.passageId,
    this.paragraphKey,
    this.startOffset,
    this.endOffset,
    this.exactQuote,
    this.quoteSha256,
    this.sourcePageStart,
    this.sourcePageEnd,
    this.translationId,
    this.normalizedReference,
    this.verseRange,
    this.exactBibleText,
    this.bibleTextSha256,
  });

  final int id;
  final String sourceKind;
  final String evidenceRole;
  final int? sermonId;
  final String? editionId;
  final int? passageId;
  final String? paragraphKey;
  final int? startOffset;
  final int? endOffset;
  final String? exactQuote;
  final String? quoteSha256;
  final int? sourcePageStart;
  final int? sourcePageEnd;
  final String? translationId;
  final String? normalizedReference;
  final String? verseRange;
  final String? exactBibleText;
  final String? bibleTextSha256;
}

class StudyQuestionOption {
  const StudyQuestionOption({
    required this.id,
    required this.questionId,
    required this.ordinal,
    required this.text,
    required this.isCorrect,
  });

  final int id;
  final int questionId;
  final int ordinal;
  final String text;
  final bool isCorrect;
}

class StudyQuestion {
  const StudyQuestion({
    required this.id,
    required this.sermonId,
    required this.packVersion,
    required this.type,
    required this.category,
    required this.difficulty,
    required this.prompt,
    required this.pedagogicalExplanation,
    required this.validationStatus,
    required this.certificationEligible,
    required this.options,
    required this.evidenceIds,
    this.correctAnswerPayload,
    this.scoringPayload,
    this.sectionId,
  });

  final int id;
  final int sermonId;
  final int packVersion;
  final int? sectionId;
  final StudyQuestionType type;
  final StudyQuestionCategory category;
  final int difficulty;
  final String prompt;
  final String pedagogicalExplanation;
  final StudyQuestionStatus validationStatus;
  final bool certificationEligible;
  final List<StudyQuestionOption> options;
  final List<int> evidenceIds;

  /// Structured, build-validated answer contract from study_packs.db.
  ///
  /// This is deliberately data-only: runtime scoring remains deterministic
  /// and never calls a network or generative model.
  final Object? correctAnswerPayload;

  /// Optional deterministic scoring rubric. Only rubric modes understood by
  /// StudyAnswerScoringEngine may be used for certification.
  final Object? scoringPayload;
}

class StudyExamCategoryRule {
  const StudyExamCategoryRule({
    required this.category,
    required this.weight,
    required this.questionCount,
    this.minimumScore,
  });

  final StudyQuestionCategory category;
  final double weight;
  final int questionCount;
  final double? minimumScore;
}

class StudyExamRules {
  const StudyExamRules({
    required this.sermonId,
    required this.packVersion,
    required this.examSize,
    required this.passThreshold,
    required this.recentQuestionExclusionCount,
    required this.minimumReadingPercent,
    required this.minimumBankMultiplier,
    required this.categories,
  });

  final int sermonId;
  final int packVersion;
  final int examSize;
  final double passThreshold;
  final int recentQuestionExclusionCount;
  final double minimumReadingPercent;
  final double minimumBankMultiplier;
  final List<StudyExamCategoryRule> categories;

  int get minimumQuestionBankSize => (examSize * minimumBankMultiplier).ceil();
}

class StudyProgressSnapshot {
  const StudyProgressSnapshot({
    required this.sermonId,
    required this.packVersion,
    required this.status,
    required this.readingPercent,
    required this.activeStudySeconds,
    required this.startedAt,
    required this.lastStudiedAt,
    this.lastSectionId,
    this.lastParagraphKey,
    this.lastPassageId,
    this.lastOffset,
    this.completedAt,
  });

  final int sermonId;
  final int packVersion;
  final StudyProgressStatus status;
  final double readingPercent;
  final int activeStudySeconds;
  final int? lastSectionId;
  final String? lastParagraphKey;
  final int? lastPassageId;
  final int? lastOffset;
  final int startedAt;
  final int lastStudiedAt;
  final int? completedAt;
}

class StudyCertification {
  const StudyCertification({
    required this.certificationId,
    required this.sermonId,
    required this.packVersion,
    required this.corpusVersion,
    required this.score,
    required this.categoryScores,
    required this.studySeconds,
    required this.attemptId,
    required this.certifiedAt,
    required this.level,
    required this.integrityHash,
  });

  final String certificationId;
  final int sermonId;
  final int packVersion;
  final String corpusVersion;
  final double score;
  final Map<String, double> categoryScores;
  final int studySeconds;
  final int attemptId;
  final int certifiedAt;
  final String level;
  final String integrityHash;
}
