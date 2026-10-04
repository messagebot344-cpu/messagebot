import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/grenier_tokens.dart';
import 'collections_screen.dart';
import 'concordance_screen.dart';
import 'conversation_screen.dart';
import 'grenier_navigation.dart';
import 'grenier_top_banner.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'personal_search_screen.dart';
import 'settings_screen.dart';
import 'study_screen.dart';
import 'timeline_screen.dart';

class ConversationShellScreen extends StatefulWidget {
  const ConversationShellScreen({super.key});

  @override
  State<ConversationShellScreen> createState() => _ConversationShellScreenState();
}

class _ConversationShellScreenState extends State<ConversationShellScreen> {
  GrenierDestination _selected = GrenierDestination.home;

  Widget _pageFor(GrenierDestination destination) => switch (destination) {
        GrenierDestination.home => const HomeScreen(),
        GrenierDestination.library => const LibraryScreen(),
        GrenierDestination.conversations => const ConversationScreen(),
        GrenierDestination.collections => const CollectionsScreen(),
        GrenierDestination.notes => const PersonalSearchScreen(),
        GrenierDestination.concordance => const ConcordanceScreen(),
        GrenierDestination.timeline => const TimelineScreen(),
        GrenierDestination.compare => const StudyScreen(),
        GrenierDestination.scripture => const StudyScreen(),
        GrenierDestination.settings => const SettingsScreen(),
      };

  void _select(GrenierDestination destination) {
    setState(() => _selected = destination);
  }

  void _newConversation() {
    final controller = AppScope.of(context).conversationController;
    controller.startNewConversation();
    _select(GrenierDestination.conversations);
  }

  void _openConversation(int id) {
    final controller = AppScope.of(context).conversationController;
    controller.loadConversation(id);
    _select(GrenierDestination.conversations);
  }

  @override
  Widget build(BuildContext context) {
    final conversationController = AppScope.of(context).conversationController;
    return AnimatedBuilder(
      animation: conversationController,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final page = KeyedSubtree(
            key: ValueKey(_selected),
            child: _pageFor(_selected),
          );
          if (!GrenierBreakpoints.isMobile(constraints.maxWidth)) {
            return Scaffold(
              body: Column(
                children: [
                  const GrenierTopBanner(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GrenierDesktopSidebar(
                          selected: _selected,
                          onSelect: _select,
                          onNewConversation: _newConversation,
                          recentConversations: conversationController.conversations,
                          onOpenConversation: _openConversation,
                          onConversationSearch: conversationController.setConversationSearch,
                        ),
                        Expanded(child: page),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text(
                GrenierBrand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      GrenierBrand.offlineLabel,
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            drawer: Drawer(
              child: GrenierNavigationDrawer(
                selected: _selected,
                onSelect: _select,
                onNewConversation: _newConversation,
                recentConversations: conversationController.conversations,
                onOpenConversation: _openConversation,
                onConversationSearch: conversationController.setConversationSearch,
              ),
            ),
            body: page,
            bottomNavigationBar: GrenierMobileNavigation(
              selected: _selected,
              onSelect: _select,
            ),
          );
        },
      ),
    );
  }
}
