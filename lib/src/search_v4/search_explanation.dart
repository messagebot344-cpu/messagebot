class SearchExplanationV4 {
  const SearchExplanationV4({
    this.direct = false,
    this.exactPhrase = false,
    this.proximity = false,
    this.strongTerms = false,
    this.broadTerms = false,
    this.prefix = false,
    this.morphology = false,
    this.conceptual = false,
    this.fuzzy = false,
    this.alternateEdition = false,
    this.fuzzyTerms = const <String>[],
    this.conceptualTerms = const <String>[],
  });

  final bool direct;
  final bool exactPhrase;
  final bool proximity;
  final bool strongTerms;
  final bool broadTerms;
  final bool prefix;
  final bool morphology;
  final bool conceptual;
  final bool fuzzy;
  final bool alternateEdition;
  final List<String> fuzzyTerms;
  final List<String> conceptualTerms;

  List<String> get reasons {
    final values = <String>[];
    if (direct) values.add('Correspondance directe du titre ou du code');
    if (exactPhrase) values.add('Citation exacte retrouvée');
    if (proximity) values.add('Mots retrouvés à proximité');
    if (strongTerms) values.add('Tous les termes principaux sont présents');
    if (broadTerms) values.add('Plusieurs termes de la recherche sont présents');
    if (prefix) values.add('Correspondance de préfixe');
    if (morphology) values.add('Variante morphologique sûre');
    if (conceptual) {
      values.add(
        conceptualTerms.isEmpty
            ? 'Contexte conceptuel local du corpus'
            : 'Contexte conceptuel local : ${conceptualTerms.join(', ')}',
      );
    }
    if (fuzzy) values.add('Variante orthographique proche : ${fuzzyTerms.join(', ')}');
    if (alternateEdition) values.add('Correspondance dans une édition alternative');
    return values;
  }
}
