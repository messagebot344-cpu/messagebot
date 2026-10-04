import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../conversation/relevance_label.dart';
import '../models/models.dart';
import 'print_models.dart';

class PrintDocumentBuilder {
  PrintDocumentBuilder({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  String debugPlainText = '';
  List<String> debugSections = const [];

  Future<Uint8List> buildPassagePdf(PrintableResult result, {String? query}) async {
    final turn = PrintableTurn(
      query: query?.trim().isNotEmpty == true ? query!.trim() : 'Passage sélectionné',
      filters: const ConversationFilterSet(),
      results: [result],
    );
    return _buildDocument(
      title: 'Passage',
      turns: [turn],
      includeConversationTitle: false,
    );
  }

  Future<Uint8List> buildTurnPdf(PrintableTurn turn) async {
    return _buildDocument(
      title: 'Résultats de recherche',
      turns: [turn],
      includeConversationTitle: false,
    );
  }

  Future<Uint8List> buildConversationPdf(PrintableConversation conversation) async {
    return _buildDocument(
      title: conversation.title.trim().isEmpty ? 'Conversation' : conversation.title.trim(),
      turns: conversation.turns,
      includeConversationTitle: true,
    );
  }

  Future<Uint8List> _buildDocument({
    required String title,
    required List<PrintableTurn> turns,
    required bool includeConversationTitle,
  }) async {
    final doc = pw.Document();
    final generated = _formatDate(_now());
    final sections = <String>[];
    final plain = StringBuffer()
      ..writeln('Le Grenier du Message')
      ..writeln('V4 - IR Expert')
      ..writeln('Toute Sa Parole. Toujours avec vous. Hors ligne.')
      ..writeln('Date : $generated')
      ..writeln(title);

    final widgets = <pw.Widget>[];
    if (includeConversationTitle) {
      widgets.addAll([
        pw.Text(_safe(title), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
      ]);
    }

    for (var turnIndex = 0; turnIndex < turns.length; turnIndex++) {
      final turn = turns[turnIndex];
      sections.add('Recherche ${turnIndex + 1}');
      plain
        ..writeln('Recherche : ${turn.query}')
        ..writeln('${turn.results.length} passages pertinents');

      widgets.addAll([
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                turnIndex == 0 && !includeConversationTitle
                    ? 'Recherche'
                    : 'Recherche ${turnIndex + 1}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(_safe(turn.query)),
              pw.SizedBox(height: 4),
              pw.Text('${turn.results.length} passages pertinents', style: const pw.TextStyle(fontSize: 9)),
              if (!turn.filters.isEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(_safe(_filterLine(turn.filters)), style: const pw.TextStyle(fontSize: 9)),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ]);

      final topScore = turn.results.isEmpty ? 0.0 : turn.results.first.hit.score;
      for (final item in turn.results) {
        sections.add('Résultat ${item.rank}');
        final hit = item.hit;
        final p = hit.studyPassage;
        final source = _sourceLine(p);
        final relevance = relevanceLabelFor(hit.score, topScore: topScore).label;
        plain
          ..writeln('Résultat ${item.rank} - $relevance')
          ..writeln(source)
          ..writeln(hit.highlightSentence);

        widgets.addAll([
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Résultat ${item.rank}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_safe(relevance), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Text(_safe(source), style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 7),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.amber50,
                  child: pw.Text(
                    _safe(hit.highlightSentence),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5),
                  ),
                ),
                pw.SizedBox(height: 7),
                pw.Text(_safe(p.passage.text), style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 2)),
              ],
            ),
          ),
          pw.SizedBox(height: 9),
        ]);
      }

      if (turnIndex != turns.length - 1) {
        widgets.addAll([pw.Divider(), pw.SizedBox(height: 10)]);
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 28,
                  height: 28,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue900,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text('G', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Le Grenier du Message', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
                      pw.Text('V4 - IR Expert | Toute Sa Parole. Toujours avec vous. Hors ligne.', style: const pw.TextStyle(fontSize: 8.5)),
                    ],
                  ),
                ),
                pw.Text(generated, style: const pw.TextStyle(fontSize: 8.5)),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Text('100% hors ligne | Aucune IA générative | Texte canonique uniquement', style: const pw.TextStyle(fontSize: 8)),
            pw.Divider(),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI | 242 069101357 | ebassombi@gmail.com',
                style: const pw.TextStyle(fontSize: 7.2),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text('${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        build: (_) => widgets,
      ),
    );

    debugSections = sections;
    debugPlainText = plain.toString();
    return doc.save();
  }

  String _sourceLine(StudyPassage p) {
    final page = p.passage.sourcePageStart == p.passage.sourcePageEnd
        ? 'p. ${p.passage.sourcePageStart}'
        : 'pp. ${p.passage.sourcePageStart}-${p.passage.sourcePageEnd}';
    if (p.sermon == null) {
      final chapter = p.chapterTitle == null ? '' : ' - ${p.chapterTitle}';
      return '${p.source.title}$chapter - $page';
    }
    return '${p.sermon!.code} - ${p.source.title} - ${p.sermon!.year} - $page';
  }

  String _filterLine(ConversationFilterSet f) {
    final values = <String>[];
    if (f.subjectTerms.isNotEmpty) values.add('Sujet : ${f.subjectTerms.join(' ')}');
    if (f.yearMin != null || f.yearMax != null) {
      values.add('Période : ${f.yearMin ?? '...'}-${f.yearMax ?? '...'}');
    }
    if (f.sourceType != null) {
      values.add('Source : ${f.sourceType == 'book' ? 'livres' : 'prédications'}');
    }
    return values.join(' | ');
  }

  String _formatDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

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
