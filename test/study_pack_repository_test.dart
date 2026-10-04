import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_repository.dart';
import 'package:sqlite3/sqlite3.dart';

void createFixture(String path) {
  final db = sqlite3.open(path);
  final schema =
      File('tools/study_pipeline/study_pack_schema.sql').readAsStringSync();
  db.execute(schema);
  db.execute(
    "INSERT INTO study_pack_meta(key,value) VALUES"
    "('schema_version','1'),"
    "('packset_version','prototype-1'),"
    "('corpus_version','corpus-v4'),"
    "('corpus_canonical_sha256','canonical-sha')",
  );
  db.execute(
    "INSERT INTO study_packs("
    "sermon_id,sermon_code,title,pack_version,pack_schema_version,"
    "corpus_version,corpus_canonical_sha256,primary_edition_id,"
    "bible_pack_version,status,validation_status,generated_at,published_at"
    ") VALUES(1,'47-0412','La Foi Est l''Assurance',1,1,"
    "'corpus-v4','canonical-sha','e1',NULL,'published','validated',1,1)",
  );
  db.execute(
    "INSERT INTO study_paragraphs("
    "paragraph_key,sermon_id,pack_version,edition_id,passage_id,"
    "global_ordinal,start_offset,end_offset,source_page_start,"
    "source_page_end,text_sha256,character_count,printed_paragraph_number"
    ") VALUES('p1',1,1,'e1',10,0,0,20,3,3,'p1sha',20,'1')",
  );
  db.execute(
    "INSERT INTO study_sections("
    "id,sermon_id,pack_version,ordinal,title,kind,required_for_exam,"
    "minimum_reading_percent"
    ") VALUES(100,1,1,0,'Introduction','introduction',1,0.90)",
  );
  db.execute(
    "INSERT INTO study_section_paragraphs(section_id,paragraph_key,position) "
    "VALUES(100,'p1',0)",
  );
  db.execute(
    "INSERT INTO study_source_evidence("
    "id,sermon_id,pack_version,source_kind,evidence_role,edition_id,"
    "passage_id,paragraph_key,start_offset,end_offset,exact_quote,"
    "quote_sha256,source_page_start,source_page_end"
    ") VALUES(500,1,1,'sermon','correct_answer_support','e1',10,'p1',"
    "0,10,'Citation','quotesha',3,3)",
  );
  db.execute(
    "INSERT INTO study_questions("
    "id,sermon_id,pack_version,section_id,type,category,difficulty,"
    "prompt,pedagogical_explanation,correct_answer_payload,scoring_payload,"
    "validation_status,certification_eligible,generator_kind,created_at"
    ") VALUES(900,1,1,100,'single_choice','comprehension',4,"
    "'Quelle idée est soutenue ?','Explication pédagogique.','{}','{}',"
    "'validated',1,'deterministic',1)",
  );
  db.execute(
    "INSERT INTO study_question_options("
    "id,question_id,ordinal,option_text,is_correct"
    ") VALUES(901,900,0,'Bonne réponse',1),(902,900,1,'Distracteur',0)",
  );
  db.execute(
    "INSERT INTO study_question_evidence(question_id,evidence_id,evidence_role) "
    "VALUES(900,500,'correct_answer_support')",
  );
  db.execute(
    "INSERT INTO study_exam_rules("
    "sermon_id,pack_version,exam_size,pass_threshold,"
    "recent_question_exclusion_count,minimum_reading_percent,"
    "minimum_bank_multiplier"
    ") VALUES(1,1,1,0.85,2,0.95,2.4)",
  );
  db.execute(
    "INSERT INTO study_exam_category_rules("
    "sermon_id,pack_version,category,weight,question_count,minimum_score"
    ") VALUES(1,1,'comprehension',1.0,1,NULL)",
  );
  db.dispose();
}

void main() {
  test('repository accepte uniquement un Study Pack lié au bon corpus', () {
    final dir = Directory.systemTemp.createTempSync('grenier-study-pack-');
    final path = '${dir.path}/study_packs.db';
    createFixture(path);

    final repository = StudyPackRepository.open(
      path,
      expectedCorpusVersion: 'corpus-v4',
      expectedCanonicalSha256: 'canonical-sha',
    );
    expect(repository.publishedPackCount, 1);
    final pack = repository.latestPublishedPack(1)!;
    expect(pack.sermonCode, '47-0412');
    expect(pack.sectionCount, 1);
    expect(pack.validatedQuestionCount, 1);

    final sections = repository.sectionsFor(1, 1);
    expect(sections.single.paragraphKeys, ['p1']);

    final paragraphs = repository.paragraphsForSection(100);
    expect(paragraphs.single.passageId, 10);

    final questions = repository.certificationQuestionPool(1, 1);
    expect(questions.single.category, StudyQuestionCategory.comprehension);
    expect(questions.single.options.where((o) => o.isCorrect).single.text,
        'Bonne réponse');

    final evidence = repository.evidenceForQuestion(900);
    expect(evidence.single.exactQuote, 'Citation');

    final rules = repository.examRules(1, 1)!;
    expect(rules.passThreshold, 0.85);
    expect(rules.examSize, 1);
    expect(rules.minimumQuestionBankSize, 3);

    repository.close();
    dir.deleteSync(recursive: true);
  });

  test('repository refuse un hash canonique incompatible', () {
    final dir =
        Directory.systemTemp.createTempSync('grenier-study-pack-bad-sha-');
    final path = '${dir.path}/study_packs.db';
    createFixture(path);

    expect(
      () => StudyPackRepository.open(
        path,
        expectedCorpusVersion: 'corpus-v4',
        expectedCanonicalSha256: 'wrong-sha',
      ),
      throwsA(isA<StudyPackCompatibilityException>()),
    );

    dir.deleteSync(recursive: true);
  });
}
