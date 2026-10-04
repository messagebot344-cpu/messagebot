import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/screens/grenier_navigation.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

void main() {
  testWidgets('desktop navigation exposes approved destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: MessageBotTheme.light(),
      home: Scaffold(
        body: GrenierDesktopSidebar(
          selected: GrenierDestination.home,
          onSelect: (_) {},
          onNewConversation: () {},
          recentConversations: const [],
          onOpenConversation: (_) {},
        ),
      ),
    ));

    expect(find.text('Le Grenier du Message'), findsOneWidget);
    expect(find.text('+ Nouvelle conversation'), findsOneWidget);
    for (final label in const [
      'Accueil', 'Bibliothèque', 'Conversations', 'Collections', 'Notes',
      'Concordance', 'Chronologie', 'Comparer', 'Références bibliques', 'Réglages',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('mobile navigation keeps four primary destinations', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: MessageBotTheme.light(),
      home: Scaffold(
        bottomNavigationBar: GrenierMobileNavigation(
          selected: GrenierDestination.home,
          onSelect: (_) {},
        ),
      ),
    ));

    for (final label in const ['Accueil', 'Bibliothèque', 'Conversations', 'Réglages']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
