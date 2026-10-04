import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le runtime charge le manifeste de références humaines', () {
    final app = File('lib/src/app.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(app, contains('CuratedReferenceIndex.loadAsset'));
    expect(app, contains('curatedReferenceIndex: curatedReferenceIndex'));
    expect(pubspec, contains('assets/curated/'));
    expect(
      File('assets/curated/manifest.json').existsSync(),
      isTrue,
    );
  });

  test('la recherche canonique reste la source de texte affiché', () {
    final coordinator =
        File('lib/src/search_v4/search_coordinator_v4.dart')
            .readAsStringSync();

    expect(coordinator, contains('lexicalSearchSermons'));
    expect(coordinator, contains('reference.sermonCode'));
    expect(
      coordinator,
      isNot(contains('reference.context.substring')),
    );
  });
}
