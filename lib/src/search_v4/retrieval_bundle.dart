import '../services/corpus_repository.dart';

class RetrievalBundleV4 {
  const RetrievalBundleV4({
    this.direct = const <int>[],
    this.exact = const <RankedPassage>[],
    this.proximity = const <RankedPassage>[],
    this.strong = const <RankedPassage>[],
    this.broad = const <RankedPassage>[],
    this.prefix = const <RankedPassage>[],
    this.morphology = const <RankedPassage>[],
    this.fuzzy = const <RankedPassage>[],
    this.alternate = const <RankedPassage>[],
  });

  final List<int> direct;
  final List<RankedPassage> exact;
  final List<RankedPassage> proximity;
  final List<RankedPassage> strong;
  final List<RankedPassage> broad;
  final List<RankedPassage> prefix;
  final List<RankedPassage> morphology;
  final List<RankedPassage> fuzzy;
  final List<RankedPassage> alternate;
}
