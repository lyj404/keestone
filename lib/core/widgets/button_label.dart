import 'package:material_ui/material_ui.dart';

/// A button label that never forces the button to grow or wrap.
///
/// Long localized strings used to either wrap onto multiple lines (filling the
/// whole button) or overflow. This renders the text on a single line and scales
/// it down to fit the available width, so buttons keep a consistent height on
/// both desktop and mobile regardless of how long the translation is.
///
/// Use inside full-width or [Expanded] buttons where the available width is
/// bounded. For intrinsic-width buttons (e.g. dialog actions) the width is
/// unbounded, so this simply behaves like a single-line [Text] with ellipsis.
class ButtonLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const ButtonLabel(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
    // When the width is bounded (full-width / Expanded buttons) FittedBox
    // shrinks the single line to fit instead of clipping; when it is unbounded
    // (intrinsic-width buttons) it is a no-op and the ellipsis above applies.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: label,
    );
  }
}
