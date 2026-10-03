import 'text_normalizer.dart';

class MorphologyEngine {
  const MorphologyEngine({this.normalizer = const TextNormalizer()});

  final TextNormalizer normalizer;

  List<String> expandSafe(String raw) {
    final token = normalizer.normalize(raw);
    if (token.length < 4 || token.contains(' ')) return token.isEmpty ? const [] : [token];
    final result = <String>{token};
    if (token.endsWith('es') && token.length > 5) result.add(token.substring(0, token.length - 2));
    if (token.endsWith('s') && token.length > 4) result.add(token.substring(0, token.length - 1));
    if (token.endsWith('x') && token.length > 4) result.add(token.substring(0, token.length - 1));
    if (token.endsWith('ment') && token.length > 7) result.add(token.substring(0, token.length - 4));
    if (token.endsWith('e') && token.length > 5) result.add(token.substring(0, token.length - 1));
    if (token.endsWith('er') || token.endsWith('ir') || token.endsWith('re')) {
      final stem = token.substring(0, token.length - 2);
      if (stem.length >= 3) {
        result.add(stem);
        result.add('${stem}e');
      }
    }
    return result.take(5).toList(growable: false);
  }
}
