import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/screens/game_over_screen.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  setUpAll(() async {
    final fontFile = File('assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf');
    if (fontFile.existsSync()) {
      final loader = FontLoader('CormorantGaramond');
      loader.addFont(fontFile.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
      await loader.load();
    }
  });

  Future<void> pumpCard(WidgetTester tester, {required double textScale, double width = 320}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 800),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: const HighlightCard(
                  title: 'BEST LIE OF THE NIGHT',
                  sigilType: ThematicIconType.secret,
                  quote: 'A clever falsehood told during the game',
                  subtext: 'By Alice for prompt "A mysterious secret"',
                  badgeText: 'Fooled 3 players',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoTruncation(WidgetTester tester, String text, double textScale) {
    final para = tester.renderObject<RenderParagraph>(find.text(text));
    expect(
      para.didExceedMaxLines,
      isFalse,
      reason: '"$text" exceeded max lines at textScale $textScale and 320pt width',
    );
  }

  testWidgets('AA14 (Issue 168): highlight card with BEST LIE OF THE NIGHT does not exceed max lines at 320pt width (textScale 1.0)', (tester) async {
    await pumpCard(tester, textScale: 1.0);
    expectNoTruncation(tester, 'BEST LIE OF THE NIGHT', 1.0);
  });

  testWidgets('AA14 (Issue 168): highlight card with BEST LIE OF THE NIGHT does not exceed max lines at 320pt width (textScale 2.0)', (tester) async {
    await pumpCard(tester, textScale: 2.0);
    expectNoTruncation(tester, 'BEST LIE OF THE NIGHT', 2.0);
  });
}
