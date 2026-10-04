import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

void main() {
  CuratedReferenceIndex loadAll() {
    final manifest = jsonDecode(
      File('assets/curated/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final paths = (manifest['files'] as List).cast<String>();
    final payloads = paths
        .map(
          (path) => jsonDecode(File(path).readAsStringSync())
              as Map<String, dynamic>,
        )
        .toList(growable: false);
    return CuratedReferenceIndex.fromPayloads(payloads);
  }

  test('tous les guides humains sont agrégés sans remplacer le corpus', () {
    final index = loadAll();

    expect(index.references.length, 1796);
    expect(index.topics.length, greaterThanOrEqualTo(80));
    expect(
      index.references.values
          .where((reference) => !reference.corpusResolved)
          .length,
      29,
    );
  });

  test('une cause profonde de prière non exaucée retrouve une référence tardive', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Pourquoi ma prière n’est-elle pas exaucée avec un péché non confessé ?',
    );

    expect(hints, isNotEmpty);
    expect(
      hints.take(8).any(
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

  test('les dons prophétiques utilisent le fascicule de 1060 repères', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Comment développer la sensibilité au prophétique sans imiter un don ?',
    );

    expect(
      hints.take(10).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                'curated-doctrine-service-1060-v1',
          ),
      isTrue,
    );
  });

  test('venir trente minutes avant le service retrouve Church Order', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Pourquoi venir trente minutes avant le service et rester révérencieux ?',
    );

    expect(
      hints.take(12).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                    'curated-doctrine-service-1060-v1' &&
                hint.reference.sermonCode == '63-1226',
          ),
      isTrue,
    );
  });

  test('les finances chrétiennes exploitent le fascicule de 200 repères', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Comment gérer mes dettes et mon budget de façon chrétienne ?',
    );

    expect(
      hints.take(10).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                'curated-finance-family-deliverance-200-v1',
          ),
      isTrue,
    );
  });

  test('mari de nuit route vers le discernement sans en faire une doctrine', () {
    final index = loadAll();
    final hints = index.searchHints(
      'Que dit Branham sur ce que certains appellent mari de nuit ?',
    );

    expect(
      hints.take(10).any(
            (hint) =>
                hint.reference.sourceIndexId ==
                'curated-finance-family-deliverance-200-v1',
          ),
      isTrue,
    );

    final raw = File(
      'assets/curated/finance_family_deliverance_200.reference_index.json',
    ).readAsStringSync();
    expect(
      raw,
      contains("does not define 'mari/femme de nuit' as a Branham doctrine"),
    );
  });

  test('les index humains ne stockent aucun texte de citation à afficher', () {
    final manifest = jsonDecode(
      File('assets/curated/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final paths = (manifest['files'] as List).cast<String>();

    for (final path in paths) {
      final raw = File(path).readAsStringSync();
      expect(raw, isNot(contains('"quote_text"')));
      expect(raw, isNot(contains('"exact_quote"')));
      expect(raw, isNot(contains('"canonical_text"')));
      expect(raw, isNot(contains('"quote"')));
    }
  });
}
