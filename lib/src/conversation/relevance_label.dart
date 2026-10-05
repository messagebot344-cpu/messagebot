enum RelevanceLabel { veryRelevant, relevant, partial }

extension RelevanceLabelText on RelevanceLabel {
  String get label => switch (this) {
        RelevanceLabel.veryRelevant => 'Très pertinent',
        RelevanceLabel.relevant => 'Pertinent',
        RelevanceLabel.partial => 'Correspondance partielle',
      };
}

RelevanceLabel relevanceLabelFor(
  double score, {
  required double topScore,
  double? answerConfidence,
}) {
  final absolute = answerConfidence?.clamp(0.0, 1.0).toDouble();
  if (absolute != null) {
    if (absolute >= 0.42) return RelevanceLabel.veryRelevant;
    if (absolute >= 0.13) return RelevanceLabel.relevant;
    return RelevanceLabel.partial;
  }

  if (topScore <= 0) return RelevanceLabel.partial;
  final ratio = score / topScore;
  if (ratio >= 0.72) return RelevanceLabel.veryRelevant;
  if (ratio >= 0.38) return RelevanceLabel.relevant;
  return RelevanceLabel.partial;
}
