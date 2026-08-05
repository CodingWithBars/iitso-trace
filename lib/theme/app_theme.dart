import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TraceColors {
  // Primary (Black/Gray Theme)
  static const Color navyBlue = Color(0xFF121212); // Deep Black
  static const Color royalBlue = Color(0xFF242424); // Dark Gray
  static const Color midBlue = Color(0xFF333333); // Medium Gray
  static const Color lightBlue = Color(0xFF4F4F4F); // Light Gray

  // Accent (Orange Theme)
  static const Color gold = Color(0xFFFF6D00); // Bright Orange
  static const Color darkGold = Color(0xFFE65100); // Dark Orange
  static const Color lightGold = Color(0xFFFF9E80); // Light Orange

  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F7FA);
  static const Color black = Color(0xFF0A0A0A);
  static const Color darkGrey = Color(0xFF1C1C2E);
  static const Color medGrey = Color(0xFF4A4A6A);
  static const Color lightGrey = Color(0xFFB0BEC5);

  // Status Colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color late = Color(0xFFE65100); // Orange for late
  static const Color lateLight = Color(0xFFFFF3E0);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [navyBlue, royalBlue, midBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [darkGold, gold, lightGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [navyBlue, Color(0xFF1E1E1E)], // Darker gray
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: TraceColors.royalBlue,
        onPrimary: TraceColors.white,
        primaryContainer: TraceColors.midBlue,
        onPrimaryContainer: TraceColors.white,
        secondary: TraceColors.gold,
        onSecondary: TraceColors.navyBlue,
        secondaryContainer: TraceColors.lightGold,
        onSecondaryContainer: TraceColors.navyBlue,
        tertiary: TraceColors.navyBlue,
        onTertiary: TraceColors.white,
        tertiaryContainer: TraceColors.darkGrey,
        onTertiaryContainer: TraceColors.white,
        error: TraceColors.error,
        onError: TraceColors.white,
        surface: TraceColors.white,
        onSurface: TraceColors.black,
        surfaceContainerHighest: TraceColors.offWhite,
        outline: TraceColors.lightGrey,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: TraceColors.white,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: TraceColors.white,
        ),
        displaySmall: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: TraceColors.navyBlue,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: TraceColors.navyBlue,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: TraceColors.navyBlue,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TraceColors.navyBlue,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: TraceColors.black,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: TraceColors.medGrey,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: TraceColors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: TraceColors.white,
          letterSpacing: 1.2,
        ),
        iconTheme: const IconThemeData(color: TraceColors.gold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TraceColors.gold,
          foregroundColor: TraceColors.navyBlue,
          elevation: 2,
          shadowColor: TraceColors.gold.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TraceColors.royalBlue,
          side: const BorderSide(color: TraceColors.royalBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TraceColors.offWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TraceColors.lightGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TraceColors.lightGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TraceColors.royalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TraceColors.error, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
        hintStyle: GoogleFonts.inter(
          color: TraceColors.lightGrey,
          fontSize: 14,
        ),
        prefixIconColor: TraceColors.royalBlue,
      ),
      cardTheme: CardThemeData(
        elevation: 4,
        shadowColor: TraceColors.royalBlue.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: TraceColors.white,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: TraceColors.gold,
        unselectedLabelColor: TraceColors.lightGrey,
        indicatorColor: TraceColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: TraceColors.offWhite,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    );
  }
}
