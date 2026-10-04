import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'grenier_navigation.dart';

/// Compatibility adapter kept for older imports. New layouts should use
/// [GrenierDesktopSidebar] directly.
class ConversationSidebar extends StatelessWidget {
  const ConversationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    this.inDrawer = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final bool inDrawer;

  static const _legacyMap = <GrenierDestination>[
    GrenierDestination.conversations,
    GrenierDestination.library,
    GrenierDestination.concordance,
    GrenierDestination.collections,
    GrenierDestination.home,
    GrenierDestination.notes,
    GrenierDestination.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).conversationController;
    final safeIndex = selectedIndex.clamp(0, _legacyMap.length - 1);
    final selected = _legacyMap[safeIndex];

    void go(GrenierDestination destination) {
      final index = _legacyMap.indexOf(destination);
      onNavigate(index < 0 ? 0 : index);
      if (inDrawer && Navigator.of(context).canPop()) Navigator.of(context).pop();
    }

    if (inDrawer) {
      return GrenierDrawerNavigation(
        selected: selected,
        onSelect: go,
        onNewConversation: () {
          controller.startNewConversation();
          go(GrenierDestination.conversations);
        },
      );
    }

    return GrenierDesktopSidebar(
      selected: selected,
      onSelect: go,
      onNewConversation: () {
        controller.startNewConversation();
        go(GrenierDestination.conversations);
      },
      recentConversations: controller.conversations,
      selectedConversationId: controller.conversationId,
      onOpenConversation: (id) {
        controller.loadConversation(id);
        go(GrenierDestination.conversations);
      },
      onTogglePin: (summary) => controller.togglePin(summary.id, !summary.pinned),
      onDeleteConversation: controller.deleteConversation,
    );
  }
}
