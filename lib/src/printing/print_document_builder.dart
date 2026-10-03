import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'print_models.dart';

class PrintDocumentBuilder {
  String debugPlainText = '';
  List<String> debugSections = const [];

  Future<Uint8List> buildTurnPdf(PrintableTurn turn) async {
    final doc = pw.Document();
    final sections = <String>['Recherche'];
    final plain = StringBuffer()..writeln('Message Bot')..writeln(turn.query);
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Message Bot', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('100 % hors ligne - Aucune IA générative', style: const pw.TextStyle(fontSize: 9)),
        pw.Divider(),
      ]),
      footer: (context) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Ce logiciel est conçu par le frère Erly Rolvinst BASSOMBI', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('${context.pageNumber}/${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ]),
      build: (_) => [
        pw.Text('Recherche', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(_safe(turn.query)),
        if (!turn.filters.isEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Text(_safe(_filterLine(turn.filters)), style: const pw.TextStyle(fontSize: 9)),
        ],
        pw.SizedBox(height: 14),
        ...turn.results.expand((item) {
          sections.add('Résultat ${item.rank}');
          final hit = item.hit;
          final p = hit.studyPassage;
          final source = p.sermon == null
              ? '${p.source.title} - p. ${p.passage.sourcePageStart}'
              : '${p.sermon!.code} - ${p.source.title} - p. ${p.passage.sourcePageStart}';
          plain.writeln('Résultat ${item.rank}: $source');
          plain.writeln(hit.highlightSentence);
          return <pw.Widget>[
            pw.Text('Résultat ${item.rank}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(_safe(source), style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(_safe(hit.highlightSentence), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(_safe(p.passage.text), style: const pw.TextStyle(fontSize: 9.5)),
            pw.Divider(),
          ];
        }),
        pw.SizedBox(height: 12),
        pw.Text('Contact : 242 069101357 - ebassombi@gmail.com', style: const pw.TextStyle(fontSize: 8)),
      ],
    ));
    debugSections = sections;
    debugPlainText = plain.toString();
    return doc.save();
  }

  String _filterLine(dynamic f) {
    final values = <String>[];
    if (f.subjectTerms.isNotEmpty) values.add('Sujet : ${f.subjectTerms.join(' ')}');
    if (f.yearMin != null || f.yearMax != null) values.add('Période : ${f.yearMin ?? '...'}-${f.yearMax ?? '...'}');
    if (f.sourceType != null) values.add('Source : ${f.sourceType == 'book' ? 'livres' : 'prédications'}');
    return values.join(' | ');
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
