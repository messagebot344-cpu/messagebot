import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le coordinateur analyse références puis texte canonique', () {
    final source =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();

    expect(source, contains('rankReferences'));
    expect(source, contains('rankPassages'));
    expect(source, contains('referencePriors'));
    expect(source, contains('passageMatch?.sentence'));
    expect(source, contains('semanticScore: passageMatch?.score'));
  });

  test('le fallback V4 reste actif si le ranker IA local est absent', () {
    final source =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();

    expect(
      source,
      contains('final semanticGateEnabled = offlineAiCitationRanker != null;'),
    );
    expect(
      source,
      contains('if (semanticGateEnabled &&\n          naturalQuestion'),
    );
    expect(source, contains('!hasStrongIndependentEvidence'));
    expect(
      source,
      contains('if (semanticGateEnabled &&\n          explanation.curatedReference'),
    );
  });

  test('la fenêtre sémantique conserve aussi les candidats curated', () {
    final source =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();

    expect(source, contains('candidates.take(240)'));
    expect(source, contains('semanticWindow.length >= 360'));
    expect(
      source,
      contains('curated.references.containsKey(candidate.passageId)'),
    );
  });

  test('la couche citation offline est couverte par le garde réseau', () {
    final guard = File('tools/v4_runtime_guard.py').readAsStringSync();

    expect(guard, contains("lib/src/offline_ai"));
  });

  test('aucun générateur de texte n est introduit dans le ranker', () {
    final source =
        File('lib/src/offline_ai/offline_ai_citation_ranker.dart')
            .readAsStringSync();

    expect(source, isNot(contains('http')));
    expect(source, isNot(contains('dio')));
    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('openai')));
    expect(source, isNot(contains('generateText')));
  });
}
