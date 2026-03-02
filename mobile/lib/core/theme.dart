import 'package:flutter/material.dart';

/// AppColors defines every colour used in the Smart ISP Monitor app.
/// Using a central colour definition means if the client wants to
/// change the brand colour from blue to green, you change it in one
/// place and every screen updates automatically.
class AppColors {
  // Private constructor prevents this class from being instantiated.
  // It only exists to hold static constants.
  AppColors._();

  // ── Primary Brand Colours ───────────────────────────────────────────────
  // The main blue used for headers, buttons, and active states
  static const Color primary        = Color(0xFF1565C0);

  // A lighter shade of blue used for secondary elements and highlights
  static const Color primaryLight   = Color(0xFF1E88E5);

  // A very light blue used for card backgrounds and subtle highlights
  static const Color primarySurface = Color(0xFFE3F2FD);

  // Dark navy used for the app bar and important headings
  static const Color primaryDark    = Color(0xFF0D47A1);

  // ── Status Colours ──────────────────────────────────────────────────────
  // Green for online/healthy/success states
  static const Color online    = Color(0xFF2E7D32);
  static const Color onlineLight = Color(0xFFE8F5E9);

  // Orange for degraded/warning states
  static const Color degraded  = Color(0xFFE65100);
  static const Color degradedLight = Color(0xFFFFF3E0);

  // Red for offline/error/critical states
  static const Color offline   = Color(0xFFC62828);
  static const Color offlineLight = Color(0xFFFFEBEE);

  // Grey for unknown states
  static const Color unknown   = Color(0xFF546E7A);

  // ── Alert Severity Colours ──────────────────────────────────────────────
  static const Color severityLow      = Color(0xFF1565C0);
  static const Color severityMedium   = Color(0xFFE65100);
  static const Color severityHigh     = Color(0xFFB71C1C);
  static const Color severityCritical = Color(0xFF4A148C);

  // ── Neutral Colours ─────────────────────────────────────────────────────
  static const Color white       = Color(0xFFFFFFFF);
  static const Color background  = Color(0xFFF5F7FA);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color divider     = Color(0xFFE0E0E0);

  // ── Text Colours ────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint      = Color(0xFFBDBDBD);
  static const Color textOnDark    = Color(0xFFFFFFFF);
}


/// AppTheme builds the MaterialApp ThemeData object used throughout the app.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // ColorScheme tells Flutter which colours to use for various
      // built-in components like buttons, app bars, and text fields.
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary:   AppColors.primary,
        secondary: AppColors.primaryLight,
        surface:   AppColors.surface,
        background: AppColors.background,
        error:     AppColors.offline,
      ),

      scaffoldBackgroundColor: AppColors.background,

      // AppBar theme — controls the top navigation bar on every screen
      appBarTheme: const AppBarTheme(
        backgroundColor:  AppColors.primary,
        foregroundColor:  AppColors.textOnDark,
        elevation:        0,
        centerTitle:      false,
        titleTextStyle: TextStyle(
          color:      AppColors.textOnDark,
          fontSize:   20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),

      // Card theme — controls the appearance of Card widgets
      cardTheme: CardThemeData(
        color:     AppColors.surface,
        elevation: 2,
        // ignore: deprecated_member_use
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ElevatedButton theme — the main action button style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize:   16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // TextButton theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input decoration theme — controls all TextFormField and TextField
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical:   14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.offline),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle:  const TextStyle(color: AppColors.textHint),
      ),

      // BottomNavigationBar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.white,
        selectedItemColor:    AppColors.primary,
        unselectedItemColor:  AppColors.textSecondary,
        selectedLabelStyle:   TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color:     AppColors.divider,
        thickness: 1,
        space:     1,
      ),

      // Chip theme — used for filter chips on the devices screen
      chipTheme: ChipThemeData(
        backgroundColor:      AppColors.primarySurface,
        selectedColor:        AppColors.primary,
        labelStyle:           const TextStyle(fontSize: 13),
        padding:              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}