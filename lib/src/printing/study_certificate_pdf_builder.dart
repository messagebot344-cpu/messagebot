import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../study_certification/study_pack_models.dart';

class StudyCertificatePdfBuilder {
  StudyCertificatePdfBuilder({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String debugPlainText = '';

  Future<Uint8List> build({
    required SermonSummary sermon,
    required StudyCertification certification,
    required int attemptCount,
  }) async {
    final doc = pw.Document();
    final certifiedAt =
        DateTime.fromMillisecondsSinceEpoch(certification.certifiedAt);
    final generatedAt = _now();
    final studyDuration = _duration(certification.studySeconds);
    final score = (certification.score * 100).toStringAsFixed(1);

    debugPlainText = [
      'Le Grenier du Message',
      'Certification de réussite du parcours d’étude',
      sermon.title,
      sermon.code,
      'Score : $score %',
      'Tentatives : $attemptCount',
      'Temps d’étude : $studyDuration',
      'Certification : ${certification.certificationId}',
      'Pack : ${certification.packVersion}',
      'Corpus : ${certification.corpusVersion}',
      'Ceci n’est pas un diplôme académique ou ecclésiastique officiel.',
    ].join('\n');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(42),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey700, width: 2),
          ),
          padding: const pw.EdgeInsets.all(34),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'LE GRENIER DU MESSAGE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'V4 - IR Expert | Toute Sa Parole. Toujours avec vous. Hors ligne.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Spacer(),
              pw.Text(
                'CERTIFICATION DE RÉUSSITE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 30,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Parcours d’étude de la prédication',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 22),
              pw.Text(
                _safe(sermon.title),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                _safe(sermon.code),
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 24),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _metric('Score', '$score %'),
                  pw.SizedBox(width: 28),
                  _metric('Tentatives', '$attemptCount'),
                  pw.SizedBox(width: 28),
                  _metric('Temps d’étude', studyDuration),
                  pw.SizedBox(width: 28),
                  _metric('Réussite', _formatDate(certifiedAt)),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Wrap(
                alignment: pw.WrapAlignment.center,
                spacing: 12,
                runSpacing: 7,
                children: certification.categoryScores.entries
                    .map(
                      (entry) => pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.blueGrey200),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '${_category(entry.key)} : '
                          '${(entry.value * 100).toStringAsFixed(1)} %',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                color: PdfColors.grey100,
                child: pw.Text(
                  'Certification de réussite du parcours d’étude de '
                  'l’application Le Grenier du Message. Ceci n’est pas un '
                  'diplôme académique ou ecclésiastique officiel.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'ID : ${_safe(certification.certificationId)}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Pack v${certification.packVersion} | '
                'Corpus ${_safe(certification.corpusVersion)} | '
                'Intégrité ${certification.integrityHash.substring(0, 20)}…',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Document généré localement le ${_formatDate(generatedAt)}.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _metric(String label, String value) => pw.Column(
        children: [
          pw.Text(
            _safe(value),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(_safe(label), style: const pw.TextStyle(fontSize: 8)),
        ],
      );

  String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}min';
    return '${minutes} min';
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  String _category(String value) => switch (value) {
        'comprehension' => 'Compréhension',
        'context' => 'Contexte',
        'reasoning' => 'Raisonnement',
        'bible' => 'Bible',
        'doctrine' => 'Doctrine',
        'comparison' => 'Comparaison',
        'case_analysis' => 'Analyse de cas',
        _ => value,
      };

  String _safe(String input) => input
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('—', '-')
      .replaceAll('–', '-')
      .replaceAll('…', '...')
      .replaceAll('\u00a0', ' ');
}
