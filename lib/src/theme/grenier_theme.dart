import 'package:flutter/material.dart';

import 'grenier_tokens.dart';

class MessageBotTheme {
  static const Color navy = GrenierPalette.navy;
  static const Color actionBlue = GrenierPalette.actionBlue;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: GrenierPalette.actionBlue,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: GrenierPalette.actionBlue,
        surface: GrenierPalette.lightCard,
        outlineVariant: GrenierPalette.borderLight,
      ),
      scaffoldBackgroundColor: GrenierPalette.lightCanvas,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: GrenierPalette.lightCard,
        foregroundColor: Color(0xFF18212F),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: GrenierPalette.lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.card),
          side: const BorderSide(color: GrenierPalette.borderLight),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 68),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.control),
          borderSide: const BorderSide(color: GrenierPalette.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.control),
          borderSide: const BorderSide(color: GrenierPalette.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.control),
          borderSide: const BorderSide(color: GrenierPalette.actionBlue, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(44, 44))),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: GrenierPalette.actionBlue,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: const Color(0xFF78A8FF),
        surface: const Color(0xFF172238),
        outlineVariant: const Color(0xFF33445F),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF172238),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: const Color(0xFF172238),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.card),
          side: const BorderSide(color: Color(0xFF33445F)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF172238),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(GrenierRadii.control)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.control),
          borderSide: const BorderSide(color: Color(0xFF33445F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.control),
          borderSide: const BorderSide(color: Color(0xFF78A8FF), width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(44, 44))),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(44, 44))),
      ),
    );
  }
}
