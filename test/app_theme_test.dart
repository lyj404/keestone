import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/theme/app_theme.dart';
import 'package:keestone/core/theme/theme_seed.dart';

void main() {
  group('AppTheme.resolveFontFamily', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('Windows zh uses Microsoft YaHei UI', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.resolveFontFamily(const Locale('zh')),
        'Microsoft YaHei UI',
      );
    });

    test('Windows en uses Segoe UI Variable Display', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.resolveFontFamily(const Locale('en')),
        'Segoe UI Variable Display',
      );
    });

    test('Linux zh uses Noto Sans CJK SC', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(
        AppTheme.resolveFontFamily(const Locale('zh')),
        'Noto Sans CJK SC',
      );
    });

    test('Linux en uses Noto Sans', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(AppTheme.resolveFontFamily(const Locale('en')), 'Noto Sans');
    });

    test('Android does not force a font family', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppTheme.resolveFontFamily(const Locale('zh')), isNull);
      expect(AppTheme.resolveFontFamily(const Locale('en')), isNull);
    });
  });

  group('AppTheme typography', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('shared type scale is consistent', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.light(locale: const Locale('en'));
      final tt = theme.textTheme;

      expect(tt.titleMedium?.fontSize, 15);
      expect(tt.titleMedium?.fontWeight, FontWeight.w600);
      expect(tt.bodyMedium?.fontSize, 14);
      expect(tt.bodySmall?.fontSize, 12);
      expect(tt.labelSmall?.fontSize, 11);
    });

    test('light theme snackbar keeps readable white body text', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final style = AppTheme.light(
        locale: const Locale('en'),
      ).snackBarTheme.contentTextStyle;

      expect(style, isNotNull);
      expect(style!.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, Colors.white);
    });

    test('dark theme uses high-contrast text on elevated surface', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.dark(locale: const Locale('en'));
      final style = theme.snackBarTheme.contentTextStyle;

      expect(style, isNotNull);
      expect(style!.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, ClayColors.onSurfaceDark);
      expect(theme.snackBarTheme.backgroundColor, isNot(ClayColors.surfaceDark));
    });

    test('dark theme has solid containers and readable onPrimary', () {
      final scheme = AppTheme.dark(locale: const Locale('en')).colorScheme;
      expect(scheme.primaryContainer.a, greaterThan(0.99));
      expect(scheme.onSurface, ClayColors.onSurfaceDark);
      expect(scheme.onSurfaceVariant, ClayColors.onSurfaceVariantDark);
      expect(
        scheme.onPrimary,
        ThemeSeed.indigo.colors.onPrimaryDark,
      );
    });

    test('text styles inherit platform + locale font', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(
        AppTheme.light(locale: const Locale('zh')).textTheme.bodyMedium?.fontFamily,
        'Microsoft YaHei UI',
      );
      expect(
        AppTheme.light(locale: const Locale('en')).textTheme.bodyMedium?.fontFamily,
        'Segoe UI Variable Display',
      );
      expect(
        AppTheme.light(locale: const Locale('zh')).textTheme.titleMedium?.fontFamily,
        'Microsoft YaHei UI',
      );
    });

    test('list tiles share titleMedium / bodySmall', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final theme = AppTheme.light(locale: const Locale('en'));
      expect(theme.listTileTheme.titleTextStyle?.fontSize, 15);
      expect(theme.listTileTheme.titleTextStyle?.fontWeight, FontWeight.w600);
      expect(theme.listTileTheme.subtitleTextStyle?.fontSize, 12);
    });
  });

  group('AppTheme seeds', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('default seed is indigo', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final scheme = AppTheme.light(locale: const Locale('en')).colorScheme;
      expect(scheme.primary, ThemeSeed.indigo.colors.primary);
    });

    test('seed changes light and dark primary', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final light = AppTheme.light(
        locale: const Locale('en'),
        seed: ThemeSeed.emerald,
      ).colorScheme;
      final dark = AppTheme.dark(
        locale: const Locale('en'),
        seed: ThemeSeed.emerald,
      ).colorScheme;

      expect(light.primary, ThemeSeed.emerald.colors.primary);
      expect(light.primaryContainer, ThemeSeed.emerald.colors.primaryContainerLight);
      expect(dark.primary, ThemeSeed.emerald.colors.primaryLight);
      expect(dark.primaryContainer, ThemeSeed.emerald.colors.primaryContainerDark);
      expect(dark.onPrimary, ThemeSeed.emerald.colors.onPrimaryDark);
    });

    test('neutrals stay constant across seeds', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final indigo = AppTheme.light(
        locale: const Locale('en'),
        seed: ThemeSeed.indigo,
      );
      final rose = AppTheme.light(
        locale: const Locale('en'),
        seed: ThemeSeed.rose,
      );

      expect(indigo.scaffoldBackgroundColor, rose.scaffoldBackgroundColor);
      expect(indigo.colorScheme.surface, rose.colorScheme.surface);
      expect(indigo.colorScheme.onSurface, rose.colorScheme.onSurface);
      expect(indigo.colorScheme.outline, rose.colorScheme.outline);
    });

    test('ThemeSeed.fromId falls back to indigo', () {
      expect(ThemeSeed.fromId(null), ThemeSeed.indigo);
      expect(ThemeSeed.fromId('nope'), ThemeSeed.indigo);
      expect(ThemeSeed.fromId('sky'), ThemeSeed.sky);
    });
  });
}
