import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';
import 'package:le_grenier_du_message/src/theme/grenier_tokens.dart';

void main() {
  test('Grenier brand and breakpoints are exact', () {
    expect(GrenierBrand.name, 'Le Grenier du Message');
    expect(GrenierBrand.versionLabel, 'V4 – IR Expert');
    expect(GrenierBrand.tagline, 'Toute Sa Parole. Toujours avec vous. Hors ligne.');
    expect(GrenierBrand.offlineLabel, '100% hors ligne');
    expect(GrenierBrand.noAiLabel, 'Aucune IA générative');
    expect(GrenierBrand.canonicalOnlyLabel, 'Texte canonique uniquement');
    expect(GrenierBreakpoints.mobile, 760.0);
    expect(GrenierBreakpoints.desktopWide, 1180.0);
  });

  test('light and dark themes expose Grenier action colors', () {
    expect(MessageBotTheme.light().colorScheme.primary, GrenierPalette.actionBlue);
    expect(MessageBotTheme.dark().brightness, Brightness.dark);
  });
}
