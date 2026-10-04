import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/models/models.dart';
import 'package:le_grenier_du_message/src/printing/study_certificate_pdf_builder.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

void main() {
  test('certificat PDF contient le libellé non officiel obligatoire', () async {
    final builder = StudyCertificatePdfBuilder(
      now: () => DateTime(2026, 10, 4),
    );
    const sermon = SermonSummary(
      id: 1,
      code: '47-0412',
      title: 'La Foi Est l’Assurance',
      year: 1947,
      editionCount: 1,
      primaryEditionId: 'e1',
    );
    const certification = StudyCertification(
      certificationId: 'GRN-1-1-ABCDEF',
      sermonId: 1,
      packVersion: 1,
      corpusVersion: 'corpus-v4',
      score: 0.92,
      categoryScores: {
        'comprehension': 0.90,
        'context': 0.94,
      },
      studySeconds: 7200,
      attemptId: 2,
      certifiedAt: 1791120000000,
      level: 'Certification',
      integrityHash:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );

    final bytes = await builder.build(
      sermon: sermon,
      certification: certification,
      attemptCount: 2,
    );

    expect(bytes, isNotEmpty);
    expect(
      builder.debugPlainText,
      contains('Ceci n’est pas un diplôme académique ou ecclésiastique officiel.'),
    );
    expect(builder.debugPlainText, contains('GRN-1-1-ABCDEF'));
  });
}
