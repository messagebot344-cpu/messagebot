import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V4 bootstrap uses deterministic search and does not load SemanticIndex', () {
    final source = File('lib/src/app.dart').readAsStringSync();
    expect(source, contains('SearchServiceV4'));
    expect(source, isNot(contains('SemanticIndex')));
    expect(source, isNot(contains('semantic_index.dart')));
  });

  test('V4 package does not ship LSA float assets', () {
    expect(File('assets/corpus/semantic_vectors.f32').existsSync(), isFalse);
    expect(File('assets/corpus/semantic_components.f32').existsSync(), isFalse);
  });
}
