enum RelevanceLabel { veryRelevant, relevant, partial }

extension RelevanceLabelText on RelevanceLabel {
  String get label => switch (this) {
        RelevanceLabel.veryRelevant => 'Très pertinent',
        RelevanceLabel.relevant => 'Pertinent',
        RelevanceLabel.partial => 'Correspondance partielle',
      };
}

RelevanceLabel relevanceLabelFor(double score, {required double topScore}) {
  if (topScore <= 0) return RelevanceLabel.partial;
  final ratio = score / topScore;
  if (ratio >= 0.72) return RelevanceLabel.veryRelevant;
  if (ratio >= 0.38) return RelevanceLabel.relevant;
  return RelevanceLabel.partial;
}
