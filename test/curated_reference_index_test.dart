import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

void main() {
  CuratedReferenceIndex loadIndex() {
    final payload = jsonDecode(
      File('assets/curated/le_mari_gentleman.reference_index.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    return CuratedReferenceIndex.fromPayloads([payload]);
  }

  test('le guide mariage route une question naturelle vers les bons sermons', () {
    final index = loadIndex();
    final hints = index.searchHints(
      'Ma femme est très fatiguée, comment puis-je l’aider à la maison ?',
    );

    expect(hints, isNotEmpty);
    expect(hints.first.reference.sermonCode, '57-0519E');
    expect(
      hints.map((value) => value.reference.sermonCode),
      contains('54-0216'),
    );
  });

  test('la prière familiale retrouve les références validées du guide', () {
    final index = loadIndex();
    final hints = index.searchHints(
      'Comment prier avec ma femme et mes enfants dans le foyer ?',
    );

    final codes =
        hints.map((value) => value.reference.sermonCode).toSet();
    expect(codes, contains('57-0519A'));
    expect(codes, contains('61-0808'));
  });

  test('une question sans rapport ne reçoit aucun routage manuel', () {
    final index = loadIndex();
    final hints = index.searchHints(
      'Que dit le Message sur la septième dimension ?',
    );

    expect(hints, isEmpty);
  });

  test('l’index ne stocke pas de citation canonique à afficher', () {
    final raw = File(
      'assets/curated/le_mari_gentleman.reference_index.json',
    ).readAsStringSync();

    expect(raw, isNot(contains('"exact_quote"')));
    expect(raw, isNot(contains('"quote_text"')));
    expect(raw, isNot(contains('"canonical_text"')));
  });
}
