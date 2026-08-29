import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:gaslight/widgets/dealt_card_overlay.dart';

void main() {
  setUpAll(() async {
    final loraLoader = FontLoader('Lora');
    final loraFile = File('assets/fonts/lora/Lora-Regular.ttf');
    if (loraFile.existsSync()) {
      loraLoader.addFont(loraFile.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
    }
    final loraBoldFile = File('assets/fonts/lora/Lora-Bold.ttf');
    if (loraBoldFile.existsSync()) {
      loraLoader.addFont(loraBoldFile.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
    }
    await loraLoader.load();

    final cormorantLoader = FontLoader('CormorantGaramond');
    final cormorantFile = File('assets/fonts/cormorant_garamond/CormorantGaramond-Regular.ttf');
    if (cormorantFile.existsSync()) {
      cormorantLoader.addFont(cormorantFile.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
    }
    final cormorantBoldFile = File('assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf');
    if (cormorantBoldFile.existsSync()) {
      cormorantLoader.addFont(cormorantBoldFile.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
    }
    await cormorantLoader.load();
  });

  Widget buildOverlayHarness({
    required String promptText,
    required Size screenSize,
    VoidCallback? onDismiss,
    GamePhase phase = GamePhase.forgery,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: screenSize,
          accessibleNavigation: true, // reduce motion for predictable sizing
        ),
        child: Scaffold(
          body: Stack(
            children: [
              DealtCardOverlay(
                phase: phase,
                readerName: 'Alice',
                promptText: promptText,
                onDismiss: onDismiss ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  group('Issue 137: Dealt-Card Overlay Growth (R2)', () {
    testWidgets('Falsifying test: Longest prompt does not use FittedBox scale-down and expands naturally', (tester) async {
      // Dynamically fetch the longest prompt across all prompt decks
      final allPrompts = PromptDecks.allDecks.expand((d) => d.prompts).toList();
      allPrompts.sort((a, b) => b.length.compareTo(a.length));
      final longestPrompt = allPrompts.first;

      const surfaceSize = Size(375, 812);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildOverlayHarness(
        promptText: longestPrompt,
        screenSize: surfaceSize,
      ));
      await tester.pump(const Duration(milliseconds: 1000));

      // Guard: No FittedBox scale-down wrapping the card content
      final fittedBoxes = find.descendant(
        of: find.byType(DealtCardOverlay),
        matching: find.byType(FittedBox),
      );
      expect(
        fittedBoxes,
        findsNothing,
        reason: 'DealtCardOverlay must not use FittedBox scale-down to compress long prompt cards',
      );

      // Verify the prompt text is present and readable
      final promptFinder = find.text(longestPrompt);
      expect(promptFinder, findsOneWidget);
    });

    testWidgets('Short vs Long comparison: Short prompt renders more compactly than long prompt', (tester) async {
      final allPrompts = PromptDecks.allDecks.expand((d) => d.prompts).toList();
      allPrompts.sort((a, b) => a.length.compareTo(b.length));
      final shortestPrompt = allPrompts.first;
      allPrompts.sort((a, b) => b.length.compareTo(a.length));
      final longestPrompt = allPrompts.first;

      const surfaceSize = Size(375, 812);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Measure short prompt card
      await tester.pumpWidget(buildOverlayHarness(
        promptText: shortestPrompt,
        screenSize: surfaceSize,
      ));
      await tester.pump(const Duration(milliseconds: 1000));

      // Find the card container (the decorated Container inside DealtCardOverlay)
      final cardFinder = find.descendant(
        of: find.byType(DealtCardOverlay),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color != null),
      );
      final shortCardBox = tester.renderObject<RenderBox>(cardFinder.first);
      final shortCardHeight = shortCardBox.size.height;

      // Measure long prompt card
      await tester.pumpWidget(buildOverlayHarness(
        promptText: longestPrompt,
        screenSize: surfaceSize,
      ));
      await tester.pump(const Duration(milliseconds: 1000));

      final longCardBox = tester.renderObject<RenderBox>(cardFinder.first);
      final longCardHeight = longCardBox.size.height;

      expect(
        shortCardHeight,
        lessThan(longCardHeight),
        reason: 'Short prompt card ($shortCardHeight pt) must be shorter than long prompt card ($longCardHeight pt)',
      );
    });

    testWidgets('Viewport boundary guard: Small screen (320x568) caps card height at 70% of screen height', (tester) async {
      final allPrompts = PromptDecks.allDecks.expand((d) => d.prompts).toList();
      allPrompts.sort((a, b) => b.length.compareTo(a.length));
      final longestPrompt = allPrompts.first;

      const smallSurface = Size(320, 568);
      await tester.binding.setSurfaceSize(smallSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildOverlayHarness(
        promptText: longestPrompt,
        screenSize: smallSurface,
      ));
      await tester.pump(const Duration(milliseconds: 1000));

      final cardFinder = find.descendant(
        of: find.byType(DealtCardOverlay),
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color != null),
      );
      final cardBox = tester.renderObject<RenderBox>(cardFinder.first);
      final cardHeight = cardBox.size.height;

      final double maxAllowedHeight = 568.0 * 0.7; // 397.6
      expect(
        cardHeight,
        lessThanOrEqualTo(maxAllowedHeight + 0.1),
        reason: 'Card height ($cardHeight pt) must not exceed 70% screen height ($maxAllowedHeight pt)',
      );
    });

    testWidgets('Dismiss button triggers onDismiss callback', (tester) async {
      bool dismissed = false;
      const surfaceSize = Size(375, 812);
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildOverlayHarness(
        promptText: 'Test prompt',
        screenSize: surfaceSize,
        onDismiss: () => dismissed = true,
      ));
      await tester.pump(const Duration(milliseconds: 1000));

      final buttonFinder = find.widgetWithText(ElevatedButton, 'INSPECT');
      expect(buttonFinder, findsOneWidget);
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 500));

      expect(dismissed, isTrue);
    });
  });
}
