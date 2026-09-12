import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'theme_seed.dart';

/// Minimal Neutral layout tokens (spacing, radius, density).
///
/// Visual language (do not invent per-screen values):
/// - Radius: sm chips/tools · md icons · lg buttons/inputs/list · xl dialogs/cards
/// - Elevation: surfaces are flat; separation comes from 1px hairline borders
///   and surface-container steps. Shadows are reserved for floating overlays
///   (dialogs, menus, sheets) only.
/// - Motion: [motionFast]–[motionNormal]; respect MediaQuery.disableAnimations
class ClayLayout {
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;

  /// Chips, tool icons, dense controls.
  static const double radiusSm = 8;

  /// Icon containers, tree rows, small surfaces.
  static const double radiusMd = 10;

  /// Buttons, text fields, list tiles, section cards.
  static const double radiusLg = 12;

  /// Dialogs, sheets, hero / empty-state panels.
  static const double radiusXl = 16;

  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionNormal = Duration(milliseconds: 220);

  /// Wide / desktop explorer layout breakpoint.
  static const double wideBreakpoint = 700;

  /// Comfortable max width for single-column content on large screens.
  static const double contentMaxWidth = 1120;

  static const double sidebarWidth = 280;
  static const double touchMin = 48;
  static const double iconButton = 36;

  static BorderRadius borderRadius(double r) => BorderRadius.circular(r);

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static bool isDesktopPlatform(BuildContext context) {
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.linux ||
        p == TargetPlatform.macOS;
  }
}

/// Minimal Neutral color system for KeeStone.
///
/// Zinc gray scale + a single indigo accent (Linear-style):
/// - Surfaces step via zinc 50/100/200 (light) and 950/900/850/800 (dark).
/// - Separation is done with [outlineLight]/[outlineDark] hairline borders,
///   never shadows.
/// - Class name kept as `ClayColors` for call-site compatibility.
class ClayColors {
  // Primary palette – indigo
  static const primary = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF4338CA);
  static const primaryMuted = Color(0xFFA5B4FC);

  // Secondary – sky (informational accent)
  static const secondary = Color(0xFF0EA5E9);
  static const secondaryLight = Color(0xFF38BDF8);
  static const secondaryMuted = Color(0xFF7DD3FC);

  // Tertiary – amber warm accent (warnings)
  static const tertiary = Color(0xFFF59E0B);
  static const tertiaryLight = Color(0xFFFBBF24);

  // Surfaces (light) – zinc steps: bg < container < card
  static const surfaceLight = Color(0xFFFAFAFA);
  static const surfaceCardLight = Color(0xFFFFFFFF);
  static const surfaceContainerLight = Color(0xFFF4F4F5);

  // Dark surfaces – zinc steps (bg < container < card)
  static const surfaceDark = Color(0xFF09090B);
  static const surfaceCardDark = Color(0xFF18181B);
  static const surfaceContainerDark = Color(0xFF1F1F23);

  // Text (light mode)
  static const onSurfaceLight = Color(0xFF18181B);
  static const onSurfaceVariantLight = Color(0xFF71717A);
  static const outlineLight = Color(0xFFE4E4E7);

  // Text (dark mode) – hairline borders use zinc-700
  static const onSurfaceDark = Color(0xFFFAFAFA);
  static const onSurfaceVariantDark = Color(0xFFA1A1AA);
  static const outlineDark = Color(0xFF3F3F46);

  // Dark interactive fills (avoid light primary + white text)
  static const onPrimaryDark = Color(0xFF1E1B4B);
  static const primaryContainerDark = Color(0xFF312E81);
  static const onPrimaryContainerDark = Color(0xFFC7D2FE);
  static const secondaryContainerDark = Color(0xFF0C4A6E);
  static const onSecondaryContainerDark = Color(0xFFBAE6FD);

  // Error
  static const error = Color(0xFFDC2626);
  static const errorLight = Color(0xFFFEE2E2);
  static const errorDark = Color(0xFF991B1B);
  static const errorOnDark = Color(0xFFF87171);
  static const errorContainerDark = Color(0xFF7F1D1D);
  static const onErrorContainerDark = Color(0xFFFECACA);
}

/// Minimal Neutral decorations — prefer these over ad-hoc BoxDecoration.
class ClayDecoration {
  // Cached decorations to avoid per-build allocations.
  static final _cardCache = <(Brightness, double), BoxDecoration>{};
  static final _iconContainerCache = <(Brightness, double), BoxDecoration>{};

  /// Floating-overlay shadow (dialogs, menus, sheets only).
  /// Regular surfaces must not use shadows — use hairline borders instead.
  static List<BoxShadow> outerShadow(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.40),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }

  static const List<BoxShadow> _noShadow = [];

  /// Plain [DropdownButton] paints [ThemeData.focusColor] (~12% black) as a
  /// full-area InkWell overlay after the menu closes — that reads as a dirty
  /// shadow. Surfaces stay flat; outlined fields use focusedBorder instead.
  static const Color dropdownFocusColor = Colors.transparent;

  /// List rows are flat — separation comes from their own hairline border.
  static List<BoxShadow> listShadow(Brightness brightness) => _noShadow;

  /// Sidebar edge: a crisp 1px vertical hairline drawn as a zero-blur shadow,
  /// so existing call sites keep working without layout changes.
  static List<BoxShadow> sidebarShadow(Brightness brightness) {
    return [
      BoxShadow(
        color: brightness == Brightness.dark
            ? ClayColors.outlineDark
            : ClayColors.outlineLight,
        blurRadius: 0,
        offset: const Offset(1, 0),
      ),
    ];
  }

  /// Flat inputs — no inset shadow.
  static List<BoxShadow> innerShadow(Brightness brightness) => _noShadow;

  /// Section / panel card: flat fill + 1px hairline border.
  static BoxDecoration card({
    required Brightness brightness,
    Color? color,
    double radius = ClayLayout.radiusLg,
  }) {
    final isDark = brightness == Brightness.dark;
    final borderColor = isDark ? ClayColors.outlineDark : ClayColors.outlineLight;
    if (color != null) {
      return BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      );
    }
    final key = (brightness, radius);
    return _cardCache[key] ??= BoxDecoration(
      color: isDark
          ? ClayColors.surfaceCardDark
          : ClayColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
    );
  }

  /// Lightweight list-row surface (flat fill + hairline border).
  static BoxDecoration listItem({
    required Brightness brightness,
    required ColorScheme colorScheme,
    bool selected = false,
    double radius = ClayLayout.radiusLg,
  }) {
    final isDark = brightness == Brightness.dark;
    if (selected) {
      // Uniform border only — non-uniform Border + borderRadius is illegal.
      return BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: isDark ? 0.55 : 0.35),
        ),
      );
    }
    return BoxDecoration(
      color: isDark ? ClayColors.surfaceCardDark : ClayColors.surfaceCardLight,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? ClayColors.outlineDark : ClayColors.outlineLight,
      ),
    );
  }

  /// Flat input surface: container fill + hairline border (focus handled by
  /// InputDecorationTheme, this box is for custom-drawn fields).
  static BoxDecoration input({
    required Brightness brightness,
    required ColorScheme colorScheme,
    bool focused = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final focusColor = colorScheme.primary;
    return BoxDecoration(
      color: isDark
          ? ClayColors.surfaceContainerDark
          : ClayColors.surfaceContainerLight,
      borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
      border: focused
          ? Border.all(color: focusColor, width: 2)
          : Border.all(
              color: isDark ? ClayColors.outlineDark : ClayColors.outlineLight,
              width: 1,
            ),
    );
  }

  /// Neutral icon well (no shadow). Pass a [color] for tinted wells.
  static BoxDecoration iconContainer({
    required Brightness brightness,
    Color? color,
    double radius = ClayLayout.radiusMd,
  }) {
    if (color != null) {
      return BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      );
    }
    final key = (brightness, radius);
    return _iconContainerCache[key] ??= BoxDecoration(
      color: brightness == Brightness.dark
          ? ClayColors.surfaceContainerDark
          : ClayColors.surfaceContainerLight,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

class AppTheme {
  // Cache by (seed, resolved system font).
  static final _lightCache = <(ThemeSeed, String?), ThemeData>{};
  static final _darkCache = <(ThemeSeed, String?), ThemeData>{};

  /// Shared type scale — screens should prefer textTheme over ad-hoc sizes.
  static TextTheme _textTheme({
    required TextTheme base,
    required Color onSurface,
    required Color onSurfaceVariant,
    String? fontFamily,
  }) {
    // Fresh TextStyles so Material's baked-in "Roboto" does not override
    // ThemeData.fontFamily / platform system UI fonts.
    TextStyle style({
      required double size,
      required FontWeight weight,
      required Color color,
      double? letterSpacing,
    }) {
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );
    }

    return base.copyWith(
      headlineSmall: style(
        size: 24,
        weight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      titleLarge: style(
        size: 18,
        weight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      titleMedium: style(size: 15, weight: FontWeight.w600, color: onSurface),
      titleSmall: style(size: 14, weight: FontWeight.w600, color: onSurface),
      bodyLarge: style(size: 15, weight: FontWeight.w400, color: onSurface),
      bodyMedium: style(size: 14, weight: FontWeight.w400, color: onSurface),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      labelLarge: style(size: 14, weight: FontWeight.w600, color: onSurface),
      labelMedium: style(
        size: 12,
        weight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w500,
        color: onSurfaceVariant,
      ),
    );
  }

  /// System UI font for en/zh (no bundled fonts). Android/iOS/macOS use default.
  static String? resolveFontFamily(Locale? locale) {
    final isZh = locale?.languageCode == 'zh';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return isZh ? 'Microsoft YaHei UI' : 'Segoe UI Variable Display';
      case TargetPlatform.linux:
        return isZh ? 'Noto Sans CJK SC' : 'Noto Sans';
      default:
        return null;
    }
  }

  static ThemeData light({
    Locale? locale,
    ThemeSeed seed = ThemeSeed.indigo,
  }) {
    final fontFamily = resolveFontFamily(locale);
    return _lightCache[(seed, fontFamily)] ??= _buildLight(fontFamily, seed);
  }

  static ThemeData dark({
    Locale? locale,
    ThemeSeed seed = ThemeSeed.indigo,
  }) {
    final fontFamily = resolveFontFamily(locale);
    return _darkCache[(seed, fontFamily)] ??= _buildDark(fontFamily, seed);
  }

  static ThemeData _buildLight(String? fontFamily, ThemeSeed seed) {
    final palette = seed.colors;
    final textTheme = _textTheme(
      base: ThemeData.light().textTheme,
      onSurface: ClayColors.onSurfaceLight,
      onSurfaceVariant: ClayColors.onSurfaceVariantLight,
      fontFamily: fontFamily,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: palette.primary,
        onPrimary: Colors.white,
        primaryContainer: palette.primaryContainerLight,
        onPrimaryContainer: palette.onPrimaryContainerLight,
        secondary: ClayColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFE0F2FE),
        onSecondaryContainer: const Color(0xFF075985),
        tertiary: ClayColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFFEF3C7),
        onTertiaryContainer: const Color(0xFF92400E),
        error: ClayColors.error,
        onError: Colors.white,
        errorContainer: ClayColors.errorLight,
        onErrorContainer: ClayColors.errorDark,
        surface: ClayColors.surfaceLight,
        onSurface: ClayColors.onSurfaceLight,
        onSurfaceVariant: ClayColors.onSurfaceVariantLight,
        outline: ClayColors.outlineLight,
        outlineVariant: ClayColors.outlineLight,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: ClayColors.surfaceContainerLight,
        surfaceContainer: ClayColors.surfaceContainerLight,
        surfaceContainerHigh: const Color(0xFFE4E4E7),
        surfaceContainerHighest: const Color(0xFFD4D4D8),
      ),
      scaffoldBackgroundColor: ClayColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: ClayColors.surfaceLight,
        foregroundColor: ClayColors.onSurfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(color: ClayColors.outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(color: ClayColors.outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: const BorderSide(color: ClayColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: ClayColors.surfaceCardLight,
        labelStyle: TextStyle(
          color: ClayColors.onSurfaceVariantLight,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: ClayColors.onSurfaceVariantLight.withValues(alpha: 0.7),
          fontSize: 14,
        ),
        prefixIconColor: ClayColors.onSurfaceVariantLight,
        suffixIconColor: ClayColors.onSurfaceVariantLight,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          side: BorderSide(color: ClayColors.outlineLight),
        ),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ClayColors.outlineLight,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: textTheme.titleMedium?.copyWith(color: Colors.white),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.onSurfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: textTheme.titleMedium,
          side: const BorderSide(color: ClayColors.outlineLight),
          backgroundColor: ClayColors.surfaceCardLight,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        backgroundColor: ClayColors.onSurfaceLight,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
          side: BorderSide(color: ClayColors.outlineLight),
        ),
        backgroundColor: Colors.white,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ClayLayout.radiusXl),
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          side: BorderSide(color: ClayColors.outlineLight),
        ),
        elevation: 8,
        color: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: textTheme.titleMedium?.copyWith(
            color: palette.primary,
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: ClayColors.outlineLight),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primary,
        inactiveTrackColor: ClayColors.outlineLight,
        thumbColor: palette.primary,
        overlayColor: palette.primary.withValues(alpha: 0.1),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }

  static ThemeData _buildDark(String? fontFamily, ThemeSeed seed) {
    final palette = seed.colors;
    final textTheme = _textTheme(
      base: ThemeData.dark().textTheme,
      onSurface: ClayColors.onSurfaceDark,
      onSurfaceVariant: ClayColors.onSurfaceVariantDark,
      fontFamily: fontFamily,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        // Light primary for icons/accents; pair with dark onPrimary for filled controls.
        primary: palette.primaryLight,
        onPrimary: palette.onPrimaryDark,
        primaryContainer: palette.primaryContainerDark,
        onPrimaryContainer: palette.onPrimaryContainerDark,
        secondary: ClayColors.secondaryLight,
        onSecondary: const Color(0xFF082F49),
        secondaryContainer: ClayColors.secondaryContainerDark,
        onSecondaryContainer: ClayColors.onSecondaryContainerDark,
        tertiary: ClayColors.tertiaryLight,
        onTertiary: const Color(0xFF451A03),
        tertiaryContainer: const Color(0xFF78350F),
        onTertiaryContainer: const Color(0xFFFDE68A),
        error: ClayColors.errorOnDark,
        onError: const Color(0xFF450A0A),
        errorContainer: ClayColors.errorContainerDark,
        onErrorContainer: ClayColors.onErrorContainerDark,
        surface: ClayColors.surfaceDark,
        onSurface: ClayColors.onSurfaceDark,
        onSurfaceVariant: ClayColors.onSurfaceVariantDark,
        outline: ClayColors.outlineDark,
        outlineVariant: ClayColors.outlineDark,
        surfaceContainerLowest: const Color(0xFF0A0A0B),
        surfaceContainerLow: ClayColors.surfaceCardDark,
        surfaceContainer: ClayColors.surfaceContainerDark,
        surfaceContainerHigh: const Color(0xFF27272A),
        surfaceContainerHighest: const Color(0xFF303036),
      ),
      scaffoldBackgroundColor: ClayColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: ClayColors.surfaceDark,
        foregroundColor: ClayColors.onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: ClayColors.onSurfaceDark),
        actionsIconTheme: const IconThemeData(color: ClayColors.onSurfaceDark),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(
            color: ClayColors.outlineDark.withValues(alpha: 0.9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(
            color: ClayColors.outlineDark.withValues(alpha: 0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: BorderSide(
            color: palette.primaryLight,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          borderSide: const BorderSide(
            color: ClayColors.errorOnDark,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: ClayColors.surfaceContainerDark,
        labelStyle: TextStyle(
          color: ClayColors.onSurfaceVariantDark,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: ClayColors.onSurfaceVariantDark.withValues(alpha: 0.65),
          fontSize: 14,
        ),
        prefixIconColor: ClayColors.onSurfaceVariantDark,
        suffixIconColor: ClayColors.onSurfaceVariantDark,
      ),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          side: BorderSide(color: ClayColors.outlineDark),
        ),
        color: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        iconColor: ClayColors.onSurfaceVariantDark,
        textColor: ClayColors.onSurfaceDark,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ClayColors.outlineDark,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Light seed primary + near-black label stays compliant in dark mode.
          backgroundColor: palette.primaryLight,
          foregroundColor: palette.onPrimaryDark,
          disabledBackgroundColor: palette.primaryLight.withValues(
            alpha: 0.35,
          ),
          disabledForegroundColor: palette.onPrimaryDark.withValues(
            alpha: 0.55,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: textTheme.titleMedium?.copyWith(
            color: palette.onPrimaryDark,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClayColors.onSurfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: textTheme.titleMedium,
          side: BorderSide(color: ClayColors.outlineDark),
          backgroundColor: ClayColors.surfaceContainerDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          side: BorderSide(color: ClayColors.outlineDark),
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: ClayColors.onSurfaceDark,
        ),
        backgroundColor: const Color(0xFF27272A),
        actionTextColor: palette.primaryMuted,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primaryLight,
        foregroundColor: palette.onPrimaryDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusXl),
          side: BorderSide(color: ClayColors.outlineDark),
        ),
        backgroundColor: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ClayLayout.radiusXl),
          ),
        ),
        backgroundColor: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: ClayColors.outlineDark,
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClayLayout.radiusLg),
          side: BorderSide(color: ClayColors.outlineDark),
        ),
        elevation: 8,
        color: ClayColors.surfaceCardDark,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(
          color: ClayColors.onSurfaceDark,
          fontSize: 14,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primaryMuted,
          textStyle: textTheme.titleMedium?.copyWith(
            color: palette.primaryMuted,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: ClayColors.onSurfaceVariantDark),
      primaryIconTheme: IconThemeData(color: palette.primaryLight),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primaryLight;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(palette.onPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: ClayColors.outlineDark),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primaryLight,
        inactiveTrackColor: ClayColors.outlineDark,
        thumbColor: palette.primaryLight,
        overlayColor: palette.primaryLight.withValues(alpha: 0.12),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
    );
  }
}
