import 'package:flutter/material.dart';

abstract final class GrenierBrand {
  static const String name = 'Le Grenier du Message';
  static const String versionLabel = 'V4 – IR Expert';
  static const String tagline = 'Toute Sa Parole. Toujours avec vous. Hors ligne.';
  static const String offlineLabel = '100% hors ligne';
  static const String noAiLabel = 'Aucune IA générative';
  static const String canonicalOnlyLabel = 'Texte canonique uniquement';
}

abstract final class GrenierBreakpoints {
  static const double mobile = 760;
  static const double desktopWide = 1180;

  static bool isMobile(double width) => width < mobile;
  static bool isWideDesktop(double width) => width >= desktopWide;
}

abstract final class GrenierPalette {
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navyRaised = Color(0xFF17365D);
  static const Color actionBlue = Color(0xFF2563EB);
  static const Color actionBlueAlt = Color(0xFF147DDE);
  static const Color lightCanvas = Color(0xFFF6F8FC);
  static const Color lightCard = Colors.white;
  static const Color borderLight = Color(0xFFD9E2EF);
  static const Color highlightLight = Color(0xFFFFE9A3);
  static const Color highlightDark = Color(0xFF725C13);
  static const Color offlineGreen = Color(0xFF1F9D62);
}

abstract final class GrenierSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class GrenierRadii {
  static const double control = 14;
  static const double card = 16;
  static const double pill = 18;
}
