import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  testWidgets('routes functional glyphs to Phosphor and keeps sigils painted', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      ThematicIcon(type: ThematicIconType.writing, size: 20),
      ThematicIcon(type: ThematicIconType.flame,   size: 20),
    ]))));

    final writing = find.byWidgetPredicate(
      (w) => w is ThematicIcon && w.type == ThematicIconType.writing);
    final flame = find.byWidgetPredicate(
      (w) => w is ThematicIcon && w.type == ThematicIconType.flame);

    expect(find.descendant(of: writing, matching: find.byType(CustomPaint)), findsNothing);
    expect(find.descendant(of: writing, matching: find.byType(Icon)), findsOneWidget);

    // Guard against over-reach: sigils must still be painted.
    expect(find.descendant(of: flame, matching: find.byType(CustomPaint)), findsOneWidget);

    final icon = tester.widget<Icon>(find.descendant(of: writing, matching: find.byType(Icon)));
    expect(icon.icon!.codePoint, 0xe9c0);
    expect(icon.icon!.fontFamily, 'PhosphorLight');
    expect(icon.icon!.fontPackage, isNull);
    expect(icon.size, 20.0);
  });
}
