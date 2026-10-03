import 'dart:math' as math;

class PassageComparison {
  const PassageComparison({
    required this.commonWordCount,
    required this.similarity,
    required this.onlyInA,
    required this.onlyInB,
  });

  final int commonWordCount;
  final double similarity;
  final List<String> onlyInA;
  final List<String> onlyInB;
}

class ComparisonEngine {
  const ComparisonEngine();

  PassageComparison compare(String a, String b) {
    final aTokens = _tokens(a);
    final bTokens = _tokens(b);
    final aSet = aTokens.toSet();
    final bSet = bTokens.toSet();
    final common = aSet.intersection(bSet);
    final union = aSet.union(bSet);
    final similarity = union.isEmpty ? 1.0 : common.length / math.max(1, union.length);
    final onlyA = aSet.difference(bSet).toList()..sort();
    final onlyB = bSet.difference(aSet).toList()..sort();
    return PassageComparison(
      commonWordCount: common.length,
      similarity: similarity,
      onlyInA: onlyA,
      onlyInB: onlyB,
    );
  }

  List<String> _tokens(String value) => RegExp(r"[0-9A-Za-zÀ-ÖØ-öø-ÿŒœ'’]+")
      .allMatches(value.toLowerCase())
      .map((m) => m.group(0)!.replaceAll('’', "'"))
      .where((word) => word.length >= 2)
      .toList(growable: false);
}
