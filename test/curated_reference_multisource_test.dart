import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

void main() {
  CuratedReferenceIndex loadAll() {
    const paths = <String>[
      'assets/curated/le_mari_gentleman.reference_index.json',
      'assets/curated/prayer_fasting.reference_index.json',
      'assets/curated/marriage_choice_church.reference_index.json',
      'assets/curated/gods_will_mystery.reference_index.json',
      'assets/curated/holy_spirit.reference_index.json',
    ];
    final payloads = paths
        .map(
          (path) => jsonDecode(File(path).readAsStringSync())
              as Map<String, dynamic>,
        )
        .toList(growable: false);
    return CuratedReferenceIndex.fromPayloads(payloads);
  }

  test('les cinq guides humains sont agrégés sans remplacer le corpus', () {
    final index = loadAll();

    expect(index.references.length, 535);
    expect(index.topics.length, 53);
    expect(
      index.references.values
          .where((reference) => !reference.corpusResolved)
          .length,
      18,
    );
  });

  test('une cause profonde de prière non exaucée retrouve une référence tardive', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Pourquoi ma prière n’est-elle pas exaucée avec un péché non confessé ?',
    );

    expect(hints, isNotEmpty);
    expect(
      hints.take(6).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                    'curated-prayer-fasting-v1' &&
                hint.reference.context.toLowerCase().contains(
                  'péché non confessé',
                ),
          ),
      isTrue,
    );
  });

  test('le choix de l église exploite les repères sur le pasteur et la Parole', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Comment reconnaître un bon pasteur fidèle à la Parole ?',
    );

    expect(
      hints.take(8).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                'curated-marriage-choice-church-v1',
          ),
      isTrue,
    );
  });

  test('la volonté de Dieu retrouve les repères sur absence de hasard', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Est-ce que quelque chose arrive au chrétien par hasard ?',
    );

    expect(
      hints.take(8).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                    'curated-gods-will-mystery-v1' &&
                hint.reference.context.toLowerCase().contains('hasard'),
          ),
      isTrue,
    );
  });

  test('le Saint Esprit retrouve les repères sceau et Token', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Que signifie le Saint-Esprit comme sceau et Token ?',
    );

    expect(
      hints.take(8).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                    'curated-holy-spirit-v1' &&
                (hint.reference.context.toLowerCase().contains('sceau') ||
                    hint.reference.context.toLowerCase().contains('token')),
          ),
      isTrue,
    );
  });

  test('les index humains ne stockent aucun texte de citation à afficher', () {
    for (final path in <String>[
      'assets/curated/prayer_fasting.reference_index.json',
      'assets/curated/marriage_choice_church.reference_index.json',
      'assets/curated/gods_will_mystery.reference_index.json',
      'assets/curated/holy_spirit.reference_index.json',
    ]) {
      final raw = File(path).readAsStringSync();
      expect(raw, isNot(contains('"quote_text"')));
      expect(raw, isNot(contains('"exact_quote"')));
      expect(raw, isNot(contains('"canonical_text"')));
      expect(raw, isNot(contains('"quote"')));
    }
  });
}
