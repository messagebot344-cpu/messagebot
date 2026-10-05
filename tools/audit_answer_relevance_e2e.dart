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
  });

  final String id;
  final String query;
  final Set<String> acceptableSermons;
  final List<List<String>> spanGroups;
}

class AbstainCase {
  const AbstainCase(this.id, this.query);
  final String id;
  final String query;
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
    AbstainCase('ambiguous-why', 'Pourquoi ?'),
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
    final spanOk = sermon1 &&
        hits.isNotEmpty &&
        spanMatches(hits.first.hit.highlightSentence, item.spanGroups);
    if (sermon1) top1Sermon++;
    if (sermon3) top3Sermon++;
    if (spanOk) top1Span++;
    answers.add({
      'id': item.id,
      'query': item.query,
      'top1_sermon': top1Code,
      'top3_sermons': topCodes,
      'top1_sermon_ok': sermon1,
      'top3_sermon_ok': sermon3,
      'top1_span_ok': spanOk,
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

  final report = <String, dynamic>{
    'answer_cases': answerCases.length,
    'top1_sermon_rate': top1Sermon / answerCases.length,
    'top3_sermon_rate': top3Sermon / answerCases.length,
    'top1_answer_span_rate': top1Span / answerCases.length,
    'abstention_cases': abstainCases.length,
    'abstention_rate': abstained / abstainCases.length,
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

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(report),
  );

  repository.close();
  try {
    File(dbPath).parent.deleteSync(recursive: true);
  } catch (_) {}
}
