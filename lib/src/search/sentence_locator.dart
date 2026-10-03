import '../services/semantic_index.dart';
import 'search_contracts.dart';

class SentenceLocator {
  const SentenceLocator(this.semanticIndex);

  final SemanticIndex semanticIndex;

  SentenceReference? locate(int passageId, String text, String query) {
    if (text.trim().isEmpty) return null;
    final queryTokens = semanticIndex.tokens(query).toSet();
    final spans = _sentenceSpans(text);
    if (spans.isEmpty) return null;

    _SentenceSpan best = spans.first;
    var bestScore = double.negativeInfinity;
    for (final span in spans) {
      if (_isEditorial(span.text)) continue;
      final tokens = semanticIndex.tokens(span.text).toSet();
      final overlap = tokens.where(queryTokens.contains).length.toDouble();
      final coverage = queryTokens.isEmpty ? 0.0 : overlap / queryTokens.length;
      final density = tokens.isEmpty ? 0.0 : overlap / tokens.length;
      final score = coverage * 3.0 + density;
      if (score > bestScore) {
        bestScore = score;
        best = span;
      }
    }
    return SentenceReference(
      passageId: passageId,
      startOffset: best.start,
      endOffset: best.end,
      ordinal: best.ordinal,
    );
  }

  List<_SentenceSpan> _sentenceSpans(String text) {
    final spans = <_SentenceSpan>[];
    var start = 0;
    var ordinal = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '.' || c == '!' || c == '?' || c == '…' || c == '\n') {
        var end = i + 1;
        while (start < end && text.codeUnitAt(start) <= 32) start++;
        while (end > start && text.codeUnitAt(end - 1) <= 32) end--;
        if (end - start >= 12) {
          spans.add(_SentenceSpan(start, end, ordinal++, text.substring(start, end)));
        }
        start = i + 1;
      }
    }
    var end = text.length;
    while (start < end && text.codeUnitAt(start) <= 32) start++;
    while (end > start && text.codeUnitAt(end - 1) <= 32) end--;
    if (end > start) {
      spans.add(_SentenceSpan(start, end, ordinal, text.substring(start, end)));
    }
    return spans;
  }

  bool _isEditorial(String text) {
    final value = semanticIndex.normalize(text);
    const markers = [
      'branham.fr', 'branham.ru', 'shekinah', 'veuillez trouver les autres predications',
      'central africa', 'pasteurdick', 'shekinahmission',
    ];
    return markers.any(value.contains);
  }
}

class _SentenceSpan {
  const _SentenceSpan(this.start, this.end, this.ordinal, this.text);
  final int start;
  final int end;
  final int ordinal;
  final String text;
}
