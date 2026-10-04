import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_grenier_du_message/src/theme/grenier_theme.dart';
import 'package:le_grenier_du_message/src/theme/grenier_tokens.dart';

void main() {
  test('Grenier brand and breakpoints are exact', () {
    expect(GrenierBrand.name, 'Le Grenier du Message');
    expect(GrenierBrand.versionLabel, 'V4 – IR Expert');
    expect(
      GrenierBrand.tagline,
      'Toute Sa Parole. Toujours avec vous. Hors ligne.',
    );
    expect(GrenierBrand.offlineLabel, '100% hors ligne');
    expect(GrenierBrand.noAiLabel, 'Aucune IA générative');
    expect(GrenierBrand.canonicalOnlyLabel, 'Texte canonique uniquement');
    expect(GrenierBreakpoints.mobile, 760.0);
    expect(GrenierBreakpoints.desktopWide, 1180.0);
    expect(GrenierBreakpoints.isMobile(759.0), isTrue);
    expect(GrenierBreakpoints.isMobile(760.0), isFalse);
    expect(GrenierBreakpoints.isWideDesktop(1180.0), isTrue);
  });

  test('Grenier light and dark themes use approved brand colors', () {
    final light = MessageBotTheme.light();
    final dark = MessageBotTheme.dark();

    expect(GrenierPalette.navy, const Color(0xFF0B1F3A));
    expect(GrenierPalette.actionBlue, const Color(0xFF2563EB));
    expect(GrenierPalette.lightCanvas, const Color(0xFFF6F8FC));
    expect(GrenierPalette.offlineGreen, const Color(0xFF22C55E));

    expect(light.colorScheme.primary, GrenierPalette.actionBlue);
    expect(light.scaffoldBackgroundColor, GrenierPalette.lightCanvas);
    expect(dark.colorScheme.primary, GrenierPalette.actionBlue);
  });
}
