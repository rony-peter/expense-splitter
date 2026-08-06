import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0A0A0B);
  static const secondaryBg = Color(0xFF1C1C1E);
  static const tertiaryBg = Color(0xFF2A2A2C);
  static const separator = Color(0x1FFFFFFF);
  static const labelPrimary = Colors.white;
  static const labelSecondary = Color(0x99FFFFFF);
  static const labelTertiary = Color(0x59FFFFFF);
  static const green = Color(0xFFB6FF3D);
  static const greenDeep = Color(0xFF7CD936);
  static const redAccent = Color(0xFFFF453A);
}

class AppTheme {
  static ThemeData get darkTheme {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.secondaryBg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.labelPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.labelPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.labelPrimary.withValues(alpha: 0.04),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.green, width: 1.4),
        ),
        labelStyle:
            const TextStyle(color: AppColors.labelTertiary, fontSize: 14.5),
      ),
      cardTheme: CardThemeData(
        color: AppColors.secondaryBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(baseTheme.textTheme),
    );
  }
}
