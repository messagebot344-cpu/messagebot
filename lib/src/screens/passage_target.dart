import '../models/models.dart';

int resolvePassageIndex(
  List<Passage> passages, {
  int? passageId,
  int fallbackIndex = 0,
}) {
  if (passages.isEmpty) return 0;
  if (passageId != null) {
    final found = passages.indexWhere((passage) => passage.id == passageId);
    if (found >= 0) return found;
  }
  return fallbackIndex.clamp(0, passages.length - 1).toInt();
}

bool hasValidHighlight(
  Passage passage, {
  int? startOffset,
  int? endOffset,
}) =>
    startOffset != null &&
    endOffset != null &&
    startOffset >= 0 &&
    endOffset > startOffset &&
    endOffset <= passage.text.length;
