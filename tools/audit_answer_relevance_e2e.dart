import 'dart:convert';
import 'dart:io';

import 'package:le_grenier_du_message/src/conversation/conversation_models.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';
import 'package:le_grenier_du_message/src/search_v4/text_normalizer.dart';
import 'package:le_grenier_du_message/src/services/corpus_repository.dart';
import 'package:le_grenier_du_message/src/services/search_service_v4.dart';

class AnswerCase {
  const AnswerCase({
    required this.id,
    required this.query,
    required this.acceptableSermons,
    this.spanGroups = const <List<String>>[],
    this.category = 'baseline',
    this.inheritedSubjectTerms = const <String>[],
  });

  final String id;
  final String query;
  final Set<String> acceptableSermons;
  final List<List<String>> spanGroups;
  final String category;
  final List<String> inheritedSubjectTerms;
}

class AbstainCase {
  const AbstainCase(
    this.id,
    this.query, {
    this.category = 'no-answer',
  });

  final String id;
  final String query;
  final String category;
}

final normalizer = const TextNormalizer();

Future<String> rebuildCorpus() async {
  final manifest = jsonDecode(
    File('assets/corpus/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final parts = (manifest['parts'] as List)
      .cast<Map<String, dynamic>>();
  final dir = Directory.systemTemp.createTempSync('grenier-e2e-audit-');
  final db = File('${dir.path}/corpus.db');
  final sink = db.openWrite();
  try {
    for (final part in parts) {
      final name = part['name'] as String;
      final file = File('assets/corpus/db_parts/$name');
      if (!file.existsSync()) {
        throw StateError('Corpus part missing: $name');
      }
      await sink.addStream(file.openRead());
    }
  } finally {
    await sink.close();
  }
  return db.path;
}

CuratedReferenceIndex loadCurated() {
  final manifest = jsonDecode(
    File('assets/curated/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final payloads = (manifest['files'] as List)
      .cast<String>()
      .map(
        (path) => jsonDecode(File(path).readAsStringSync())
            as Map<String, dynamic>,
      )
      .toList(growable: false);
  return CuratedReferenceIndex.fromPayloads(payloads);
}

bool spanMatches(String span, List<List<String>> groups) {
  if (groups.isEmpty) return true;
  final tokens = normalizer.semanticTokens(
    span,
    removeStopWords: false,
  ).toSet();
  for (final group in groups) {
    final normalized = <String>{
      for (final value in group)
        ...normalizer.semanticTokens(
          value,
          removeStopWords: false,
        ),
    };
    if (!normalized.any(tokens.contains)) return false;
  }
  return true;
}

Future<void> main() async {
  const answerCases = <AnswerCase>[
    AnswerCase(
      id: 'prayer-hidden-iniquity',
      query:
          'Pourquoi Dieu ne répond-il pas à une prière quand une iniquité est cachée ?',
      acceptableSermons: {'59-0810'},
      spanGroups: [
        ['iniquite', 'iniquity'],
        ['priere', 'prayer'],
      ],
    ),
    AnswerCase(
      id: 'marriage-pray-before-choice',
      query: 'Pourquoi faut-il prier avant de choisir une épouse ?',
      acceptableSermons: {'65-0429E'},
      spanGroups: [
        ['priere', 'pray'],
        ['epouse', 'wife', 'conjoint'],
      ],
    ),
    AnswerCase(
      id: 'marriage-character',
      query: 'Quel est le critère déterminant dans le choix du conjoint ?',
      acceptableSermons: {'62-0720'},
      spanGroups: [
        ['caractere', 'character'],
      ],
    ),
    AnswerCase(
      id: 'holy-spirit-purpose',
      query: 'Pourquoi le Saint-Esprit a-t-il été donné ?',
      acceptableSermons: {'59-1217'},
      spanGroups: [
        ['saint', 'holy'],
        ['esprit', 'spirit', 'ghost'],
        ['purpose', 'donne', 'given', 'sending'],
      ],
    ),
    AnswerCase(
      id: 'holy-spirit-teacher',
      query: 'Le Saint-Esprit est-il l enseignant de l Église ?',
      acceptableSermons: {'58-0209A'},
      spanGroups: [
        ['enseignant', 'teacher'],
        ['eglise', 'church'],
      ],
    ),
    AnswerCase(
      id: 'will-perfect-vs-permissive',
      query:
          'Quelle différence entre la volonté permissive et la volonté parfaite de Dieu ?',
      acceptableSermons: {'65-0427', '47-1123'},
      spanGroups: [
        ['permissive'],
        ['parfaite', 'perfect'],
      ],
    ),
    AnswerCase(
      id: 'will-consequences',
      query: 'Quelles conséquences quand on sort de la volonté de Dieu ?',
      acceptableSermons: {'53-1114'},
      spanGroups: [
        ['consequence', 'consequences', 'trouble'],
      ],
    ),
    AnswerCase(
      id: 'finance-debts',
      query: 'Que faire des dettes que l on peut régler ?',
      acceptableSermons: {'65-0822M'},
      spanGroups: [
        ['dette', 'dettes', 'debt'],
        ['payer', 'pay', 'regler'],
      ],
    ),
    AnswerCase(
      id: 'finance-budget',
      query: 'Comment planifier les dépenses ?',
      acceptableSermons: {'55-0220A'},
      spanGroups: [
        ['budget', 'planifier', 'depenses', 'expenses'],
      ],
    ),
    AnswerCase(
      id: 'finance-true-riches',
      query: 'La vraie richesse se mesure-t-elle seulement en argent ?',
      acceptableSermons: {'58-1221E'},
      spanGroups: [
        ['richesse', 'riches', 'rich'],
        ['argent', 'dollars', 'money'],
      ],
    ),
    AnswerCase(
      id: 'marriage-gentleman',
      query:
          'Comment un gentleman chrétien doit-il traiter son épouse avec respect ?',
      acceptableSermons: {'64-0830M'},
      spanGroups: [
        ['gentleman'],
        ['respect', 'reverence', 'femme', 'wife'],
      ],
    ),
    AnswerCase(
      id: 'marriage-honor',
      query:
          'Comment honorer son conjoint après des années de mariage ?',
      acceptableSermons: {'57-0818'},
      spanGroups: [
        ['honorer', 'honor', 'amoureux', 'love'],
      ],
    ),
    AnswerCase(
      id: 'trap-prayer-delay-paraphrase',
      category: 'trap',
      query:
          'Je ne parle pas d un retard humain : Dieu peut-il volontairement laisser quelqu un attendre après avoir prié ?',
      acceptableSermons: {'56-0513'},
      spanGroups: [
        ['attendre', 'wait', 'waiting', 'differer'],
        ['dieu', 'god'],
      ],
    ),
    AnswerCase(
      id: 'trap-marriage-own-judgment',
      category: 'trap',
      query:
          'Si mon choix de conjoint me semble logique, pourquoi chercher encore le choix de Dieu plutôt que mon propre jugement ?',
      acceptableSermons: {'59-0418'},
      spanGroups: [
        ['choix', 'choice'],
        ['dieu', 'god'],
      ],
    ),
    AnswerCase(
      id: 'trap-marriage-character-not-beauty',
      category: 'trap',
      query:
          'Sans parler de beauté ni d argent, quel élément doit vraiment décider dans le choix d un conjoint ?',
      acceptableSermons: {'62-0720'},
      spanGroups: [
        ['caractere', 'character'],
      ],
    ),
    AnswerCase(
      id: 'trap-holy-spirit-teacher-not-emotion',
      category: 'trap',
      query:
          'Je ne demande pas si le Saint-Esprit donne une émotion : est-il présenté comme Celui qui enseigne l Église ?',
      acceptableSermons: {'58-0209A'},
      spanGroups: [
        ['enseignant', 'teacher'],
        ['eglise', 'church'],
      ],
    ),
    AnswerCase(
      id: 'trap-will-two-kinds',
      category: 'trap',
      query:
          'Quand deux formes de volonté de Dieu sont opposées, laquelle est parfaite et laquelle est seulement permissive ?',
      acceptableSermons: {'65-0427', '47-1123'},
      spanGroups: [
        ['permissive'],
        ['parfaite', 'perfect'],
      ],
    ),
    AnswerCase(
      id: 'trap-finance-payable-debt',
      category: 'trap',
      query:
          'Si j ai réellement les moyens de rembourser, dois-je quand même laisser une dette traîner ?',
      acceptableSermons: {'65-0822M'},
      spanGroups: [
        ['dette', 'dettes', 'debt', 'debts'],
        ['payer', 'pay', 'regler', 'duty'],
      ],
    ),
    AnswerCase(
      id: 'trap-finance-riches-dollars',
      category: 'trap',
      query:
          'Avoir beaucoup de dollars suffit-il à définir la vraie richesse selon le message ?',
      acceptableSermons: {'58-1221E'},
      spanGroups: [
        ['richesse', 'riches', 'rich'],
        ['dollars', 'argent', 'money'],
      ],
    ),
    AnswerCase(
      id: 'contradiction-prayer-immediate',
      category: 'contradictory',
      query:
          'Dieu répond forcément immédiatement à toute prière. Quel passage montre au contraire qu Il peut faire attendre ?',
      acceptableSermons: {'56-0513'},
      spanGroups: [
        ['attendre', 'wait', 'waiting', 'differer'],
      ],
    ),
    AnswerCase(
      id: 'contradiction-marriage-own-choice',
      category: 'contradictory',
      query:
          'Mon propre choix suffit et il est inutile de chercher celui de Dieu pour un conjoint. Quel passage corrige cette idée ?',
      acceptableSermons: {'59-0418'},
      spanGroups: [
        ['choix', 'choice'],
        ['dieu', 'god'],
      ],
    ),
    AnswerCase(
      id: 'contradiction-holy-spirit-not-teacher',
      category: 'contradictory',
      query:
          'Le Saint-Esprit n enseigne pas l Église. Quel passage permet de réfuter cette affirmation ?',
      acceptableSermons: {'58-0209A'},
      spanGroups: [
        ['enseignant', 'teacher'],
        ['eglise', 'church'],
      ],
    ),
    AnswerCase(
      id: 'contradiction-will-no-trouble',
      category: 'contradictory',
      query:
          'Sortir de la volonté de Dieu ne produit aucun problème. Existe-t-il un passage qui dit le contraire ?',
      acceptableSermons: {'53-1114'},
      spanGroups: [
        ['trouble', 'probleme', 'consequence'],
      ],
    ),
    AnswerCase(
      id: 'contradiction-riches-only-money',
      category: 'contradictory',
      query:
          'La richesse se mesure uniquement en argent et en dollars. Quel passage contredit cela ?',
      acceptableSermons: {'58-1221E'},
      spanGroups: [
        ['richesse', 'riches', 'rich'],
        ['dollars', 'argent', 'money'],
      ],
    ),
    AnswerCase(
      id: 'followup-prayer-why',
      category: 'follow-up',
      query: 'Et pourquoi ?',
      inheritedSubjectTerms: ['priere', 'reponse', 'attendre'],
      acceptableSermons: {'56-0513'},
      spanGroups: [
        ['attendre', 'wait', 'waiting', 'differer'],
      ],
    ),
    AnswerCase(
      id: 'followup-marriage-how',
      category: 'follow-up',
      query: 'Et comment alors ?',
      inheritedSubjectTerms: ['choisir', 'epouse', 'priere'],
      acceptableSermons: {'65-0429E'},
      spanGroups: [
        ['priere', 'pray'],
        ['epouse', 'wife', 'conjoint'],
      ],
    ),
  ];

  const abstainCases = <AbstainCase>[
    AbstainCase(
      'ood-speed-light',
      'Quelle est la vitesse de la lumière sur Mars ?',
    ),
    AbstainCase(
      'ood-world-cup',
      'Qui a gagné la Coupe du monde de football 2026 ?',
    ),
    AbstainCase(
      'ood-diesel',
      'Comment réparer un moteur diesel qui surchauffe ?',
    ),
    AbstainCase(
      'ood-phone',
      'Quel téléphone Android a la meilleure caméra en 2026 ?',
    ),
    AbstainCase(
      'ood-dinosaurs',
      'Pourquoi les dinosaures ont-ils disparu ?',
    ),
    AbstainCase(
      'ood-malaria',
      'Quel médicament guérit le paludisme ?',
    ),
    AbstainCase(
      'ambiguous-why',
      'Pourquoi ?',
      category: 'ambiguous',
    ),
    AbstainCase(
      'ambiguous-how-choose',
      'Comment choisir ?',
      category: 'ambiguous',
    ),
    AbstainCase(
      'ambiguous-before',
      'Que faut-il faire avant ?',
      category: 'ambiguous',
    ),
    AbstainCase(
      'ambiguous-important',
      'Est-ce vraiment important ?',
      category: 'ambiguous',
    ),
    AbstainCase(
      'no-answer-netflix-budget',
      'Quel budget mensuel William Branham recommande-t-il pour Netflix ?',
      category: 'lexical-decoy',
    ),
    AbstainCase(
      'no-answer-credit-rate-2026',
      'Quel taux d intérêt exact recommande-t-il pour un crédit bancaire en 2026 ?',
      category: 'lexical-decoy',
    ),
    AbstainCase(
      'no-answer-budget-percentage',
      'Quel pourcentage exact du salaire faut-il mettre dans un budget mensuel ?',
      category: 'lexical-decoy',
    ),
    AbstainCase(
      'no-answer-chatgpt',
      'Que dit William Branham sur ChatGPT ?',
      category: 'no-answer',
    ),
    AbstainCase(
      'no-answer-whatsapp',
      'Que dit William Branham sur WhatsApp et les smartphones Android ?',
      category: 'no-answer',
    ),
    AbstainCase(
      'no-answer-bitcoin-price',
      'Quel est le prix du Bitcoin aujourd hui ?',
      category: 'no-answer',
    ),
    AbstainCase(
      'no-answer-world-cup-2030',
      'Quelle équipe gagnera la Coupe du monde 2030 ?',
      category: 'no-answer',
    ),
  ];

  final dbPath = await rebuildCorpus();
  final repository = CorpusRepository()..open(dbPath);
  final curated = loadCurated();
  final service = SearchServiceV4(
    repository: repository,
    curatedReferenceIndex: curated,
  );

  var top1Sermon = 0;
  var top3Sermon = 0;
  var top1Span = 0;
  final answers = <Map<String, dynamic>>[];

  for (final item in answerCases) {
    final outcome = await service.searchOutcome(
      item.query,
      inherited: item.inheritedSubjectTerms.isEmpty
          ? const ConversationFilterSet()
          : ConversationFilterSet(
              subjectTerms: item.inheritedSubjectTerms,
            ),
      maxResults: 10,
    );
    final hits = outcome.hits;
    final topCodes = hits
        .take(3)
        .map((value) => value.hit.studyPassage.sermon?.code)
        .whereType<String>()
        .toList(growable: false);
    final top1Code = topCodes.isEmpty ? null : topCodes.first;
    final sermon1 = top1Code != null &&
        item.acceptableSermons.contains(top1Code);
    final sermon3 = topCodes.any(item.acceptableSermons.contains);
    var canonicalSpan = false;
    if (hits.isNotEmpty) {
      final top = hits.first.hit;
      final start = top.highlightStartOffset;
      final end = top.highlightEndOffset;
      canonicalSpan = start != null &&
          end != null &&
          start >= 0 &&
          end <= top.studyPassage.passage.text.length &&
          start < end &&
          top.studyPassage.passage.text.substring(start, end) ==
              top.highlightSentence;
    }
    final spanSemanticOk = hits.isNotEmpty &&
        spanMatches(hits.first.hit.highlightSentence, item.spanGroups);
    final spanOk = sermon1 && canonicalSpan && spanSemanticOk;
    if (sermon1) top1Sermon++;
    if (sermon3) top3Sermon++;
    if (spanOk) top1Span++;
    answers.add({
      'id': item.id,
      'category': item.category,
      'query': item.query,
      'inherited_subject_terms': item.inheritedSubjectTerms,
      'top1_sermon': top1Code,
      'top3_sermons': topCodes,
      'top1_sermon_ok': sermon1,
      'top3_sermon_ok': sermon3,
      'top1_span_ok': spanOk,
      'top1_span_is_canonical': canonicalSpan,
      'top1_span_semantic_ok': spanSemanticOk,
      'top1_passage_id':
          hits.isEmpty ? null : hits.first.hit.studyPassage.passage.id,
      'top1_start_offset':
          hits.isEmpty ? null : hits.first.hit.highlightStartOffset,
      'top1_end_offset':
          hits.isEmpty ? null : hits.first.hit.highlightEndOffset,
      'top1_confidence':
          hits.isEmpty ? null : hits.first.hit.answerConfidence,
      'top1_span':
          hits.isEmpty ? null : hits.first.hit.highlightSentence,
    });
  }

  var abstained = 0;
  final abstentions = <Map<String, dynamic>>[];
  for (final item in abstainCases) {
    final outcome = await service.searchOutcome(
      item.query,
      maxResults: 5,
    );
    final empty = outcome.hits.isEmpty;
    if (empty) abstained++;
    abstentions.add({
      'id': item.id,
      'category': item.category,
      'query': item.query,
      'abstained': empty,
      'top1_sermon': empty
          ? null
          : outcome.hits.first.hit.studyPassage.sermon?.code,
      'top1_confidence':
          empty ? null : outcome.hits.first.hit.answerConfidence,
      'top1_span':
          empty ? null : outcome.hits.first.hit.highlightSentence,
    });
  }

  final first = await service.searchOutcome(
    'Pourquoi certaines prières ne sont-elles pas exaucées à cause de l iniquité cachée ?',
    maxResults: 5,
  );
  final followUp = await service.searchOutcome(
    'Et pourquoi ?',
    inherited: first.filters,
    maxResults: 5,
  );

  final quotedSpec = service.coordinator.parser.parse(
    'Que signifie "recevoir le Saint-Esprit" ?',
  );
  final criterionSpec = service.coordinator.parser.parse(
    'Quel est le critère déterminant dans le choix du conjoint ?',
  );

  final strictPassed = top1Span + abstained;
  final totalCases = answerCases.length + abstainCases.length;
  final categories = <String, Map<String, int>>{};
  for (final row in answers) {
    final category = row['category'] as String;
    final bucket = categories.putIfAbsent(
      category,
      () => {'total': 0, 'passed': 0},
    );
    bucket['total'] = bucket['total']! + 1;
    if (row['top1_span_ok'] == true) {
      bucket['passed'] = bucket['passed']! + 1;
    }
  }
  for (final row in abstentions) {
    final category = row['category'] as String;
    final bucket = categories.putIfAbsent(
      category,
      () => {'total': 0, 'passed': 0},
    );
    bucket['total'] = bucket['total']! + 1;
    if (row['abstained'] == true) {
      bucket['passed'] = bucket['passed']! + 1;
    }
  }

  final report = <String, dynamic>{
    'report_version': 2,
    'strict_definition':
        'Answerable: expected sermon Top-1 + displayed span is an exact canonical substring + span matches every required evidence group. No-answer/ambiguous: zero returned hits.',
    'answer_cases': answerCases.length,
    'top1_sermon_rate': top1Sermon / answerCases.length,
    'top3_sermon_rate': top3Sermon / answerCases.length,
    'top1_answer_span_rate': top1Span / answerCases.length,
    'abstention_cases': abstainCases.length,
    'abstention_rate': abstained / abstainCases.length,
    'strict_end_to_end_passed': strictPassed,
    'strict_end_to_end_total': totalCases,
    'strict_end_to_end_rate': strictPassed / totalCases,
    'categories': {
      for (final entry in categories.entries)
        entry.key: {
          ...entry.value,
          'rate': entry.value['total'] == 0
              ? 0.0
              : entry.value['passed']! / entry.value['total']!,
        },
    },
    'follow_up': {
      'first_results': first.hits.length,
      'second_results': followUp.hits.length,
      'retained_subject': followUp.filters.subjectTerms,
    },
    'classification_probes': {
      'quoted_definition_is_natural':
          quotedSpec.isNaturalQuestion,
      'quoted_definition_intent':
          quotedSpec.questionIntent.name,
      'criterion_question_intent':
          criterionSpec.questionIntent.name,
    },
    'answers': answers,
    'abstentions': abstentions,
  };

  final encoded = const JsonEncoder.withIndent('  ').convert(report);
  stdout.writeln(encoded);

  final outputDir = Directory('build/relevance-audit')
    ..createSync(recursive: true);
  File('${outputDir.path}/answer_relevance_e2e_report.json')
      .writeAsStringSync('$encoded\n');

  final failures = <Map<String, dynamic>>[
    ...answers.where((row) => row['top1_span_ok'] != true),
    ...abstentions.where((row) => row['abstained'] != true),
  ];
  final summary = StringBuffer()
    ..writeln('# Answer relevance E2E audit')
    ..writeln()
    ..writeln('- Strict E2E: $strictPassed / $totalCases '
        '(${(strictPassed / totalCases * 100).toStringAsFixed(1)}%)')
    ..writeln('- Answerable Top-1 sermon: $top1Sermon / ${answerCases.length}')
    ..writeln('- Answerable strict span: $top1Span / ${answerCases.length}')
    ..writeln('- Correct abstentions: $abstained / ${abstainCases.length}')
    ..writeln()
    ..writeln('## Category rates');
  for (final entry in categories.entries) {
    final total = entry.value['total']!;
    final passed = entry.value['passed']!;
    summary.writeln(
      '- ${entry.key}: $passed / $total '
      '(${(passed / total * 100).toStringAsFixed(1)}%)',
    );
  }
  summary
    ..writeln()
    ..writeln('## Failures');
  for (final row in failures) {
    summary.writeln(
      '- ${row['id']} [${row['category']}]: ${row['query']}',
    );
  }
  File('${outputDir.path}/answer_relevance_e2e_summary.md')
      .writeAsStringSync(summary.toString());

  repository.close();
  try {
    File(dbPath).parent.deleteSync(recursive: true);
  } catch (_) {}
}
