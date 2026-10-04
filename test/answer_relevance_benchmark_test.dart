import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/offline_ai/offline_ai_citation_ranker.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

CuratedReferenceIndex loadBenchmarkIndex() {
  final manifest = jsonDecode(
    File('assets/curated/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final payloads = (manifest['files'] as List)
      .cast<String>()
      .map(
        (path) => jsonDecode(File(path).readAsStringSync())
            as Map<String, dynamic>,
      )
      .toList(growable: false);
  return CuratedReferenceIndex.fromPayloads(payloads);
}

class _Case {
  const _Case(this.query, this.acceptableReferenceIds);
  final String query;
  final Set<String> acceptableReferenceIds;
}

void main() {
  test('benchmark routing citation maintient Top-1 et Top-3', () {
    final ranker = OfflineAiCitationRanker.fromIndex(loadBenchmarkIndex());
    const cases = <_Case>[
      _Case(
        'Pourquoi Dieu peut-il parfois faire attendre la réponse à une prière ?',
        {'prayer_008'},
      ),
      _Case(
        'Pourquoi faut-il prier avant de choisir une épouse ?',
        {'marriage_choice_001'},
      ),
      _Case(
        'Pourquoi chercher le choix de Dieu plutôt que son propre jugement pour le conjoint ?',
        {'marriage_choice_005'},
      ),
      _Case(
        'Quelle différence entre la volonté permissive et la volonté parfaite de Dieu ?',
        {'god_will_001', 'god_will_004'},
      ),
      _Case(
        'Quelles conséquences quand on sort de la volonté de Dieu ?',
        {'god_will_006'},
      ),
      _Case(
        'Pourquoi le Saint-Esprit a-t-il été donné ?',
        {'holy_spirit_002'},
      ),
      _Case(
        'Le Saint-Esprit est-il l enseignant de l Église ?',
        {'holy_spirit_011'},
      ),
      _Case(
        'Que faire des dettes que l on peut régler ?',
        {'finance_family_001', 'finance_family_002', 'finance_family_003'},
      ),
      _Case(
        'Comment planifier les dépenses ?',
        {'finance_family_009'},
      ),
      _Case(
        'Comment un gentleman chrétien doit-il traiter son épouse avec respect ?',
        {'r_640830m'},
      ),
      _Case(
        'Comment honorer son conjoint après des années de mariage ?',
        {'r_570818'},
      ),
      _Case(
        'Dieu a-t-il promis de répondre à la prière ?',
        {'prayer_005'},
      ),
      _Case(
        'Quel est le critère déterminant dans le choix du conjoint ?',
        {'marriage_choice_008'},
      ),
      _Case(
        'Dieu a-t-il un but pour chaque vie ?',
        {'god_will_012'},
      ),
      _Case(
        'La vraie richesse se mesure-t-elle seulement en argent ?',
        {'finance_family_010'},
      ),
    ];

    var top1 = 0;
    var top3 = 0;
    var top5 = 0;

    for (final item in cases) {
      final matches = ranker.rankReferences(item.query, limit: 5);
      final ids = matches.map((match) => match.reference.id).toList();

      if (ids.isNotEmpty &&
          item.acceptableReferenceIds.contains(ids.first)) {
        top1++;
      }
      if (ids.take(3).any(item.acceptableReferenceIds.contains)) {
        top3++;
      }
      if (ids.any(item.acceptableReferenceIds.contains)) {
        top5++;
      }
    }

    final top1Rate = top1 / cases.length;
    final top3Rate = top3 / cases.length;
    final top5Rate = top5 / cases.length;

    expect(
      top1Rate,
      greaterThanOrEqualTo(0.90),
      reason: 'Le routing de référence doit rester précis en Top-1.',
    );
    expect(
      top3Rate,
      greaterThanOrEqualTo(0.95),
      reason: 'La bonne référence doit presque toujours être dans le Top-3.',
    );
    expect(
      top5Rate,
      greaterThanOrEqualTo(0.95),
      reason: 'Le Top-5 ne doit pas régresser.',
    );
  });
}
