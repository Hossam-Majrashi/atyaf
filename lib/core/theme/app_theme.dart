import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const accent = Color(0xFF8C87DF);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF212327) : const Color(0xFFEFEEF1);
    final surface = dark ? const Color(0xFF232627) : const Color(0xFFFEFEFE);
    final text = dark ? const Color(0xFFCDCCCA) : const Color(0xFF212327);
    final border = dark ? const Color(0x14FFFFFF) : const Color(0x0F000000);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          surface: surface,
          onSurface: text,
          primary: accent,
          outline: border,
          outlineVariant: border,
        );
    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(surface),
      foregroundColor: WidgetStatePropertyAll(text),
      side: WidgetStatePropertyAll(BorderSide(color: border)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: buttonStyle.copyWith(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border),
    );
  }
}
