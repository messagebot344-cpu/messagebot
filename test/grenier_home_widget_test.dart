import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/screens/grenier_home_screen.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';

void main() {
  testWidgets('mobile home matches Grenier brand hierarchy', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: MessageBotTheme.light(),
      home: GrenierHomeScreen(onStartConversation: () {}),
    ));

    expect(find.text('Le Grenier du Message'), findsOneWidget);
    expect(find.text('V4 – IR Expert'), findsOneWidget);
    expect(find.text('Toute Sa Parole.\nToujours avec vous.\nHors ligne.'), findsOneWidget);
    expect(find.text('Commencer une recherche'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
