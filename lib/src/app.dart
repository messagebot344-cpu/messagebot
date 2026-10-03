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
import 'theme/grenier_theme.dart';

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
    try {
      final preferences = await PreferencesService.create();
      final controller = AppController(preferences);
      final userDatabase = await UserDatabase.createInAppSupport();
      final personalLibrary = PersonalLibrary(userDatabase);
      await personalLibrary.migrateFromLegacy(preferences);
      final install = await CorpusInstaller().ensureInstalled(
        onProgress: (progress, message) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _message = message;
          });
        },
      );
      final repository = CorpusRepository()..open(install.databasePath);
      if (mounted) {
        setState(() {
          _progress = 0.96;
          _message = 'Initialisation de la recherche documentaire V4…';
        });
      }
      final searchService = SearchServiceV4(repository: repository);
      final studyEngine = StudyEngine(repository);
      final conversationRepository = ConversationRepository(userDatabase);
      final conversationController = ConversationController(
        repository: conversationRepository,
        searchService: searchService,
      );
      if (!mounted) return;
      setState(() {
        _runtime = _Runtime(
          repository: repository,
          searchService: searchService,
          preferences: preferences,
          personalLibrary: personalLibrary,
          studyEngine: studyEngine,
          conversationController: conversationController,
          userDatabase: userDatabase,
          controller: controller,
        );
        _progress = 1;
        _message = 'Prêt';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
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
        title: 'Message Bot',
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
                        Text('Message Bot', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text('Toute Sa Parole. Toujours avec vous. Hors ligne.', textAlign: TextAlign.center),
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
                        const Text('Impossible de préparer le corpus.', style: TextStyle(fontWeight: FontWeight.w700)),
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
        conversationController: runtime.conversationController,
        controller: runtime.controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Message Bot',
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
    required this.conversationController,
    required this.userDatabase,
    required this.controller,
  });

  final CorpusRepository repository;
  final SearchServiceV4 searchService;
  final PreferencesService preferences;
  final PersonalLibrary personalLibrary;
  final StudyEngine studyEngine;
  final ConversationController conversationController;
  final UserDatabase userDatabase;
  final AppController controller;
}
