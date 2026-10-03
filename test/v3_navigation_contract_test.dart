import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V3 navigation exposes the five approved workspaces', () {
    final shell = File('lib/src/screens/shell_screen.dart').readAsStringSync();
    for (final label in const ['Accueil', 'Rechercher', 'Bibliothèque', 'Étudier', 'Favoris']) {
      expect(shell, contains(label));
    }
  });

  test('V3 study UI keeps personal notes visibly separate', () {
    final collections = File('lib/src/screens/collections_screen.dart').readAsStringSync();
    expect(collections, contains('Note personnelle'));
    expect(collections, contains('distincte du texte du corpus'));
  });

  test('V3 readers expose study actions without answer generation', () {
    final reader = File('lib/src/screens/reader_screen.dart').readAsStringSync();
    expect(reader, contains('Passages similaires'));
    expect(reader, contains('Ajouter à une collection'));
    expect(reader, contains('Rechercher dans cette prédication'));
    expect(reader, isNot(contains('answer(')));
  });
}
