import 'package:flutter/material.dart';

import 'grenier_tokens.dart';

class MessageBotTheme {
  static const Color navy = GrenierPalette.navy;
  static const Color actionBlue = GrenierPalette.actionBlue;

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: GrenierPalette.actionBlue,
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: GrenierPalette.actionBlue,
      surface: Colors.white,
      surfaceContainerLowest: Colors.white,
    );
    final border = BorderSide(color: scheme.outlineVariant);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: GrenierPalette.lightCanvas,
      focusColor: GrenierPalette.actionBlue.withValues(alpha: 0.16),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.card),
          side: border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
          borderSide: const BorderSide(
            color: GrenierPalette.actionBlue,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrenierPalette.actionBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GrenierRadii.button),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.button),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: GrenierPalette.actionBlue,
      brightness: Brightness.dark,
    );
    final scheme = base.copyWith(
      primary: GrenierPalette.actionBlue,
      surface: const Color(0xFF111C30),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: GrenierPalette.darkCanvas,
      focusColor: GrenierPalette.actionBlue.withValues(alpha: 0.26),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GrenierRadii.input),
          borderSide: const BorderSide(
            color: GrenierPalette.actionBlue,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrenierPalette.actionBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GrenierRadii.button),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
    );
  }
}
