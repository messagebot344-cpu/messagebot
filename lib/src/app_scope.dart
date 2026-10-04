import 'package:flutter/widgets.dart';

import 'conversation/conversation_controller.dart';
import 'personal/personal_library.dart';
import 'services/corpus_repository.dart';
import 'services/preferences_service.dart';
import 'services/search_service_v4.dart';
import 'study/study_engine.dart';
import 'study_certification/study_pack_repository.dart';
import 'study_certification/study_progress_repository.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.searchService,
    required this.preferences,
    required this.personalLibrary,
    required this.studyEngine,
    required this.studyPackRepository,
    required this.studyProgressRepository,
    required this.conversationController,
    required this.controller,
    required super.child,
  });

  final CorpusRepository repository;
  final SearchServiceV4 searchService;
  final PreferencesService preferences;
  final PersonalLibrary personalLibrary;
  final StudyEngine studyEngine;
  final StudyPackRepository studyPackRepository;
  final StudyProgressRepository studyProgressRepository;
  final ConversationController conversationController;
  final AppController controller;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope absent de l’arbre.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      controller != oldWidget.controller ||
      repository != oldWidget.repository ||
      searchService != oldWidget.searchService ||
      studyEngine != oldWidget.studyEngine ||
      studyPackRepository != oldWidget.studyPackRepository ||
      studyProgressRepository != oldWidget.studyProgressRepository ||
      personalLibrary != oldWidget.personalLibrary ||
      conversationController != oldWidget.conversationController;
}
