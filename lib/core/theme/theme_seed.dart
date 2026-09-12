import 'package:material_ui/material_ui.dart';

/// Accent family for a theme seed. Neutrals (surfaces, outline, text) and
/// semantic secondary/tertiary/error stay global — only the primary brand
/// color shifts when the user picks a seed.
class ThemeSeedColors {
  const ThemeSeedColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryMuted,
    required this.primaryContainerLight,
    required this.onPrimaryContainerLight,
    required this.primaryContainerDark,
    required this.onPrimaryContainerDark,
    required this.onPrimaryDark,
  });

  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryMuted;
  final Color primaryContainerLight;
  final Color onPrimaryContainerLight;
  final Color primaryContainerDark;
  final Color onPrimaryContainerDark;

  /// Label color for filled controls on [primaryLight] in dark mode.
  final Color onPrimaryDark;
}

enum ThemeSeed {
  indigo,
  emerald,
  sky,
  amber,
  slate,
  rose;

  ThemeSeedColors get colors {
    switch (this) {
      case ThemeSeed.indigo:
        return const ThemeSeedColors(
          primary: Color(0xFF4F46E5),
          primaryLight: Color(0xFF818CF8),
          primaryDark: Color(0xFF4338CA),
          primaryMuted: Color(0xFFA5B4FC),
          primaryContainerLight: Color(0xFFE0E7FF),
          onPrimaryContainerLight: Color(0xFF3730A3),
          primaryContainerDark: Color(0xFF312E81),
          onPrimaryContainerDark: Color(0xFFC7D2FE),
          onPrimaryDark: Color(0xFF1E1B4B),
        );
      case ThemeSeed.emerald:
        return const ThemeSeedColors(
          primary: Color(0xFF059669),
          primaryLight: Color(0xFF34D399),
          primaryDark: Color(0xFF047857),
          primaryMuted: Color(0xFF6EE7B7),
          primaryContainerLight: Color(0xFFD1FAE5),
          onPrimaryContainerLight: Color(0xFF064E3B),
          primaryContainerDark: Color(0xFF064E3B),
          onPrimaryContainerDark: Color(0xFFA7F3D0),
          onPrimaryDark: Color(0xFF022C22),
        );
      case ThemeSeed.sky:
        return const ThemeSeedColors(
          primary: Color(0xFF0284C7),
          primaryLight: Color(0xFF38BDF8),
          primaryDark: Color(0xFF0369A1),
          primaryMuted: Color(0xFF7DD3FC),
          primaryContainerLight: Color(0xFFE0F2FE),
          onPrimaryContainerLight: Color(0xFF075985),
          primaryContainerDark: Color(0xFF0C4A6E),
          onPrimaryContainerDark: Color(0xFFBAE6FD),
          onPrimaryDark: Color(0xFF082F49),
        );
      case ThemeSeed.amber:
        return const ThemeSeedColors(
          primary: Color(0xFFD97706),
          primaryLight: Color(0xFFFBBF24),
          primaryDark: Color(0xFFB45309),
          primaryMuted: Color(0xFFFCD34D),
          primaryContainerLight: Color(0xFFFEF3C7),
          onPrimaryContainerLight: Color(0xFF78350F),
          primaryContainerDark: Color(0xFF78350F),
          onPrimaryContainerDark: Color(0xFFFDE68A),
          onPrimaryDark: Color(0xFF451A03),
        );
      case ThemeSeed.slate:
        return const ThemeSeedColors(
          primary: Color(0xFF475569),
          primaryLight: Color(0xFF94A3B8),
          primaryDark: Color(0xFF334155),
          primaryMuted: Color(0xFFCBD5E1),
          primaryContainerLight: Color(0xFFE2E8F0),
          onPrimaryContainerLight: Color(0xFF0F172A),
          primaryContainerDark: Color(0xFF1E293B),
          onPrimaryContainerDark: Color(0xFFCBD5E1),
          onPrimaryDark: Color(0xFF0F172A),
        );
      case ThemeSeed.rose:
        return const ThemeSeedColors(
          primary: Color(0xFFE11D48),
          primaryLight: Color(0xFFFB7185),
          primaryDark: Color(0xFFBE123C),
          primaryMuted: Color(0xFFFDA4AF),
          primaryContainerLight: Color(0xFFFFE4E6),
          onPrimaryContainerLight: Color(0xFF881337),
          primaryContainerDark: Color(0xFF881337),
          onPrimaryContainerDark: Color(0xFFFECDD3),
          onPrimaryDark: Color(0xFF4C0519),
        );
    }
  }

  static ThemeSeed fromId(String? id) {
    for (final seed in ThemeSeed.values) {
      if (seed.name == id) return seed;
    }
    return ThemeSeed.indigo;
  }
}
