import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keestone/core/widgets/button_label.dart';

void main() {
  // A single very long label that previously filled or overflowed buttons.
  const longLabel =
      'This is an extremely long button label that would otherwise wrap or overflow';

  Future<Size> renderInWidth(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: FilledButton(
                onPressed: () {},
                child: const ButtonLabel(longLabel),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.byType(FilledButton));
  }

  testWidgets('keeps the label on a single line (no wrapping)', (tester) async {
    await renderInWidth(tester, 200);
    final text = tester.widget<Text>(find.text(longLabel));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.softWrap, isFalse);
  });

  testWidgets('a narrow button does not grow taller than a wide one', (
    tester,
  ) async {
    final narrow = await renderInWidth(tester, 160);
    final wide = await renderInWidth(tester, 360);
    // Wrapping used to make the narrow button much taller. With a single-line
    // label scaled to fit, both buttons keep the same (default) height.
    expect(narrow.height, wide.height);
  });

  testWidgets('does not overflow its bounded width', (tester) async {
    await renderInWidth(tester, 140);
    expect(tester.takeException(), isNull);
  });
}
