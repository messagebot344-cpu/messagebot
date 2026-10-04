import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../printing/study_certificate_pdf_builder.dart';
import '../study_certification/study_pack_models.dart';
import 'print_preview_screen.dart';

class StudyCertificateScreen extends StatelessWidget {
  const StudyCertificateScreen({
    super.key,
    required this.sermon,
    required this.certification,
  });

  final SermonSummary sermon;
  final StudyCertification certification;

  @override
  Widget build(BuildContext context) {
    final attempts = AppScope.of(context)
        .studyProgressRepository
        .examAttemptCount(
          sermonId: certification.sermonId,
          packVersion: certification.packVersion,
        );
    final date =
        DateTime.fromMillisecondsSinceEpoch(certification.certifiedAt);

    return Scaffold(
      appBar: AppBar(title: const Text('Certification')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        size: 64,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Certification de réussite',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Parcours d’étude de l’application '
                        'Le Grenier du Message',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        sermon.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sermon.code,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 22),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _Metric(
                            label: 'Score',
                            value:
                                '${(certification.score * 100).toStringAsFixed(1)} %',
                          ),
                          _Metric(
                            label: 'Tentatives',
                            value: '$attempts',
                          ),
                          _Metric(
                            label: 'Temps actif',
                            value: _duration(certification.studySeconds),
                          ),
                          _Metric(
                            label: 'Date',
                            value: _date(date),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (final entry
                          in certification.categoryScores.entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(_category(entry.key))),
                              Text(
                                '${(entry.value * 100).toStringAsFixed(1)} %',
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Ceci n’est pas un diplôme académique ou '
                          'ecclésiastique officiel. Cette certification '
                          'atteste uniquement la réussite du parcours '
                          'd’étude interne à l’application.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SelectableText(
                        'ID : ${certification.certificationId}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pack v${certification.packVersion} • '
                        'Corpus ${certification.corpusVersion}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () async {
                          final bytes =
                              await StudyCertificatePdfBuilder().build(
                            sermon: sermon,
                            certification: certification,
                            attemptCount: attempts,
                          );
                          if (!context.mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MessageBotPrintPreviewScreen(
                                title: 'Certificat',
                                bytes: bytes,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Exporter le certificat en PDF'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _duration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}min';
    return '$minutes min';
  }

  static String _date(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year}';
  }

  static String _category(String value) => switch (value) {
        'comprehension' => 'Compréhension',
        'context' => 'Contexte',
        'reasoning' => 'Raisonnement',
        'bible' => 'Bible',
        'doctrine' => 'Doctrine',
        'comparison' => 'Comparaison',
        'case_analysis' => 'Analyse de cas',
        _ => value,
      };
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
