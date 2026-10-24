import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// A reusable card container with clay styling, used across multiple screens.
class SectionCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const SectionCard({
    super.key,
    required this.children,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dense = ClayLayout.isDesktopPlatform(context);
    final radius = ClayLayout.borderRadius(ClayLayout.radiusLg);
    final color = brightness == Brightness.dark
        ? ClayColors.surfaceCardDark
        : ClayColors.surfaceCardLight;

    // Material owns the fill color and hairline border so ListTile /
    // SwitchListTile ink paints on this ancestor (avoids "ink splashes may
    // be invisible" assert).
    return RepaintBoundary(
      child: Container(
        margin: margin ?? const EdgeInsets.only(bottom: ClayLayout.space12),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: brightness == Brightness.dark
                  ? ClayColors.outlineDark
                  : ClayColors.outlineLight,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding:
                padding ??
                EdgeInsets.symmetric(
                  horizontal: ClayLayout.space16,
                  vertical: dense ? ClayLayout.space12 : ClayLayout.space16,
                ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
