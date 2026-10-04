class SermonSummary {
  const SermonSummary({
    required this.id,
    required this.code,
    required this.title,
    required this.year,
    required this.editionCount,
    required this.primaryEditionId,
  });

  final int id;
  final String code;
  final String title;
  final int year;
  final int editionCount;
  final String primaryEditionId;
}

class EditionSummary {
  const EditionSummary({
    required this.id,
    required this.sermonId,
    required this.title,
    required this.isPrimary,
    required this.isFrn,
    required this.sourcePageStart,
    required this.sourcePageEnd,
  });

  final String id;
  final int sermonId;
  final String title;
  final bool isPrimary;
  final bool isFrn;
  final int sourcePageStart;
  final int sourcePageEnd;

  String get label => isFrn ? 'Édition FRN' : 'Édition principale';
}

class Passage {
  const Passage({
    required this.id,
    required this.editionId,
    required this.sermonId,
    required this.ordinal,
    required this.sourcePageStart,
    required this.sourcePageEnd,
    required this.text,
  });

  final int id;
  final String editionId;
  final int sermonId;
  final int ordinal;
  final int sourcePageStart;
  final int sourcePageEnd;
  final String text;
}

class SearchHit {
  const SearchHit({
    required this.passage,
    required this.sermon,
    required this.edition,
    required this.score,
    required this.highlightSentence,
  });

  final Passage passage;
  final SermonSummary sermon;
  final EditionSummary edition;
  final double score;
  final String highlightSentence;
}

class CorpusStats {
  const CorpusStats({
    required this.sermons,
    required this.editions,
    required this.passages,
    required this.sourcePdfPages,
  });

  final int sermons;
  final int editions;
  final int passages;
  final int sourcePdfPages;
}

enum CorpusSourceType { sermon, book }

class CorpusSourceSummary {
  const CorpusSourceSummary({
    required this.id,
    required this.type,
    required this.title,
    this.code,
    this.year,
  });

  final String id;
  final CorpusSourceType type;
  final String title;
  final String? code;
  final int? year;
}

class StudyPassage {
  const StudyPassage({
    required this.passage,
    required this.source,
    this.sermon,
    this.edition,
    this.chapterTitle,
  });

  final Passage passage;
  final CorpusSourceSummary source;
  final SermonSummary? sermon;
  final EditionSummary? edition;
  final String? chapterTitle;

  String get referenceLabel {
    if (sermon != null) {
      return '${sermon!.code} • p. ${passage.sourcePageStart}';
    }
    final chapter = chapterTitle == null ? '' : ' • $chapterTitle';
    return '${source.title}$chapter • p. ${passage.sourcePageStart}';
  }
}

class NeighborPassage {
  const NeighborPassage({
    required this.passageId,
    required this.score,
    required this.relationScope,
  });

  final int passageId;
  final double score;
  final String relationScope;
}

class TermStat {
  const TermStat({
    required this.term,
    required this.documentCount,
    required this.totalOccurrences,
  });

  final String term;
  final int documentCount;
  final int totalOccurrences;
}

class BookChapterSummary {
  const BookChapterSummary({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.ordinal,
    required this.sourcePageStart,
    required this.sourcePageEnd,
  });

  final int id;
  final String sourceId;
  final String title;
  final int ordinal;
  final int sourcePageStart;
  final int sourcePageEnd;
}

class DocumentSearchHit {
  const DocumentSearchHit({
    required this.studyPassage,
    required this.score,
    required this.highlightSentence,
    this.highlightStartOffset,
    this.highlightEndOffset,
  });

  final StudyPassage studyPassage;
  final double score;
  final String highlightSentence;
  final int? highlightStartOffset;
  final int? highlightEndOffset;

  bool get isBook => studyPassage.source.type == CorpusSourceType.book;
}
