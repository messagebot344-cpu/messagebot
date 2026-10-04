import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'conversation/conversation_controller.dart';
import 'conversation/conversation_repository.dart';
import 'personal/personal_library.dart';
import 'personal/user_database.dart';
import 'screens/conversation_shell_screen.dart';
import 'services/corpus_installer.dart';
import 'services/corpus_repository.dart';
import 'services/preferences_service.dart';
import 'services/search_service_v4.dart';
import 'study/study_engine.dart';
import 'study_certification/study_pack_installer.dart';
import 'study_certification/study_pack_repository.dart';
import 'study_certification/study_progress_repository.dart';
import 'theme/grenier_theme.dart';
import 'theme/grenier_tokens.dart';

class GrenierBootstrap extends StatefulWidget {
  const GrenierBootstrap({super.key});

  @override
  State<GrenierBootstrap> createState() => _GrenierBootstrapState();
}

class _GrenierBootstrapState extends State<GrenierBootstrap> {
  double _progress = 0;
  String _message = 'Préparation…';
  Object? _error;
  _Runtime? _runtime;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    UserDatabase? pendingUserDatabase;
    CorpusRepository? pendingRepository;
    StudyPackRepository? pendingStudyPackRepository;
    ConversationController? pendingConversationController;
    try {
      final preferences = await PreferencesService.create();
      final controller = AppController(preferences);
      final userDatabase = await UserDatabase.createInAppSupport();
      pendingUserDatabase = userDatabase;
      final personalLibrary = PersonalLibrary(userDatabase);
      await personalLibrary.migrateFromLegacy(preferences);
      final install = await CorpusInstaller().ensureInstalled(
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = progress * 0.88;
            _message = message;
          });
        },
      );
      final repository = CorpusRepository()..open(install.databasePath);
      pendingRepository = repository;

      final corpusVersion = install.manifest['corpus_version'] as String;
      final canonicalSha =
          install.manifest['canonical_text_sha256'] as String;
      final studyInstall = await StudyPackInstaller().ensureInstalled(
        expectedCorpusVersion: corpusVersion,
        expectedCanonicalSha256: canonicalSha,
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = 0.88 + (progress * 0.10);
            _message = message;
          });
        },
      );
      final studyPackRepository = StudyPackRepository.open(
        studyInstall.databasePath,
        expectedCorpusVersion: corpusVersion,
        expectedCanonicalSha256: canonicalSha,
      );
      pendingStudyPackRepository = studyPackRepository;

      if (mounted) {
        setState(() {
          _progress = 0.99;
          _message = 'Initialisation de la recherche documentaire V4…';
        });
      }
      final searchService = SearchServiceV4(repository: repository);
      final studyEngine = StudyEngine(repository);
      final studyProgressRepository = StudyProgressRepository(userDatabase);
      final conversationRepository = ConversationRepository(userDatabase);
      final conversationController = ConversationController(
        repository: conversationRepository,
        searchService: searchService,
      );
      pendingConversationController = conversationController;
      if (!mounted) {
        conversationController.dispose();
        studyPackRepository.close();
        repository.close();
        userDatabase.close();
        return;
      }
      setState(() {
        _runtime = _Runtime(
          repository: repository,
          searchService: searchService,
          preferences: preferences,
          personalLibrary: personalLibrary,
          studyEngine: studyEngine,
          studyPackRepository: studyPackRepository,
          studyProgressRepository: studyProgressRepository,
          conversationController: conversationController,
          userDatabase: userDatabase,
          controller: controller,
        );
        _progress = 1;
        _message = 'Prêt';
      });
      pendingConversationController = null;
      pendingStudyPackRepository = null;
      pendingRepository = null;
      pendingUserDatabase = null;
    } catch (e) {
      pendingConversationController?.dispose();
      pendingStudyPackRepository?.close();
      pendingRepository?.close();
      pendingUserDatabase?.close();
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _runtime?.studyPackRepository.close();
    _runtime?.repository.close();
    _runtime?.userDatabase.close();
    _runtime?.conversationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: GrenierBrand.name,
        theme: MessageBotTheme.light(),
        darkTheme: MessageBotTheme.dark(),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: _error == null
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.menu_book_rounded, size: 68),
                        const SizedBox(height: 20),
                        Text(GrenierBrand.name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        const Text(GrenierBrand.versionLabel, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(GrenierBrand.tagline, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                        const SizedBox(height: 12),
                        Text(_message, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text('Aucune connexion internet ni IA générative n’est utilisée.', textAlign: TextAlign.center),
                      ])
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.error_outline_rounded, size: 56),
                        const SizedBox(height: 16),
                        const Text('Impossible de préparer les données locales.', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        SelectableText('$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _error = null;
                              _progress = 0;
                            });
                            _initialize();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: runtime.controller,
      builder: (context, _) => AppScope(
        repository: runtime.repository,
        searchService: runtime.searchService,
        preferences: runtime.preferences,
        personalLibrary: runtime.personalLibrary,
        studyEngine: runtime.studyEngine,
        studyPackRepository: runtime.studyPackRepository,
        studyProgressRepository: runtime.studyProgressRepository,
        conversationController: runtime.conversationController,
        controller: runtime.controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: GrenierBrand.name,
          themeMode: runtime.controller.themeMode,
          theme: MessageBotTheme.light(),
          darkTheme: MessageBotTheme.dark(),
          home: const ConversationShellScreen(),
        ),
      ),
    );
  }
}

class _Runtime {
  const _Runtime({
    required this.repository,
    required this.searchService,
    required this.preferences,
    required this.personalLibrary,
    required this.studyEngine,
    required this.studyPackRepository,
    required this.studyProgressRepository,
    required this.conversationController,
    required this.userDatabase,
    required this.controller,
  });

  final CorpusRepository repository;
  final SearchServiceV4 searchService;
  final PreferencesService preferences;
  final PersonalLibrary personalLibrary;
  final StudyEngine studyEngine;
  final StudyPackRepository studyPackRepository;
  final StudyProgressRepository studyProgressRepository;
  final ConversationController conversationController;
  final UserDatabase userDatabase;
  final AppController controller;
}
