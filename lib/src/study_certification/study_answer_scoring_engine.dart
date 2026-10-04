import 'study_pack_models.dart';

class StudyAnswerScore {
  const StudyAnswerScore({
    required this.score,
    required this.isCorrect,
    required this.normalizedAnswer,
    required this.explanation,
  });

  final double score;
  final bool isCorrect;
  final Object? normalizedAnswer;
  final String explanation;
}

/// Deterministic, fully local answer scoring for certification questions.
///
/// A certification question is only auto-gradable when its format can be
/// evaluated from the validated Study Pack payload/options. Unsupported open
/// answers fail closed instead of being guessed or sent to a model.
class StudyAnswerScoringEngine {
  const StudyAnswerScoringEngine();

  bool canScore(StudyQuestion question) {
    try {
      _scoringKind(question);
      return true;
    } on UnsupportedError {
      return false;
    }
  }

  StudyAnswerScore score({
    required StudyQuestion question,
    required Object? answerPayload,
  }) {
    final kind = _scoringKind(question);
    return switch (kind) {
      _ScoringKind.singleOption => _scoreSingleOption(question, answerPayload),
      _ScoringKind.multiOption => _scoreMultiOption(question, answerPayload),
      _ScoringKind.orderedOptions => _scoreOrderedOptions(question, answerPayload),
      _ScoringKind.acceptedText => _scoreAcceptedText(question, answerPayload),
    };
  }

  _ScoringKind _scoringKind(StudyQuestion question) {
    switch (question.type) {
      case StudyQuestionType.multipleChoice:
        if (question.options.isEmpty) {
          throw UnsupportedError('QCM multiple sans options validées.');
        }
        return _ScoringKind.multiOption;
      case StudyQuestionType.reasoningOrder:
        if (_correctOrder(question).isEmpty) {
          throw UnsupportedError('Question d’ordre sans ordre validé.');
        }
        return _ScoringKind.orderedOptions;
      case StudyQuestionType.singleChoice:
      case StudyQuestionType.trueFalseJustified:
      case StudyQuestionType.quoteToContext:
      case StudyQuestionType.quoteToScripture:
      case StudyQuestionType.bestInterpretation:
      case StudyQuestionType.badInterpretation:
        if (question.options.isEmpty) {
          throw UnsupportedError('Question à choix sans options validées.');
        }
        return _ScoringKind.singleOption;
      case StudyQuestionType.fillBlank:
      case StudyQuestionType.shortAnswer:
      case StudyQuestionType.caseStudy:
      case StudyQuestionType.synthesis:
        if (question.options.isNotEmpty) {
          return _ScoringKind.singleOption;
        }
        if (_acceptedAnswers(question).isNotEmpty) {
          return _ScoringKind.acceptedText;
        }
        throw UnsupportedError(
          'Réponse libre sans rubrique déterministe validée.',
        );
    }
  }

  StudyAnswerScore _scoreSingleOption(
    StudyQuestion question,
    Object? answerPayload,
  ) {
    final selected = _singleOptionId(answerPayload);
    final correct = question.options
        .where((option) => option.isCorrect)
        .map((option) => option.id)
        .toList(growable: false);
    if (correct.length != 1) {
      throw UnsupportedError(
        'Une question à choix unique doit avoir exactement une option correcte.',
      );
    }
    final ok = selected != null && selected == correct.single;
    return StudyAnswerScore(
      score: ok ? 1 : 0,
      isCorrect: ok,
      normalizedAnswer: selected,
      explanation: ok ? 'Réponse correcte.' : 'Réponse incorrecte.',
    );
  }

  StudyAnswerScore _scoreMultiOption(
    StudyQuestion question,
    Object? answerPayload,
  ) {
    final selected = _optionIds(answerPayload).toSet();
    final correct = question.options
        .where((option) => option.isCorrect)
        .map((option) => option.id)
        .toSet();
    if (correct.isEmpty) {
      throw UnsupportedError('QCM multiple sans réponse correcte validée.');
    }
    final ok = selected.length == correct.length && selected.containsAll(correct);
    return StudyAnswerScore(
      score: ok ? 1 : 0,
      isCorrect: ok,
      normalizedAnswer: selected.toList()..sort(),
      explanation: ok
          ? 'Toutes les options correctes ont été sélectionnées.'
          : 'La sélection ne correspond pas exactement aux réponses validées.',
    );
  }

  StudyAnswerScore _scoreOrderedOptions(
    StudyQuestion question,
    Object? answerPayload,
  ) {
    final selected = _optionIds(answerPayload);
    final correct = _correctOrder(question);
    final ok = selected.length == correct.length &&
        List.generate(correct.length, (index) => selected[index] == correct[index])
            .every((value) => value);
    return StudyAnswerScore(
      score: ok ? 1 : 0,
      isCorrect: ok,
      normalizedAnswer: selected,
      explanation:
          ok ? 'Ordre correct.' : 'L’ordre ne correspond pas à la séquence validée.',
    );
  }

  StudyAnswerScore _scoreAcceptedText(
    StudyQuestion question,
    Object? answerPayload,
  ) {
    final raw = _answerText(answerPayload);
    final normalized = _normalizeText(raw);
    final accepted = _acceptedAnswers(question)
        .map(_normalizeText)
        .where((value) => value.isNotEmpty)
        .toSet();
    if (accepted.isEmpty) {
      throw UnsupportedError('Rubrique texte vide.');
    }
    final ok = normalized.isNotEmpty && accepted.contains(normalized);
    return StudyAnswerScore(
      score: ok ? 1 : 0,
      isCorrect: ok,
      normalizedAnswer: normalized,
      explanation: ok
          ? 'Réponse conforme à la rubrique validée.'
          : 'Réponse différente des formulations validées.',
    );
  }

  int? _singleOptionId(Object? payload) {
    if (payload is int) return payload;
    if (payload is num) return payload.toInt();
    if (payload is Map) {
      final value = payload['option_id'] ?? payload['optionId'];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return null;
  }

  List<int> _optionIds(Object? payload) {
    Object? value = payload;
    if (payload is Map) {
      value = payload['option_ids'] ??
          payload['optionIds'] ??
          payload['correct_order'] ??
          payload['order'];
    }
    if (value is! Iterable) return const [];
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .toList(growable: false);
  }

  List<int> _correctOrder(StudyQuestion question) {
    final payload = question.correctAnswerPayload;
    if (payload is Map) {
      final values = payload['correct_order'] ??
          payload['option_ids'] ??
          payload['optionIds'];
      if (values is Iterable) {
        return values
            .whereType<num>()
            .map((item) => item.toInt())
            .toList(growable: false);
      }
    }
    return const [];
  }

  List<String> _acceptedAnswers(StudyQuestion question) {
    final payloads = <Object?>[
      question.correctAnswerPayload,
      question.scoringPayload,
    ];
    for (final payload in payloads) {
      if (payload is String && payload.trim().isNotEmpty) {
        return [payload];
      }
      if (payload is Map) {
        final values = payload['accepted_answers'] ??
            payload['acceptedAnswers'] ??
            payload['answers'];
        if (values is Iterable) {
          return values
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false);
        }
        final single = payload['answer'] ?? payload['correct_answer'];
        if (single is String && single.trim().isNotEmpty) {
          return [single];
        }
      }
    }
    return const [];
  }

  String _answerText(Object? payload) {
    if (payload is String) return payload;
    if (payload is Map) {
      final value = payload['text'] ?? payload['answer'];
      if (value is String) return value;
    }
    return '';
  }

  String _normalizeText(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[’‘]'), "'")
      .replaceAll(RegExp(r"[^a-z0-9àâäçéèêëîïôöùûüÿœæ\\s'-]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

enum _ScoringKind {
  singleOption,
  multiOption,
  orderedOptions,
  acceptedText,
}
