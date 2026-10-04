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
