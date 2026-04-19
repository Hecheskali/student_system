import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF155EEF);
  static const Color _surface = Color(0xFFF5F7FB);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      secondary: const Color(0xFF0F766E),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    final TextTheme textTheme = ThemeData(brightness: Brightness.light)
        .textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w700,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
          labelMedium: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      colorScheme: scheme,
      scaffoldBackgroundColor: _surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF0F172A),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F4FF),
        selectedColor: scheme.primary,
        disabledColor: const Color(0xFFF0F2F8),
        labelStyle: textTheme.labelLarge!,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          backgroundColor: const Color(0xFF155EEF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          foregroundColor: const Color(0xFF0F172A),
          side: const BorderSide(color: Color(0xFFD7DEEA)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF64748B),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE3EF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFDCE3EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF155EEF), width: 1.3),
        ),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE4ECFF),
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.labelMedium,
        ),
      ),
    );
  }
}
