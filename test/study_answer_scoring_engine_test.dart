import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/study_certification/study_answer_scoring_engine.dart';
import 'package:le_grenier_du_message/src/study_certification/study_pack_models.dart';

StudyQuestion question({
  required StudyQuestionType type,
  List<StudyQuestionOption> options = const [],
  Object? correctAnswerPayload,
  Object? scoringPayload,
}) =>
    StudyQuestion(
      id: 1,
      sermonId: 1,
      packVersion: 1,
      type: type,
      category: StudyQuestionCategory.comprehension,
      difficulty: 4,
      prompt: 'Question',
      pedagogicalExplanation: 'Explication',
      validationStatus: StudyQuestionStatus.validated,
      certificationEligible: true,
      options: options,
      evidenceIds: const [1],
      correctAnswerPayload: correctAnswerPayload,
      scoringPayload: scoringPayload,
    );

void main() {
  const engine = StudyAnswerScoringEngine();

  test('single choice est noté depuis les options validées', () {
    final q = question(
      type: StudyQuestionType.singleChoice,
      options: const [
        StudyQuestionOption(
          id: 10,
          questionId: 1,
          ordinal: 0,
          text: 'A',
          isCorrect: false,
        ),
        StudyQuestionOption(
          id: 11,
          questionId: 1,
          ordinal: 1,
          text: 'B',
          isCorrect: true,
        ),
      ],
    );

    expect(engine.score(question: q, answerPayload: 11).score, 1);
    expect(engine.score(question: q, answerPayload: 10).score, 0);
  });

  test('multiple choice exige l’ensemble exact', () {
    final q = question(
      type: StudyQuestionType.multipleChoice,
      options: const [
        StudyQuestionOption(
          id: 1,
          questionId: 1,
          ordinal: 0,
          text: 'A',
          isCorrect: true,
        ),
        StudyQuestionOption(
          id: 2,
          questionId: 1,
          ordinal: 1,
          text: 'B',
          isCorrect: true,
        ),
        StudyQuestionOption(
          id: 3,
          questionId: 1,
          ordinal: 2,
          text: 'C',
          isCorrect: false,
        ),
      ],
    );

    expect(engine.score(question: q, answerPayload: [2, 1]).score, 1);
    expect(engine.score(question: q, answerPayload: [1]).score, 0);
    expect(engine.score(question: q, answerPayload: [1, 2, 3]).score, 0);
  });

  test('ordre raisonné utilise le payload validé', () {
    final q = question(
      type: StudyQuestionType.reasoningOrder,
      correctAnswerPayload: const {
        'correct_order': [3, 1, 2],
      },
    );
    expect(engine.score(question: q, answerPayload: [3, 1, 2]).score, 1);
    expect(engine.score(question: q, answerPayload: [1, 3, 2]).score, 0);
  });

  test('réponse courte reste locale et déterministe', () {
    final q = question(
      type: StudyQuestionType.shortAnswer,
      scoringPayload: const {
        'accepted_answers': ['La foi', 'foi'],
      },
    );
    expect(engine.score(question: q, answerPayload: '  LA FOI ').score, 1);
    expect(engine.score(question: q, answerPayload: 'espérance').score, 0);
  });

  test('réponse libre sans rubrique échoue fermée', () {
    final q = question(type: StudyQuestionType.synthesis);
    expect(engine.canScore(q), isFalse);
    expect(
      () => engine.score(question: q, answerPayload: 'texte libre'),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
