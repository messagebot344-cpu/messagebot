import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/models/models.dart';
import 'package:le_grenier_du_message/src/offline_ai/offline_ai_citation_ranker.dart';
import 'package:le_grenier_du_message/src/search_v4/curated_reference_index.dart';

CuratedReferenceIndex loadFullIndex() {
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

CuratedReferenceIndex smallIndex() {
  const references = <String, CuratedSermonReference>{
    'prayer': CuratedSermonReference(
      id: 'prayer',
      sermonCode: 'TEST-1',
      sermonTitle: 'Prayer And Faith',
      locator: '§1',
      context:
          'Prayer answered by faith; doubt and unbelief hinder receiving.',
      anchorTerms: ['prayer', 'faith', 'doubt', 'unbelief'],
      sourceIndexId: 'test',
      corpusResolved: true,
    ),
    'money': CuratedSermonReference(
      id: 'money',
      sermonCode: 'TEST-2',
      sermonTitle: 'Stewardship',
      locator: '§1',
      context: 'Work, debt, money and faithful stewardship.',
      anchorTerms: ['money', 'work', 'debt', 'stewardship'],
      sourceIndexId: 'test',
      corpusResolved: true,
    ),
  };
  const topics = <CuratedReferenceTopic>[
    CuratedReferenceTopic(
      id: 'prayer_topic',
      label: 'Prière et foi',
      aliases: ['prière de foi', 'prière non exaucée'],
      keywords: ['prière', 'foi', 'doute', 'incrédulité'],
      referenceIds: ['prayer'],
      sourceIndexId: 'test',
    ),
    CuratedReferenceTopic(
      id: 'money_topic',
      label: 'Finances',
      aliases: ['finances chrétiennes'],
      keywords: ['argent', 'dette', 'travail'],
      referenceIds: ['money'],
      sourceIndexId: 'test',
    ),
  ];
  return CuratedReferenceIndex(
    references: references,
    topics: topics,
  );
}

StudyPassage passage({
  required int id,
  required String text,
  required String code,
}) {
  final sermonId = id;
  return StudyPassage(
    passage: Passage(
      id: id,
      editionId: 'edition-$id',
      sermonId: sermonId,
      ordinal: 1,
      sourcePageStart: 1,
      sourcePageEnd: 1,
      text: text,
    ),
    source: CorpusSourceSummary(
      id: 'source-$id',
      type: CorpusSourceType.sermon,
      title: code,
      code: code,
      year: 1960,
    ),
    sermon: SermonSummary(
      id: sermonId,
      code: code,
      title: code,
      year: 1960,
      editionCount: 1,
      primaryEditionId: 'edition-$id',
    ),
    edition: EditionSummary(
      id: 'edition-$id',
      sermonId: sermonId,
      title: 'Édition principale',
      isPrimary: true,
      isFrn: true,
      sourcePageStart: 1,
      sourcePageEnd: 1,
    ),
  );
}

void main() {
  test('toutes les références actives sont incluses dans le classement local', () {
    final ranker = OfflineAiCitationRanker.fromIndex(loadFullIndex());

    expect(ranker.activeReferenceCount, 1767);
  });

  test('la question 30 minutes retrouve Church Order 63-1226', () {
    final ranker = OfflineAiCitationRanker.fromIndex(loadFullIndex());
    final matches = ranker.rankReferences(
      'Pourquoi faut-il venir environ trente minutes avant le service et rester révérencieux ?',
      limit: 20,
    );

    expect(
      matches.any(
        (match) => match.reference.sermonCode == '63-1226',
      ),
      isTrue,
    );
  });

  test('la matrice de questions naturelles reste ancrée aux bons fascicules', () {
    final ranker = OfflineAiCitationRanker.fromIndex(loadFullIndex());

    const cases = <({String query, String sourceIndexId})>[
      (
        query:
            'Je prie depuis longtemps mais je ne reçois pas de réponse. Qu est-ce qui peut bloquer ma prière ?',
        sourceIndexId: 'curated-prayer-fasting-v1',
      ),
      (
        query:
            'Comment reconnaître une bonne église et un pasteur fidèle à la Parole ?',
        sourceIndexId: 'curated-marriage-choice-church-v1',
      ),
      (
        query:
            'Comment comprendre la volonté de Dieu quand je ne vois pas pourquoi une situation arrive ?',
        sourceIndexId: 'curated-gods-will-mystery-v1',
      ),
      (
        query:
            'Que signifie recevoir le Saint-Esprit comme sceau et puissance de Dieu ?',
        sourceIndexId: 'curated-holy-spirit-v1',
      ),
      (
        query:
            'Comment servir Dieu sans imiter un ministère ou un don spirituel ?',
        sourceIndexId: 'curated-doctrine-service-1060-v1',
      ),
      (
        query:
            'Comment gérer les dettes, le travail et l argent dans une famille chrétienne ?',
        sourceIndexId: 'curated-finance-family-deliverance-200-v1',
      ),
    ];

    for (final item in cases) {
      final matches = ranker.rankReferences(item.query, limit: 20);
      expect(
        matches.take(12).any(
              (match) =>
                  match.reference.sourceIndexId == item.sourceIndexId,
            ),
        isTrue,
        reason: item.query,
      );
    }
  });

  test('une requête sans sens ne fabrique aucune pertinence', () {
    final ranker = OfflineAiCitationRanker.fromIndex(loadFullIndex());
    final matches = ranker.rankReferences(
      'zxqv jklm qzxw nvbk',
      limit: 20,
    );

    expect(matches, isEmpty);
  });

  test('le rang canonique préfère le passage qui répond réellement', () {
    final ranker = OfflineAiCitationRanker.fromIndex(
      smallIndex(),
      minPassageScore: 0.02,
    );

    final good = passage(
      id: 1,
      code: 'TEST-1',
      text:
          'Quand vous priez, croyez ce que Dieu a promis. Le doute et l incrédulité empêchent une personne de recevoir la réponse. La foi prend Dieu à Sa Parole.',
    );
    final bad = passage(
      id: 2,
      code: 'TEST-2',
      text:
          'Un homme doit travailler honnêtement, payer ses dettes et gérer avec sagesse l argent et les dépenses de sa maison.',
    );

    final matches = ranker.rankPassages(
      'Pourquoi ma prière peut-elle rester sans réponse à cause du doute et de l incrédulité ?',
      [bad, good],
    );

    expect(matches, isNotEmpty);
    expect(matches.first.passageId, 1);
    expect(matches.first.sentence, isNotNull);

    final sentence = matches.first.sentence!;
    final selected = good.passage.text.substring(
      sentence.startOffset,
      sentence.endOffset,
    );
    expect(
      selected.toLowerCase(),
      anyOf(contains('doute'), contains('incrédulité')),
    );
  });

  test('les vecteurs canoniques sont réutilisés entre deux questions', () {
    final ranker = OfflineAiCitationRanker.fromIndex(
      smallIndex(),
      minPassageScore: 0.02,
    );
    final good = passage(
      id: 1,
      code: 'TEST-1',
      text:
          'Quand vous priez, croyez ce que Dieu a promis. Le doute et l incrédulité empêchent une personne de recevoir la réponse.',
    );
    final bad = passage(
      id: 2,
      code: 'TEST-2',
      text:
          'Un homme travaille honnêtement et gère avec sagesse les dépenses de sa maison.',
    );

    final first = ranker.rankPassages(
      'Pourquoi le doute peut-il empêcher une prière d être exaucée ?',
      [bad, good],
    );
    expect(first, isNotEmpty);
    expect(ranker.cachedPassageCount, 2);

    final second = ranker.rankPassages(
      'Quel rôle la foi joue-t-elle dans la prière ?',
      [bad, good],
    );
    expect(second, isNotEmpty);
    expect(ranker.cachedPassageCount, 2);
  });

  test('une forte référence humaine ne force jamais un mauvais passage', () {
    final ranker = OfflineAiCitationRanker.fromIndex(
      smallIndex(),
      minPassageScore: 0.35,
    );
    final unrelated = passage(
      id: 2,
      code: 'TEST-2',
      text:
          'The farmer repaired the fence and counted the sacks in the barn before sunset.',
    );

    final matches = ranker.rankPassages(
      'Pourquoi ma prière n est-elle pas exaucée ?',
      [unrelated],
      referencePriors: const {2: 1.0},
    );

    expect(matches, isEmpty);
  });

  test('le classeur retourne des identifiants, pas du texte inventé', () {
    final ranker = OfflineAiCitationRanker.fromIndex(smallIndex());
    final matches = ranker.rankReferences(
      'Que faire quand le doute bloque la prière ?',
    );

    expect(matches, isNotEmpty);
    expect(matches.first.reference.id, isNotEmpty);
    expect(matches.first.reference.sermonCode, isNotEmpty);
  });
}
