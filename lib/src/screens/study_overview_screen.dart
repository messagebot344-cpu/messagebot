import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../study_certification/study_exam_eligibility_engine.dart';
import 'study_certificate_screen.dart';
import 'study_exam_screen.dart';
import 'study_reading_screen.dart';

class StudyOverviewScreen extends StatelessWidget {
  const StudyOverviewScreen({
    super.key,
    required this.sermon,
  });

  final SermonSummary sermon;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final pack = scope.studyPackRepository.latestPublishedPack(sermon.id);

    if (pack == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Étudier & certification')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_outlined, size: 52),
                      const SizedBox(height: 16),
                      Text(
                        sermon.title,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sermon.code,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Le parcours certifiant de cette prédication n’est '
                        'pas encore publié. Aucun quiz provisoire ou contenu '
                        'non validé ne sera utilisé.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final progress = scope.studyProgressRepository.ensureProgress(
      sermonId: pack.sermonId,
      packVersion: pack.packVersion,
    );
    final sections = scope.studyPackRepository.sectionsFor(
      pack.sermonId,
      pack.packVersion,
    );
    final completed = scope.studyProgressRepository.completedSectionIds(
      pack.sermonId,
      pack.packVersion,
    );
    final rules = scope.studyPackRepository.examRules(
      pack.sermonId,
      pack.packVersion,
    );
    final pool = scope.studyPackRepository.certificationQuestionPool(
      pack.sermonId,
      pack.packVersion,
    );
    final eligibility = rules == null
        ? const StudyExamEligibility(
            eligible: false,
            reasons: ['Règles d’examen non publiées.'],
          )
        : const StudyExamEligibilityEngine().evaluate(
            pack: pack,
            progress: progress,
            rules: rules,
            sections: sections,
            completedSectionIds: completed,
            questionPool: pool,
          );
    final certifications = scope.studyProgressRepository
        .certifications()
        .where(
          (item) =>
              item.sermonId == pack.sermonId &&
              item.packVersion == pack.packVersion,
        )
        .toList(growable: false);
    final certification =
        certifications.isEmpty ? null : certifications.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Étudier & obtenir la certification'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            sermon.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            sermon.code,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 20),
          _ProgressCard(
            readingPercent: progress.readingPercent,
            completedSections: completed.length,
            sectionCount: sections.length,
            studySeconds: progress.activeStudySeconds,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StudyReadingScreen(
                    sermon: sermon,
                    pack: pack,
                  ),
                ),
              );
              if (context.mounted) {
                // Rebuild the overview from persisted local progress.
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => StudyOverviewScreen(sermon: sermon),
                  ),
                );
              }
            },
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(
              progress.readingPercent > 0
                  ? 'Continuer l’étude'
                  : 'Commencer l’étude',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sections',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final section in sections)
            Card(
              child: ListTile(
                leading: Icon(
                  completed.contains(section.id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                title: Text(section.title),
                subtitle: Text(
                  section.requiredForExam
                      ? 'Obligatoire pour l’examen'
                      : 'Section complémentaire',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudyReadingScreen(
                        sermon: sermon,
                        pack: pack,
                        initialSectionId: section.id,
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Examen final',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    eligibility.eligible
                        ? Icons.lock_open_outlined
                        : Icons.lock_outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: eligibility.eligible
                        ? const Text(
                            'Conditions remplies. L’examen final peut être '
                            'lancé hors ligne à partir de la banque validée.',
                          )
                        : Text(
                            eligibility.reasons.join('\n'),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (certification != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudyCertificateScreen(
                      sermon: sermon,
                      certification: certification,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Voir le certificat'),
            )
          else if (eligibility.eligible)
            FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudyExamScreen(
                      sermon: sermon,
                      pack: pack,
                    ),
                  ),
                );
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => StudyOverviewScreen(sermon: sermon),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Passer l’examen final'),
            ),
          if (certification != null) ...[
            const SizedBox(height: 24),
            Text(
              'Certification',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: Text(
                  'Score : ${(certification.score * 100).toStringAsFixed(1)} %',
                ),
                subtitle: Text(certification.certificationId),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudyCertificateScreen(
                        sermon: sermon,
                        certification: certification,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.readingPercent,
    required this.completedSections,
    required this.sectionCount,
    required this.studySeconds,
  });

  final double readingPercent;
  final int completedSections;
  final int sectionCount;
  final int studySeconds;

  String get _duration {
    final hours = studySeconds ~/ 3600;
    final minutes = (studySeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Progression',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${(readingPercent * 100).toStringAsFixed(1)} %',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: readingPercent),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: [
                Text('$completedSections/$sectionCount sections'),
                Text('Temps actif : $_duration'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
