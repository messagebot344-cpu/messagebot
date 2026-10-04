import 'package:flutter/material.dart';

import '../search_v4/text_normalizer.dart';
import '../theme/grenier_tokens.dart';

class CanonicalHighlightText extends StatelessWidget {
  const CanonicalHighlightText({
    super.key,
    required this.text,
    required this.terms,
    this.style,
    this.maxLines = 0,
  });

  final String text;
  final Iterable<String> terms;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final highlightColor = Theme.of(context).brightness == Brightness.dark
        ? GrenierPalette.highlightDark
        : GrenierPalette.highlightLight;
    final ranges = _ranges(text, terms);
    if (ranges.isEmpty) {
      return SelectableText(
        text,
        maxLines: maxLines > 0 ? maxLines : null,
        style: baseStyle,
      );
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(TextSpan(
        text: text.substring(range.start, range.end),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor,
          fontWeight: FontWeight.w800,
        ),
      ));
      cursor = range.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: maxLines > 0 ? maxLines : null,
    );
  }

  static List<_TextRange> _ranges(String source, Iterable<String> rawTerms) {
    if (source.isEmpty) return const [];
    final normalizer = const TextNormalizer();
    final wanted = <String>{
      for (final raw in rawTerms)
        ...normalizer.tokens(raw).where((term) => term.length >= 2),
    };
    if (wanted.isEmpty) return const [];

    final mapped = _MappedNormalization.from(source);
    final found = <_TextRange>[];
    for (final term in wanted) {
      var from = 0;
      while (from < mapped.text.length) {
        final index = mapped.text.indexOf(term, from);
        if (index < 0) break;
        final endIndex = index + term.length - 1;
        if (index < mapped.originalIndex.length && endIndex < mapped.originalIndex.length) {
          final start = mapped.originalIndex[index];
          final end = mapped.originalIndex[endIndex] + 1;
          if (start >= 0 && end > start && end <= source.length) {
            found.add(_TextRange(start, end));
          }
        }
        from = index + term.length;
      }
    }

    if (found.isEmpty) return const [];
    found.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_TextRange>[];
    for (final range in found) {
      if (merged.isEmpty || range.start > merged.last.end) {
        merged.add(range);
      } else if (range.end > merged.last.end) {
        merged[merged.length - 1] = _TextRange(merged.last.start, range.end);
      }
    }
    return merged;
  }
}

class _MappedNormalization {
  _MappedNormalization(this.text, this.originalIndex);

  final String text;
  final List<int> originalIndex;

  factory _MappedNormalization.from(String source) {
    final buffer = StringBuffer();
    final map = <int>[];

    void emit(String value, int original) {
      for (final rune in value.runes) {
        buffer.writeCharCode(rune);
        map.add(original);
      }
    }

    const replacements = <String, String>{
      'à':'a','á':'a','â':'a','ä':'a','ã':'a','å':'a',
      'ç':'c','è':'e','é':'e','ê':'e','ë':'e',
      'ì':'i','í':'i','î':'i','ï':'i',
      'ñ':'n','ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
      'ù':'u','ú':'u','û':'u','ü':'u','ý':'y','ÿ':'y',
      'œ':'oe','æ':'ae','’':"'",'‘':"'",'–':'-','—':'-',
    };

    for (var i = 0; i < source.length; i++) {
      final lower = source[i].toLowerCase();
      final replacement = replacements[lower] ?? lower;
      final keep = RegExp(r"[a-z0-9\-'\s]").hasMatch(replacement);
      emit(keep ? replacement : ' ', i);
    }

    return _MappedNormalization(buffer.toString(), map);
  }
}

class _TextRange {
  const _TextRange(this.start, this.end);
  final int start;
  final int end;
}
