import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/offline_ai/offline_ai_semantic_router.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

void main() {
  CuratedReferenceIndex loadIndex() {
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

  test('le routeur IA local compile tous les thèmes validés', () {
    final index = loadIndex();
    final router = OfflineAiSemanticRouter.fromIndex(index);

    expect(router.topicCount, greaterThanOrEqualTo(80));
  });

  test('une formulation naturelle de prière sans réponse est comprise', () {
    final router = OfflineAiSemanticRouter.fromIndex(loadIndex());
    final matches = router.match(
      'Je prie depuis longtemps mais mes prières semblent rester sans réponse.',
      limit: 8,
    );

    expect(
      matches.any(
        (match) => match.topicId == 'unanswered_prayer' ||
            match.topicId == 'answered_prayer',
      ),
      isTrue,
    );
  });

  test('une formulation sur une assemblée et un pasteur retrouve le choix de l église', () {
    final router = OfflineAiSemanticRouter.fromIndex(loadIndex());
    final matches = router.match(
      'Je cherche une assemblée avec un pasteur fidèle à la Bible et à la Parole.',
      limit: 10,
    );

    expect(
      matches.any(
        (match) => match.topicId == 'choose_church' ||
            match.topicId == 'pastor_word' ||
            match.topicId == 'true_shepherd',
      ),
      isTrue,
    );
  });

  test('une formulation financière française retrouve le thème finances', () {
    final router = OfflineAiSemanticRouter.fromIndex(loadIndex());
    final matches = router.match(
      'Je suis endetté et je ne sais plus comment gérer mon argent et mon budget.',
      limit: 10,
    );

    expect(
      matches.any(
        (match) => match.topicId == 'finance_practical' ||
            match.topicId == 'finance_family_deliverance_all',
      ),
      isTrue,
    );
  });

  test('une requête sur la paix du foyer retrouve les thèmes conjugaux', () {
    final router = OfflineAiSemanticRouter.fromIndex(loadIndex());
    final matches = router.match(
      'Mon épouse et moi nous nous disputons souvent, comment retrouver la paix à la maison ?',
      limit: 10,
    );

    expect(
      matches.any(
        (match) => match.topicId == 'conflict_and_communication' ||
            match.topicId == 'home_atmosphere' ||
            match.topicId == 'marriage_overview',
      ),
      isTrue,
    );
  });

  test('un score IA peut activer un thème sans fabriquer de citation', () {
    final index = loadIndex();
    final hints = index.searchHints(
      'formulation volontairement sans correspondance lexicale directe',
      offlineAiTopicScores: const {'choose_church': 0.72},
    );

    expect(hints, isNotEmpty);
    expect(hints.first.offlineAiScore, greaterThan(0));
    expect(
      hints.any((hint) => hint.reference.sermonCode.isNotEmpty),
      isTrue,
    );
  });

  test('une suite sans sens ne déclenche pas le routeur', () {
    final router = OfflineAiSemanticRouter.fromIndex(loadIndex());
    final matches = router.match('zxqv jklm qzxw', limit: 6);

    expect(matches, isEmpty);
  });
}
