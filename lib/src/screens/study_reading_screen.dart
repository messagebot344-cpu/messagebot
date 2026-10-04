import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../app_scope.dart';
import '../models/models.dart';
import '../study_certification/study_pack_models.dart';

class StudyReadingScreen extends StatefulWidget {
  const StudyReadingScreen({
    super.key,
    required this.sermon,
    required this.pack,
    this.initialSectionId,
  });

  final SermonSummary sermon;
  final SermonStudyPackSummary pack;
  final int? initialSectionId;

  @override
  State<StudyReadingScreen> createState() => _StudyReadingScreenState();
}

class _StudyReadingScreenState extends State<StudyReadingScreen>
    with WidgetsBindingObserver {
  final ItemPositionsListener _positions = ItemPositionsListener.create();
  final ItemScrollController _scrollController = ItemScrollController();

  List<StudyParagraph> _paragraphs = const [];
  List<StudySection> _sections = const [];
  Map<int, String> _canonicalTextByPassage = const {};
  Map<String, StudySection> _sectionStartByParagraph = const {};
  Timer? _timer;
  bool _active = true;
  bool _loaded = false;
  Object? _error;
  int _initialIndex = 0;
  double _readingPercent = 0;
  int _completedSections = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    try {
      _load();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _recordVisibleActivity(),
      );
    } catch (error) {
      _error = error;
    }
  }

  void _load() {
    final scope = AppScope.of(context);
    final paragraphs = scope.studyPackRepository.paragraphsForSermon(
      widget.pack.sermonId,
      widget.pack.packVersion,
    );
    final sections = scope.studyPackRepository.sectionsFor(
      widget.pack.sermonId,
      widget.pack.packVersion,
    );
    final details = scope.repository.studyDetailsForPassageIds(
      paragraphs.map((paragraph) => paragraph.passageId).toSet(),
    );

    final textByPassage = <int, String>{};
    for (final paragraph in paragraphs) {
      final detail = details[paragraph.passageId];
      if (detail == null) {
        throw StateError(
          'Passage canonique introuvable: ${paragraph.passageId}.',
        );
      }
      final text = detail.passage.text;
      if (paragraph.startOffset < 0 ||
          paragraph.endOffset > text.length ||
          paragraph.startOffset >= paragraph.endOffset) {
        throw StateError(
          'Offsets Study Pack invalides pour ${paragraph.paragraphKey}.',
        );
      }
      final exact = text.substring(
        paragraph.startOffset,
        paragraph.endOffset,
      );
      final actualHash =
          sha256.convert(utf8.encode(exact)).toString();
      if (actualHash != paragraph.textSha256) {
        throw StateError(
          'Le texte d’étude ne correspond plus au corpus canonique.',
        );
      }
      textByPassage[paragraph.passageId] = text;
    }

    final sectionStarts = <String, StudySection>{};
    for (final section in sections) {
      if (section.paragraphKeys.isNotEmpty) {
        sectionStarts[section.paragraphKeys.first] = section;
      }
    }

    final progress = scope.studyProgressRepository.ensureProgress(
      sermonId: widget.pack.sermonId,
      packVersion: widget.pack.packVersion,
    );

    var initialIndex = 0;
    final sectionId = widget.initialSectionId;
    if (sectionId != null) {
      final section = sections.where((item) => item.id == sectionId).firstOrNull;
      if (section != null && section.paragraphKeys.isNotEmpty) {
        final index = paragraphs.indexWhere(
          (paragraph) =>
              paragraph.paragraphKey == section.paragraphKeys.first,
        );
        if (index >= 0) initialIndex = index;
      }
    } else if (progress.lastParagraphKey != null) {
      final index = paragraphs.indexWhere(
        (paragraph) =>
            paragraph.paragraphKey == progress.lastParagraphKey,
      );
      if (index >= 0) initialIndex = index;
    }

    _paragraphs = paragraphs;
    _sections = sections;
    _canonicalTextByPassage = textByPassage;
    _sectionStartByParagraph = sectionStarts;
    _initialIndex = initialIndex;
    _readingPercent = progress.readingPercent;
    _completedSections = scope.studyProgressRepository.completedSectionCount(
      widget.pack.sermonId,
      widget.pack.packVersion,
    );
  }

  Future<void> _recordVisibleActivity() async {
    if (!mounted || !_active || _paragraphs.isEmpty) return;
    final visible = _positions.itemPositions.value;
    if (visible.isEmpty) return;

    final scope = AppScope.of(context);
    var countedAny = false;
    for (final position in visible) {
      if (position.index < 0 || position.index >= _paragraphs.length) {
        continue;
      }
      final visibleStart = math.max(0.0, position.itemLeadingEdge);
      final visibleEnd = math.min(1.0, position.itemTrailingEdge);
      final ratio = (visibleEnd - visibleStart).clamp(0.0, 1.0).toDouble();
      if (ratio < 0.60) continue;
      countedAny = true;
      final paragraph = _paragraphs[position.index];
      scope.studyProgressRepository.recordParagraphActivity(
        sermonId: widget.pack.sermonId,
        packVersion: widget.pack.packVersion,
        paragraph: paragraph,
        allParagraphs: _paragraphs,
        visibleMilliseconds: 1000,
        visibleRatio: ratio,
        appIsActive: true,
        studyScreenIsActive: true,
      );
      scope.studyProgressRepository.setResumePosition(
        sermonId: widget.pack.sermonId,
        packVersion: widget.pack.packVersion,
        paragraphKey: paragraph.paragraphKey,
        passageId: paragraph.passageId,
        offset: paragraph.startOffset,
      );
    }

    if (!countedAny) return;
    scope.studyProgressRepository.addActiveStudySeconds(
      sermonId: widget.pack.sermonId,
      packVersion: widget.pack.packVersion,
      seconds: 1,
      appIsActive: true,
      studyScreenIsActive: true,
    );

    for (final section in _sections) {
      final sectionKeys = section.paragraphKeys.toSet();
      final sectionParagraphs = _paragraphs
          .where(
            (paragraph) => sectionKeys.contains(paragraph.paragraphKey),
          )
          .toList(growable: false);
      final percent =
          scope.studyProgressRepository.readingPercentForParagraphs(
        sermonId: widget.pack.sermonId,
        packVersion: widget.pack.packVersion,
        paragraphs: sectionParagraphs,
      );
      final state = percent >= section.minimumReadingPercent
          ? StudySectionState.completed
          : percent > 0
              ? StudySectionState.inProgress
              : StudySectionState.available;
      scope.studyProgressRepository.updateSectionProgress(
        sermonId: widget.pack.sermonId,
        packVersion: widget.pack.packVersion,
        sectionId: section.id,
        state: state,
        readingPercent: percent,
      );
    }

    final progress = scope.studyProgressRepository.progress(
      widget.pack.sermonId,
      widget.pack.packVersion,
    );
    if (progress == null) return;
    final completed = scope.studyProgressRepository.completedSectionCount(
      widget.pack.sermonId,
      widget.pack.packVersion,
    );
    if (mounted &&
        (progress.readingPercent != _readingPercent ||
            completed != _completedSections)) {
      setState(() {
        _readingPercent = progress.readingPercent;
        _completedSections = completed;
      });
    }
  }

  String _paragraphText(StudyParagraph paragraph) {
    final source = _canonicalTextByPassage[paragraph.passageId]!;
    return source.substring(paragraph.startOffset, paragraph.endOffset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Étude certifiante')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible d’ouvrir ce parcours d’étude.\n\n$_error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.sermon.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Étude certifiante • ${(_readingPercent * 100).round()} %',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _readingPercent),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_completedSections/${_sections.length} sections terminées',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '${(_readingPercent * 100).toStringAsFixed(1)} %',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ScrollablePositionedList.builder(
              itemCount: _paragraphs.length,
              initialScrollIndex:
                  _paragraphs.isEmpty ? 0 : _initialIndex,
              itemPositionsListener: _positions,
              itemScrollController: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              itemBuilder: (context, index) {
                final paragraph = _paragraphs[index];
                final section =
                    _sectionStartByParagraph[paragraph.paragraphKey];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (section != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        section.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          _paragraphText(paragraph),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.55),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
