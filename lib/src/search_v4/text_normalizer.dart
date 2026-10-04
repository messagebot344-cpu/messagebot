class TextNormalizer {
  const TextNormalizer();

  String normalize(String input) {
    var value = input.toLowerCase();
    const replacements = <String, String>{
      'à':'a','á':'a','â':'a','ä':'a','ã':'a','å':'a',
      'ç':'c','è':'e','é':'e','ê':'e','ë':'e',
      'ì':'i','í':'i','î':'i','ï':'i',
      'ñ':'n','ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
      'ù':'u','ú':'u','û':'u','ü':'u','ý':'y','ÿ':'y',
      'œ':'oe','æ':'ae','’':"'",'‘':"'",'–':'-','—':'-',
    };
    replacements.forEach((from, to) => value = value.replaceAll(from, to));
    value = value.replaceAll(RegExp(r"[^a-z0-9\-'\s]"), ' ');
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> tokens(String input, {bool removeStopWords = true}) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return const [];
    final values = normalized.split(' ').where((e) => e.length >= 2).toList(growable: false);
    if (!removeStopWords) return values;
    return values.where((e) => !_stopWords.contains(e)).toList(growable: false);
  }

  List<String> semanticTokens(
    String input, {
    bool removeStopWords = true,
  }) {
    final normalized = normalize(input)
        .replaceAll(RegExp(r"[-']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return const [];
    final values = normalized
        .split(' ')
        .where((value) => value.length >= 2)
        .toList(growable: false);
    if (!removeStopWords) return values;
    return values
        .where((value) => !_stopWords.contains(value))
        .toList(growable: false);
  }

  static const _stopWords = <String>{
    'alors','au','aux','avec','ce','ces','dans','de','des','du','elle','en','et','eux','il','je','la','le','les','leur','lui','ma','mais','me','meme','mes','moi','mon','ne','nos','notre','nous','on','ou','par','pas','pour','qu','que','qui','sa','se','ses','son','sur','ta','te','tes','toi','ton','tu','un','une','vos','votre','vous','y','dit','dire','sujet','uniquement','seulement','apres','avant','depuis','partir','predication','predications','livre','livres'
  };
}
