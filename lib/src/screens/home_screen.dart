import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'grenier_home_screen.dart';

/// Compatibility wrapper for routes that still reference HomeScreen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GrenierHomeScreen(
      onStartConversation: AppScope.of(context).conversationController.startNewConversation,
    );
  }
}
