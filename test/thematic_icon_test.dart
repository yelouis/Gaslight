import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  testWidgets('routes functional glyphs to Phosphor and keeps sigils painted including depart', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Column(children: [
      ThematicIcon(type: ThematicIconType.writing, size: 20),
      ThematicIcon(type: ThematicIconType.flame,   size: 20),
      ThematicIcon(type: ThematicIconType.depart,  size: 20),
    ]))));

    final writing = find.byWidgetPredicate(
      (w) => w is ThematicIcon && w.type == ThematicIconType.writing);
    final flame = find.byWidgetPredicate(
      (w) => w is ThematicIcon && w.type == ThematicIconType.flame);
    final depart = find.byWidgetPredicate(
      (w) => w is ThematicIcon && w.type == ThematicIconType.depart);

    expect(find.descendant(of: writing, matching: find.byType(CustomPaint)), findsNothing);
    expect(find.descendant(of: writing, matching: find.byType(Icon)), findsOneWidget);

    // Guard against over-reach: sigils and depart must still be painted.
    expect(find.descendant(of: flame, matching: find.byType(CustomPaint)), findsOneWidget);
    expect(find.descendant(of: depart, matching: find.byType(CustomPaint)), findsOneWidget);

    final icon = tester.widget<Icon>(find.descendant(of: writing, matching: find.byType(Icon)));
    expect(icon.icon!.codePoint, 0xe9c0);
    expect(icon.icon!.fontFamily, 'PhosphorLight');
    expect(icon.icon!.fontPackage, isNull);
    expect(icon.size, 20.0);
  });

  testWidgets('ThematicIconType.depart renders non-zero ink pixels to bitmap', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: const ThematicIcon(type: ThematicIconType.depart, size: 64, color: Colors.white),
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Render boundary to image and inspect pixel bytes under real async engine thread
    ByteData? byteData;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    });
    expect(byteData, isNotNull);

    final bytes = byteData!.buffer.asUint8List();
    int nonZeroAlphaCount = 0;
    for (int i = 3; i < bytes.length; i += 4) {
      if (bytes[i] > 0) {
        nonZeroAlphaCount++;
      }
    }

    // Assert that the doorway & arrow line art renders at least 30 visible ink pixels
    expect(nonZeroAlphaCount, greaterThanOrEqualTo(30),
        reason: 'depart sigil must render visible line art pixels');
  });
}
