import '../search/search_contracts.dart';
import 'text_normalizer.dart';

class CanonicalSentenceLocator {
  const CanonicalSentenceLocator({this.normalizer = const TextNormalizer()});
  final TextNormalizer normalizer;

  SentenceReference? locate(int passageId, String text, String query) {
    if (text.trim().isEmpty) return null;
    final wanted = normalizer.tokens(query).toSet();
    if (wanted.isEmpty) return null;
    final spans = _spans(text);
    if (spans.isEmpty) return null;
    _Span? best;
    double bestScore = -1;
    for (final span in spans) {
      final terms = normalizer.tokens(span.text).toSet();
      if (terms.isEmpty) continue;
      final overlap = terms.where(wanted.contains).length;
      final coverage = overlap / wanted.length;
      final density = overlap / terms.length;
      final score = coverage * 4 + density;
      if (score > bestScore) {
        bestScore = score;
        best = span;
      }
    }
    final chosen = best ?? spans.first;
    return SentenceReference(
      passageId: passageId,
      startOffset: chosen.start,
      endOffset: chosen.end,
      ordinal: chosen.ordinal,
    );
  }

  List<_Span> _spans(String text) {
    final result = <_Span>[];
    var start = 0;
    var ordinal = 0;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '.' || c == '!' || c == '?' || c == '…' || c == '\n') {
        var s = start;
        var e = i + 1;
        while (s < e && text.codeUnitAt(s) <= 32) {
          s++;
        }
        while (e > s && text.codeUnitAt(e - 1) <= 32) {
          e--;
        }
        if (e - s >= 12) {
          result.add(_Span(s, e, ordinal++, text.substring(s, e)));
        }
        start = i + 1;
      }
    }
    if (start < text.length) {
      var s = start;
      var e = text.length;
      while (s < e && text.codeUnitAt(s) <= 32) {
        s++;
      }
      while (e > s && text.codeUnitAt(e - 1) <= 32) {
        e--;
      }
      if (e > s) {
        result.add(_Span(s, e, ordinal, text.substring(s, e)));
      }
    }
    return result;
  }
}

class _Span {
  const _Span(this.start, this.end, this.ordinal, this.text);
  final int start;
  final int end;
  final int ordinal;
  final String text;
}
