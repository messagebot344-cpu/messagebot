import 'package:flutter/material.dart';

abstract final class GrenierBrand {
  static const String name = 'Le Grenier du Message';
  static const String versionLabel = 'V4 – IR Expert';
  static const String tagline =
      'Toute Sa Parole. Toujours avec vous. Hors ligne.';
  static const String offlineLabel = '100% hors ligne';
  static const String noAiLabel = 'Aucune IA générative';
  static const String canonicalOnlyLabel = 'Texte canonique uniquement';
}

abstract final class GrenierBreakpoints {
  static const double mobile = 760.0;
  static const double desktopWide = 1180.0;

  static bool isMobile(double width) => width < mobile;
  static bool isWideDesktop(double width) => width >= desktopWide;
}

abstract final class GrenierPalette {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color actionBlue = Color(0xFF2563EB);
  static const Color lightCanvas = Color(0xFFF6F8FC);
  static const Color highlightLight = Color(0xFFFFE9A8);
  static const Color offlineGreen = Color(0xFF22C55E);
  static const Color darkCanvas = Color(0xFF0F172A);
}

abstract final class GrenierRadii {
  static const double card = 14.0;
  static const double input = 16.0;
  static const double button = 12.0;
}

abstract final class GrenierSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}
