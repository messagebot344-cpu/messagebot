import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/grenier_tokens.dart';
import 'collections_screen.dart';
import 'comparison_picker_screen.dart';
import 'concordance_screen.dart';
import 'conversation_screen.dart';
import 'grenier_home_screen.dart';
import 'grenier_navigation.dart';
import 'grenier_top_banner.dart';
import 'highlights_screen.dart';
import 'library_screen.dart';
import 'personal_search_screen.dart';
import 'settings_screen.dart';
import 'scripture_references_screen.dart';
import 'timeline_screen.dart';

class ConversationShellScreen extends StatefulWidget {
  const ConversationShellScreen({super.key});

  @override
  State<ConversationShellScreen> createState() => _ConversationShellScreenState();
}

class _ConversationShellScreenState extends State<ConversationShellScreen> {
  GrenierDestination _destination = GrenierDestination.home;

  void _select(GrenierDestination value, {bool closeDrawer = false}) {
    setState(() => _destination = value);
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _newConversation({bool closeDrawer = false}) {
    AppScope.of(context).conversationController.startNewConversation();
    _select(GrenierDestination.conversations, closeDrawer: closeDrawer);
  }

  Widget _pageFor(GrenierDestination destination) {
    return switch (destination) {
      GrenierDestination.home => GrenierHomeScreen(onStartConversation: _newConversation),
      GrenierDestination.library => const LibraryScreen(),
      GrenierDestination.conversations => const ConversationScreen(),
      GrenierDestination.collections => const CollectionsScreen(),
      GrenierDestination.notes => const PersonalSearchScreen(),
      GrenierDestination.highlights => const HighlightsScreen(),
      GrenierDestination.concordance => const ConcordanceScreen(),
      GrenierDestination.timeline => const TimelineScreen(),
      GrenierDestination.compare => const ComparisonPickerScreen(),
      GrenierDestination.scripture => const ScriptureReferencesScreen(),
      GrenierDestination.settings => const SettingsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).conversationController;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final mobile = GrenierBreakpoints.isMobile(width);
            final wide = GrenierBreakpoints.isWideDesktop(width);
            final page = KeyedSubtree(
              key: ValueKey(_destination),
              child: _pageFor(_destination),
            );

            if (wide) {
              return Scaffold(
                body: Column(
                  children: [
                    const GrenierTopBanner(),
                    Expanded(
                      child: Row(
                        children: [
                          GrenierDesktopSidebar(
                            selected: _destination,
                            onSelect: _select,
                            onNewConversation: _newConversation,
                            recentConversations: controller.conversations,
                            selectedConversationId: controller.conversationId,
                            onOpenConversation: (id) {
                              controller.loadConversation(id);
                              _select(GrenierDestination.conversations);
                            },
                            onTogglePin: (summary) => controller.togglePin(summary.id, !summary.pinned),
                            onDeleteConversation: controller.deleteConversation,
                          ),
                          Expanded(child: page),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (!mobile) {
              return Scaffold(
                appBar: const PreferredSize(preferredSize: Size.fromHeight(104), child: GrenierTopBanner()),
                drawer: GrenierDrawerNavigation(
                  selected: _destination,
                  onSelect: (value) => _select(value, closeDrawer: true),
                  onNewConversation: () => _newConversation(closeDrawer: true),
                ),
                body: page,
              );
            }

            return Scaffold(
              appBar: AppBar(
                titleSpacing: 0,
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(GrenierBrand.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(GrenierBrand.versionLabel, style: TextStyle(fontSize: 10.5)),
                  ],
                ),
                actions: const [
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Center(
                      child: Icon(Icons.cloud_off_rounded, color: GrenierPalette.offlineGreen, semanticLabel: GrenierBrand.offlineLabel),
                    ),
                  ),
                ],
              ),
              drawer: GrenierDrawerNavigation(
                selected: _destination,
                onSelect: (value) => _select(value, closeDrawer: true),
                onNewConversation: () => _newConversation(closeDrawer: true),
              ),
              body: page,
              bottomNavigationBar: GrenierMobileNavigation(
                selected: _destination,
                onSelect: _select,
              ),
            );
          },
        );
      },
    );
  }
}
