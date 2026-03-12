import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppColors
// ─────────────────────────────────────────────────────────────────────────────
/// Every colour token used in the Smart ISP Monitor app.
/// All values are compile-time constants — zero runtime overhead.
///
/// Files that import this:
///   theme.dart (self), utils.dart, every screen, every widget
class AppColors {
  AppColors._();

  // ── Primary Brand ─────────────────────────────────────────────────────────
  static const Color primary            = Color(0xFF2563EB); // blue-600
  static const Color primaryLight       = Color(0xFF3B82F6); // blue-500
  static const Color primaryDark        = Color(0xFF1D4ED8); // blue-700
  static const Color primarySurface     = Color(0xFFEFF6FF); // blue-50  (light)
  static const Color primaryDarkSurface = Color(0xFF1E3A5F); // navy     (dark)

  // ── Device / Network Status ───────────────────────────────────────────────
  static const Color online        = Color(0xFF16A34A); // green-600
  static const Color onlineLight   = Color(0xFFDCFCE7); // green-100
  static const Color onlineDark    = Color(0xFF14532D); // green-900

  static const Color degraded      = Color(0xFFD97706); // amber-600
  static const Color degradedLight = Color(0xFFFEF3C7); // amber-100
  static const Color degradedDark  = Color(0xFF451A03); // amber-950

  static const Color offline       = Color(0xFFDC2626); // red-600
  static const Color offlineLight  = Color(0xFFFEE2E2); // red-100
  static const Color offlineDark   = Color(0xFF450A0A); // red-950

  static const Color maintenance      = Color(0xFF7C3AED); // violet-600
  static const Color maintenanceLight = Color(0xFFEDE9FE); // violet-100
  static const Color maintenanceDark  = Color(0xFF2E1065); // violet-950

  static const Color unknown = Color(0xFF64748B); // slate-500

  // ── Alert Severity ────────────────────────────────────────────────────────
  static const Color severityLow      = Color(0xFF2563EB); // blue
  static const Color severityMedium   = Color(0xFFD97706); // amber
  static const Color severityHigh     = Color(0xFFDC2626); // red
  static const Color severityCritical = Color(0xFF7C3AED); // violet

  // ── Neutrals — Light ─────────────────────────────────────────────────────
  static const Color white          = Color(0xFFFFFFFF);
  static const Color background     = Color(0xFFF1F5F9); // slate-100
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC); // slate-50
  static const Color divider        = Color(0xFFE2E8F0); // slate-200
  static const Color border         = Color(0xFFCBD5E1); // slate-300

  // ── Neutrals — Dark ───────────────────────────────────────────────────────
  static const Color darkBackground     = Color(0xFF0F172A); // slate-900
  static const Color darkSurface        = Color(0xFF1E293B); // slate-800
  static const Color darkSurfaceVariant = Color(0xFF334155); // slate-700
  static const Color darkDivider        = Color(0xFF334155); // slate-700
  static const Color darkBorder         = Color(0xFF475569); // slate-600

  // ── Text — Light ──────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color textHint      = Color(0xFF94A3B8); // slate-400
  static const Color textOnDark    = Color(0xFFFFFFFF);

  // ── Text — Dark ───────────────────────────────────────────────────────────
  static const Color darkTextPrimary   = Color(0xFFF1F5F9); // slate-100
  static const Color darkTextSecondary = Color(0xFF94A3B8); // slate-400
  static const Color darkTextHint      = Color(0xFF64748B); // slate-500

  // ── App Bar Gradient stops ────────────────────────────────────────────────
  static const Color appBarGradientStart = Color(0xFF0D47A1); // blue-900
  static const Color appBarGradientEnd   = Color(0xFF1565C0); // blue-800

  // ── Context-aware adaptive helpers ────────────────────────────────────────
  // Use these in build methods instead of the static const tokens above so
  // the correct value is returned for both light and dark mode.
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      _isDark(context) ? darkBackground : background;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? darkSurface : surface;

  static Color surfaceVariantOf(BuildContext context) =>
      _isDark(context) ? darkSurfaceVariant : surfaceVariant;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? darkTextSecondary : textSecondary;

  static Color textHintOf(BuildContext context) =>
      _isDark(context) ? darkTextHint : textHint;

  static Color dividerOf(BuildContext context) =>
      _isDark(context) ? darkDivider : divider;

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? darkBorder : border;

  static Color primarySurfaceOf(BuildContext context) =>
      _isDark(context) ? primaryDarkSurface : primarySurface;
}

// ─────────────────────────────────────────────────────────────────────────────
// AppShadows
// ─────────────────────────────────────────────────────────────────────────────
/// Reusable shadow definitions used on cards, sheets, and elevated surfaces.
///
/// Every card in the app should use AppShadows.card so shadow style is
/// consistent and can be updated in one place.
///
/// Files that import this:
///   Every widget/screen that builds a Container with a boxShadow
class AppShadows {
  AppShadows._();

  /// Standard card shadow — tight + diffuse double shadow for depth
  static List<BoxShadow> get card => [
        BoxShadow(
          color:      Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset:     const Offset(0, 2),
        ),
        BoxShadow(
          color:      Colors.black.withOpacity(0.03),
          blurRadius: 16,
          offset:     const Offset(0, 8),
        ),
      ];

  /// Stronger shadow for hero/featured cards (uptime banner, etc.)
  static List<BoxShadow> get heroCard => [
        BoxShadow(
          color:      AppColors.primary.withOpacity(0.25),
          blurRadius: 20,
          offset:     const Offset(0, 8),
        ),
        BoxShadow(
          color:      Colors.black.withOpacity(0.08),
          blurRadius: 6,
          offset:     const Offset(0, 2),
        ),
      ];

  /// Subtle shadow for chips and small containers
  static List<BoxShadow> get small => [
        BoxShadow(
          color:      Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset:     const Offset(0, 1),
        ),
      ];

  /// Bottom sheet / modal shadow (cast upward)
  static List<BoxShadow> get bottomSheet => [
        BoxShadow(
          color:      Colors.black.withOpacity(0.12),
          blurRadius: 24,
          offset:     const Offset(0, -4),
        ),
      ];

  /// Status glow — tinted by the status colour, used on status dots
  static List<BoxShadow> statusGlow(Color color) => [
        BoxShadow(
          color:        color.withOpacity(0.45),
          blurRadius:   6,
          spreadRadius: 1,
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTextStyles
// ─────────────────────────────────────────────────────────────────────────────
/// Reusable text style definitions to keep typography consistent.
///
/// Use these directly instead of hardcoding fontSize/fontWeight everywhere.
/// Screens and widgets import AppTextStyles alongside AppColors.
///
/// Files that import this:
///   Every screen and widget that renders Text()
class AppTextStyles {
  AppTextStyles._();

  // ── Display — KPI numbers, uptime ────────────────────────────────────────
  static const TextStyle display = TextStyle(
    fontSize:      28,
    fontWeight:    FontWeight.w800,
    letterSpacing: -0.8,
    color:         AppColors.textPrimary,
    height:        1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize:      22,
    fontWeight:    FontWeight.bold,
    letterSpacing: -0.5,
    color:         AppColors.textPrimary,
    height:        1.2,
  );

  // ── Headings ──────────────────────────────────────────────────────────────
  static const TextStyle heading1 = TextStyle(
    fontSize:      19,
    fontWeight:    FontWeight.w700,
    letterSpacing: 0.1,
    color:         AppColors.textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize:      16,
    fontWeight:    FontWeight.bold,
    letterSpacing: -0.2,
    color:         AppColors.textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize:      14,
    fontWeight:    FontWeight.w600,
    color:         AppColors.textPrimary,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize:   14,
    fontWeight: FontWeight.w400,
    color:      AppColors.textPrimary,
    height:     1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize:   13,
    fontWeight: FontWeight.w400,
    color:      AppColors.textSecondary,
    height:     1.4,
  );

  // ── Labels ────────────────────────────────────────────────────────────────
  static const TextStyle label = TextStyle(
    fontSize:   12,
    fontWeight: FontWeight.w500,
    color:      AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle labelBold = TextStyle(
    fontSize:   12,
    fontWeight: FontWeight.w700,
    color:      AppColors.textPrimary,
    letterSpacing: 0.3,
  );

  // ── Captions — IP addresses, timestamps, metadata ────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize:   11,
    fontWeight: FontWeight.w400,
    color:      AppColors.textHint,
  );

  static const TextStyle captionBold = TextStyle(
    fontSize:   11,
    fontWeight: FontWeight.w600,
    color:      AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  // ── Monospace — IP addresses, CLI commands ────────────────────────────────
  static const TextStyle mono = TextStyle(
    fontSize:   13,
    fontFamily: 'monospace',
    color:      AppColors.textPrimary,
    height:     1.6,
  );

  static const TextStyle monoSmall = TextStyle(
    fontSize:   11,
    fontFamily: 'monospace',
    color:      AppColors.textSecondary,
  );

  // ── App Bar title ─────────────────────────────────────────────────────────
  static const TextStyle appBarTitle = TextStyle(
    color:         Colors.white,
    fontSize:      19,
    fontWeight:    FontWeight.w700,
    letterSpacing: 0.1,
  );

  static const TextStyle appBarSubtitle = TextStyle(
    color:      Colors.white60,
    fontSize:   11,
    fontWeight: FontWeight.w400,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AppTheme
// ─────────────────────────────────────────────────────────────────────────────
/// Builds both [lightTheme] and [darkTheme] for MaterialApp.
///
/// Usage in main.dart:
///   theme:     AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ThemeMode.system,   // or read from SettingsProvider
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────────────────
  // Shared component themes
  // ─────────────────────────────────────────────────────────────────────────

  static CardThemeData _cardTheme(Color surface, Color borderColor) =>
      CardThemeData(
        color:        surface,
        elevation:    0,
        shadowColor:  Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      );

  static ElevatedButtonThemeData _elevatedBtn(Color bg) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          minimumSize:     const Size(double.infinity, 52),
          elevation:       0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize:      15,
            fontWeight:    FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedBtn(Color fg, Color border) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize:     const Size(double.infinity, 52),
          side:            BorderSide(color: border),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static TextButtonThemeData _textBtn(Color fg) => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: fg,
          textStyle: const TextStyle(
            fontSize:   14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static ChipThemeData _chipTheme(Color bg, Color selected) => ChipThemeData(
        backgroundColor: bg,
        selectedColor:   selected,
        labelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      );

  static SnackBarThemeData _snackBarTheme() => SnackBarThemeData(
        backgroundColor:  const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(
          color:      Colors.white,
          fontSize:   14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.primaryLight,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 4,
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Light Theme
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    const cs = ColorScheme(
      brightness:           Brightness.light,
      primary:              AppColors.primary,
      onPrimary:            Colors.white,
      primaryContainer:     AppColors.primarySurface,
      onPrimaryContainer:   AppColors.primaryDark,
      secondary:            AppColors.primaryLight,
      onSecondary:          Colors.white,
      secondaryContainer:   AppColors.primarySurface,
      onSecondaryContainer: AppColors.primaryDark,
      surface:              AppColors.surface,
      onSurface:            AppColors.textPrimary,
      error:                AppColors.offline,
      onError:              Colors.white,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: AppColors.background,

      // ── Typography ──────────────────────────────────────────────────────
      // Requires fonts/Inter in pubspec.yaml — see integration notes below
      fontFamily: 'Inter',

      // ── App Bar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor:  AppColors.primary,
        foregroundColor:  Colors.white,
        elevation:        0,
        scrolledUnderElevation: 0,
        centerTitle:      false,
        titleTextStyle:   AppTextStyles.appBarTitle,
        iconTheme:        IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.light,
          statusBarBrightness:      Brightness.dark,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: _cardTheme(
          AppColors.surface, const Color(0x18000000)),

      // ── Buttons ───────────────────────────────────────────────────────────
      elevatedButtonTheme:  _elevatedBtn(AppColors.primary),
      outlinedButtonTheme:  _outlinedBtn(AppColors.primary, AppColors.primary),
      textButtonTheme:      _textBtn(AppColors.primary),

      // ── Navigation Bar (Material 3) ───────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor:       AppColors.white,
        indicatorColor:        AppColors.primarySurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(
              color: AppColors.textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w500,
            color:      AppColors.textSecondary,
          );
        }),
        elevation:            3,
        shadowColor:          Colors.black.withOpacity(0.08),
        labelBehavior:        NavigationDestinationLabelBehavior.alwaysShow,
        height:               64,
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),

      // ── Legacy Bottom Nav (kept for compatibility) ────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.white,
        selectedItemColor:    AppColors.primary,
        unselectedItemColor:  AppColors.textSecondary,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type:      BottomNavigationBarType.fixed,
        elevation: 12,
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: _chipTheme(
          AppColors.primarySurface, AppColors.primary),

      // ── Input Fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.offline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.offline, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle:  const TextStyle(color: AppColors.textHint),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // ── Tab Bar ───────────────────────────────────────────────────────────
      tabBarTheme: const TabBarThemeData(
        labelColor:            Colors.white,
        unselectedLabelColor:  Colors.white70,
        indicatorColor:        Colors.white,
        labelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppColors.divider,
        thickness: 1,
        space:     1,
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary.withOpacity(0.5)
              : AppColors.border,
        ),
      ),

      // ── Snack Bar ─────────────────────────────────────────────────────────
      snackBarTheme: _snackBarTheme(),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation:       8,
        shadowColor:     Colors.black.withOpacity(0.15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        titleTextStyle:   AppTextStyles.heading1,
        contentTextStyle: AppTextStyles.body,
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:    AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        elevation:          0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ── Icons ─────────────────────────────────────────────────────────────
      iconTheme: const IconThemeData(color: AppColors.textSecondary),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation:       3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:            AppColors.primary,
        linearTrackColor: AppColors.primarySurface,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Dark Theme
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    const cs = ColorScheme(
      brightness:           Brightness.dark,
      primary:              AppColors.primaryLight,
      onPrimary:            Colors.white,
      primaryContainer:     AppColors.primaryDarkSurface,
      onPrimaryContainer:   AppColors.primarySurface,
      secondary:            AppColors.primaryLight,
      onSecondary:          Colors.white,
      secondaryContainer:   AppColors.primaryDarkSurface,
      onSecondaryContainer: AppColors.primarySurface,
      surface:              AppColors.darkSurface,
      onSurface:            AppColors.darkTextPrimary,
      error:                Color(0xFFF87171),
      onError:              Colors.white,
    );

    return ThemeData(
      useMaterial3:            true,
      colorScheme:             cs,
      scaffoldBackgroundColor: AppColors.darkBackground,
      fontFamily:              'Inter',

      appBarTheme: const AppBarTheme(
        backgroundColor:        AppColors.darkSurface,
        foregroundColor:        AppColors.darkTextPrimary,
        elevation:              0,
        scrolledUnderElevation: 0,
        centerTitle:            false,
        surfaceTintColor:       Colors.transparent,
        titleTextStyle: TextStyle(
          color:         AppColors.darkTextPrimary,
          fontSize:      19,
          fontWeight:    FontWeight.w700,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: AppColors.darkTextPrimary),
        actionsIconTheme:
            IconThemeData(color: AppColors.darkTextPrimary),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:          Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness:     Brightness.dark,
        ),
      ),

      cardTheme: _cardTheme(
          AppColors.darkSurface, AppColors.darkDivider),

      elevatedButtonTheme:
          _elevatedBtn(AppColors.primaryLight),
      outlinedButtonTheme: _outlinedBtn(
          AppColors.primaryLight, AppColors.primaryLight),
      textButtonTheme: _textBtn(AppColors.primaryLight),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor:  AppColors.primaryDarkSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
                color: AppColors.primaryLight, size: 24);
          }
          return const IconThemeData(
              color: AppColors.darkTextSecondary, size: 22);
        }),
        labelTextStyle:
            WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize:   11,
              fontWeight: FontWeight.w700,
              color:      AppColors.primaryLight,
            );
          }
          return const TextStyle(
            fontSize:   11,
            fontWeight: FontWeight.w500,
            color:      AppColors.darkTextSecondary,
          );
        }),
        elevation:     3,
        shadowColor:   Colors.black.withOpacity(0.3),
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        height:        64,
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.darkSurface,
        selectedItemColor:    AppColors.primaryLight,
        unselectedItemColor:  AppColors.darkTextSecondary,
        selectedLabelStyle:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type:      BottomNavigationBarType.fixed,
        elevation: 12,
      ),

      chipTheme: _chipTheme(
          AppColors.primaryDarkSurface, AppColors.primaryLight),

      inputDecorationTheme: InputDecorationTheme(
        filled:    true,
        fillColor: AppColors.darkSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: AppColors.primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFF87171)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFF87171), width: 2),
        ),
        labelStyle:
            const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle:
            const TextStyle(color: AppColors.darkTextHint),
        prefixIconColor: AppColors.darkTextSecondary,
        suffixIconColor: AppColors.darkTextSecondary,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor:           AppColors.darkTextPrimary,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor:       AppColors.primaryLight,
        labelStyle:
            TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
      ),

      dividerTheme: const DividerThemeData(
        color:     AppColors.darkDivider,
        thickness: 1,
        space:     1,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding:
            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryLight
              : AppColors.darkTextSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primaryLight.withOpacity(0.4)
              : AppColors.darkSurfaceVariant,
        ),
      ),

      snackBarTheme: _snackBarTheme(),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        elevation:       8,
        shadowColor:     Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color:      AppColors.darkTextPrimary,
          fontSize:   19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color:  AppColors.darkTextSecondary,
          fontSize: 14,
          height:   1.5,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor:      AppColors.darkSurface,
        modalBackgroundColor: AppColors.darkSurface,
        elevation:            0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      iconTheme: const IconThemeData(
          color: AppColors.darkTextSecondary),

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation:       3,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.all(Radius.circular(14)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color:            AppColors.primaryLight,
        linearTrackColor: AppColors.primaryDarkSurface,
      ),
    );
  }
}