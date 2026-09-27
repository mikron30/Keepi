import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const primary = Color(0xFFFF634D);
  static const secondary = Color(0xFFFF9A62);
  static const gold = Color(0xFFFFC15A);
  static const ink = Color(0xFF08111D);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: const Color(0xFF341100),
      tertiary: gold,
      onTertiary: const Color(0xFF2B1A00),
      surface: const Color(0xFFFFFBF8),
      onSurface: const Color(0xFF17171A),
      surfaceContainerHighest: const Color(0xFFF3E8E2),
    );

    return _build(
      scheme: scheme,
      scaffoldBackground: const Color(0xFFFFF7F2),
      fieldFill: Colors.white,
      cardColor: const Color(0xFFFFFCFA),
      darkMode: false,
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFFF6B53),
      onPrimary: Colors.white,
      secondary: const Color(0xFFFFA16E),
      onSecondary: const Color(0xFF321306),
      tertiary: const Color(0xFFFFC866),
      onTertiary: const Color(0xFF2B1A00),
      surface: const Color(0xFF0F1824),
      onSurface: const Color(0xFFF8F1ED),
      surfaceContainerHighest: const Color(0xFF1A2634),
      outlineVariant: const Color(0xFF34404D),
    );

    return _build(
      scheme: scheme,
      scaffoldBackground: const Color(0xFF07111D),
      fieldFill: const Color(0xFF111C29),
      cardColor: const Color(0xFF0F1A27),
      darkMode: true,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required Color fieldFill,
    required Color cardColor,
    required bool darkMode,
  }) {
    final outline = darkMode
        ? const Color(0xFF2A3948)
        : const Color(0xFFE7D8D0);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      fontFamilyFallback: const ['Arial', 'sans-serif'],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.45,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: darkMode
            ? const Color(0xFF0C1622)
            : const Color(0xFFFFFBF8),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.7),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          side: BorderSide(color: outline),
          foregroundColor: scheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkMode
            ? const Color(0xFF14202D)
            : const Color(0xFFFFF1EB),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkMode
            ? const Color(0xFF1A2634)
            : const Color(0xFF2A1A15),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
