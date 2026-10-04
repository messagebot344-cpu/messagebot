import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../study_certification/study_answer_scoring_engine.dart';
import '../study_certification/study_exam_scoring_engine.dart';
import '../study_certification/study_exam_selection_engine.dart';
import '../study_certification/study_pack_models.dart';
import 'study_certificate_screen.dart';

class StudyExamScreen extends StatefulWidget {
  const StudyExamScreen({
    super.key,
    required this.sermon,
    required this.pack,
  });

  final SermonSummary sermon;
  final SermonStudyPackSummary pack;

  @override
  State<StudyExamScreen> createState() => _StudyExamScreenState();
}

class _StudyExamScreenState extends State<StudyExamScreen> {
  static const _scoring = StudyAnswerScoringEngine();
  static const _selectionEngine = StudyExamSelectionEngine();

  bool _initialized = false;
  bool _submitting = false;
  String? _error;
  _ExamRuntime? _runtime;
  StudyExamEvaluation? _evaluation;
  StudyCertification? _certification;
  final Map<int, Object?> _answers = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _initialize();
  }

  void _initialize() {
    try {
      final scope = AppScope.of(context);
      final rules = scope.studyPackRepository.examRules(
        widget.pack.sermonId,
        widget.pack.packVersion,
      );
      if (rules == null) {
        throw StateError('Règles d’examen non publiées.');
      }
      final pool = scope.studyPackRepository.certificationQuestionPool(
        widget.pack.sermonId,
        widget.pack.packVersion,
      );
      if (pool.isEmpty) {
        throw StateError('Banque de questions certifiantes vide.');
      }

      final recent = scope.studyProgressRepository.recentExamQuestionIds(
        sermonId: widget.pack.sermonId,
        packVersion: widget.pack.packVersion,
        attemptLimit: rules.recentQuestionExclusionCount,
      );
      final selection = _selectionEngine.select(
        rules: rules,
        pool: pool,
        recentQuestionIds: recent.toSet(),
      );
      final byId = {for (final question in pool) question.id: question};
      final questions = selection.questionIds
          .map((id) => byId[id])
          .whereType<StudyQuestion>()
          .toList(growable: false);
      if (questions.length != rules.examSize) {
        throw StateError('Sélection d’examen incomplète.');
      }
      final unsupported = questions
          .where((question) => !_scoring.canScore(question))
          .toList(growable: false);
      if (unsupported.isNotEmpty) {
        throw StateError(
          'Une question publiée ne possède pas de barème local fiable.',
        );
      }

      final attemptId = scope.studyProgressRepository.startExamAttempt(
        pack: widget.pack,
        rules: rules,
        sections: scope.studyPackRepository.sectionsFor(
          widget.pack.sermonId,
          widget.pack.packVersion,
        ),
        questionPool: pool,
        seed: selection.seed,
        questionIds: selection.questionIds,
        optionOrderByQuestion: selection.optionOrderByQuestion,
      );

      for (final question in questions) {
        if (question.type == StudyQuestionType.reasoningOrder) {
          _answers[question.id] =
              List<int>.from(selection.optionOrderByQuestion[question.id] ?? const []);
        }
      }

      setState(() {
        _runtime = _ExamRuntime(
          attemptId: attemptId,
          rules: rules,
          questions: questions,
          pool: pool,
          optionOrderByQuestion: selection.optionOrderByQuestion,
        );
      });
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  bool get _allAnswered {
    final runtime = _runtime;
    if (runtime == null) return false;
    for (final question in runtime.questions) {
      final value = _answers[question.id];
      if (value == null) return false;
      if (value is String && value.trim().isEmpty) return false;
      if (value is Iterable && value.isEmpty) return false;
    }
    return true;
  }

  List<StudyQuestionOption> _orderedOptions(StudyQuestion question) {
    final runtime = _runtime!;
    final ids = runtime.optionOrderByQuestion[question.id] ?? const <int>[];
    final byId = {for (final option in question.options) option.id: option};
    final ordered = ids
        .map((id) => byId[id])
        .whereType<StudyQuestionOption>()
        .toList(growable: true);
    if (ordered.length == question.options.length) return ordered;
    return List<StudyQuestionOption>.from(question.options);
  }

  Future<void> _submit() async {
    final runtime = _runtime;
    if (runtime == null || !_allAnswered || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final scope = AppScope.of(context);
      final scores = <int, double>{};
      for (final question in runtime.questions) {
        final answer = _answers[question.id];
        final scored = _scoring.score(
          question: question,
          answerPayload: answer,
        );
        scores[question.id] = scored.score;
        scope.studyProgressRepository.recordQuestionAttempt(
          questionId: question.id,
          sermonId: widget.pack.sermonId,
          packVersion: widget.pack.packVersion,
          context: 'exam',
          attemptId: runtime.attemptId,
          answerPayload: answer ?? const <String, Object?>{},
          score: scored.score,
        );
      }

      final evaluation = scope.studyProgressRepository.submitExamAttempt(
        attemptId: runtime.attemptId,
        rules: runtime.rules,
        questions: runtime.questions,
        scoresByQuestion: scores,
      );

      StudyCertification? certification;
      if (evaluation.passed) {
        certification = scope.studyProgressRepository.createCertification(
          attemptId: runtime.attemptId,
          pack: widget.pack,
          level: 'Certification',
          rules: runtime.rules,
          sections: scope.studyPackRepository.sectionsFor(
            widget.pack.sermonId,
            widget.pack.packVersion,
          ),
          questionPool: runtime.pool,
        );
      }

      if (!mounted) return;
      setState(() {
        _evaluation = evaluation;
        _certification = certification;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final evaluation = _evaluation;
    if (evaluation != null) {
      return _buildResult(context, evaluation);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examen final'),
      ),
      body: _error != null && _runtime == null
          ? _ErrorBody(message: _error!)
          : _runtime == null
              ? const Center(child: CircularProgressIndicator())
              : _buildExam(context),
    );
  }

  Widget _buildExam(BuildContext context) {
    final runtime = _runtime!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Text(
          widget.sermon.title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          widget.sermon.code,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Examen randomisé de ${runtime.rules.examSize} questions. '
              'Seuil de réussite : '
              '${(runtime.rules.passThreshold * 100).round()} %. '
              'Les réponses restent sur cet appareil.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < runtime.questions.length; index++) ...[
          _QuestionCard(
            number: index + 1,
            question: runtime.questions[index],
            orderedOptions: _orderedOptions(runtime.questions[index]),
            value: _answers[runtime.questions[index].id],
            onChanged: (value) {
              setState(() {
                _answers[runtime.questions[index].id] = value;
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: _allAnswered && !_submitting ? _submit : null,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.fact_check_outlined),
          label: Text(
            _submitting ? 'Correction…' : 'Soumettre l’examen',
          ),
        ),
      ],
    );
  }

  Widget _buildResult(
    BuildContext context,
    StudyExamEvaluation evaluation,
  ) {
    final passed = evaluation.passed;
    return Scaffold(
      appBar: AppBar(title: const Text('Résultat de l’examen')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        children: [
          Icon(
            passed
                ? Icons.workspace_premium_outlined
                : Icons.school_outlined,
            size: 72,
          ),
          const SizedBox(height: 16),
          Text(
            passed ? 'Examen réussi' : 'Examen à reprendre',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${(evaluation.overallScore * 100).toStringAsFixed(1)} %',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Scores par catégorie',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final entry in evaluation.categoryScores.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(_categoryLabel(entry.key))),
                          Text('${(entry.value * 100).toStringAsFixed(1)} %'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!passed)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Les bonnes réponses ne sont pas révélées après un échec. '
                  'Révise les sections concernées puis lance une nouvelle '
                  'tentative : une autre combinaison sera utilisée lorsque '
                  'la banque le permet.',
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (passed && _certification != null)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => StudyCertificateScreen(
                      sermon: widget.sermon,
                      certification: _certification!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('Voir le certificat'),
            )
          else
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Retourner à l’étude'),
            ),
        ],
      ),
    );
  }

  String _categoryLabel(String value) => switch (value) {
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.orderedOptions,
    required this.value,
    required this.onChanged,
  });

  final int number;
  final StudyQuestion question;
  final List<StudyQuestionOption> orderedOptions;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  bool get _isMultiple =>
      question.type == StudyQuestionType.multipleChoice;

  bool get _isOrder =>
      question.type == StudyQuestionType.reasoningOrder;

  bool get _isText =>
      orderedOptions.isEmpty && !_isOrder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question $number • difficulté ${question.difficulty}/5',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_isMultiple)
              ..._multipleChoice(context)
            else if (_isOrder)
              _orderedAnswer(context)
            else if (_isText)
              TextFormField(
                initialValue: value is String ? value as String : '',
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Votre réponse',
                  border: OutlineInputBorder(),
                ),
                onChanged: onChanged,
              )
            else
              ..._singleChoice(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _singleChoice(BuildContext context) {
    final selected = value is int ? value as int : null;
    return [
      RadioGroup<int>(
        groupValue: selected,
        onChanged: (next) => onChanged(next),
        child: Column(
          children: [
            for (final option in orderedOptions)
              RadioListTile<int>(
                value: option.id,
                contentPadding: EdgeInsets.zero,
                title: Text(option.text),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _multipleChoice(BuildContext context) {
    final selected = value is List<int>
        ? Set<int>.from(value as List<int>)
        : <int>{};
    return [
      for (final option in orderedOptions)
        CheckboxListTile(
          value: selected.contains(option.id),
          contentPadding: EdgeInsets.zero,
          title: Text(option.text),
          onChanged: (checked) {
            final next = Set<int>.from(selected);
            if (checked == true) {
              next.add(option.id);
            } else {
              next.remove(option.id);
            }
            onChanged(next.toList()..sort());
          },
        ),
    ];
  }

  Widget _orderedAnswer(BuildContext context) {
    final order = value is List<int>
        ? List<int>.from(value as List<int>)
        : orderedOptions.map((option) => option.id).toList();
    final byId = {for (final option in orderedOptions) option.id: option};
    return Column(
      children: [
        for (var index = 0; index < order.length; index++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(byId[order[index]]?.text ?? 'Option'),
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  tooltip: 'Monter',
                  onPressed: index == 0
                      ? null
                      : () {
                          final next = List<int>.from(order);
                          final item = next.removeAt(index);
                          next.insert(index - 1, item);
                          onChanged(next);
                        },
                  icon: const Icon(Icons.keyboard_arrow_up),
                ),
                IconButton(
                  tooltip: 'Descendre',
                  onPressed: index == order.length - 1
                      ? null
                      : () {
                          final next = List<int>.from(order);
                          final item = next.removeAt(index);
                          next.insert(index + 1, item);
                          onChanged(next);
                        },
                  icon: const Icon(Icons.keyboard_arrow_down),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Impossible de préparer l’examen.\n\n$message',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ExamRuntime {
  const _ExamRuntime({
    required this.attemptId,
    required this.rules,
    required this.questions,
    required this.pool,
    required this.optionOrderByQuestion,
  });

  final int attemptId;
  final StudyExamRules rules;
  final List<StudyQuestion> questions;
  final List<StudyQuestion> pool;
  final Map<int, List<int>> optionOrderByQuestion;
}
