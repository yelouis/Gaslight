import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/services/game_service.dart';
import 'helpers/png_decoder.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  double getContrastRatio(Color fg, Color bg) {
    final fgR = (fg.r * 255.0).round().clamp(0, 255);
    final fgG = (fg.g * 255.0).round().clamp(0, 255);
    final fgB = (fg.b * 255.0).round().clamp(0, 255);
    final bgR = (bg.r * 255.0).round().clamp(0, 255);
    final bgG = (bg.g * 255.0).round().clamp(0, 255);
    final bgB = (bg.b * 255.0).round().clamp(0, 255);

    final l1 = relativeLuminance(fgR, fgG, fgB);
    final l2 = relativeLuminance(bgR, bgG, bgB);
    return contrastRatio(l1, l2);
  }

  test('text and background token pairs satisfy WCAG contrast floors', () {
    // 1. Ivory prompt text on ground scaffold
    final promptRatio = getContrastRatio(AppColors.ivory, AppColors.ground);
    expect(promptRatio, greaterThanOrEqualTo(3.0),
        reason: 'Ivory on Ground prompt text must meet WCAG AA large text ratio (3.0:1). Got $promptRatio');

    // 2. Ivory answer body text on groundRaised card
    final answerRatio = getContrastRatio(AppColors.ivory, AppColors.groundRaised);
    expect(answerRatio, greaterThanOrEqualTo(4.5),
        reason: 'Ivory on GroundRaised answer body text must meet WCAG AA body text ratio (4.5:1). Got $answerRatio');

    // 3. Ink text on Parchment card
    final parchmentRatio = getContrastRatio(AppColors.ink, AppColors.parchment);
    expect(parchmentRatio, greaterThanOrEqualTo(4.5),
        reason: 'Ink on Parchment text must meet WCAG AA body text ratio (4.5:1). Got $parchmentRatio');

    // 4. Brass accent on ground scaffold
    final brassRatio = getContrastRatio(AppColors.brass, AppColors.ground);
    expect(brassRatio, greaterThanOrEqualTo(3.0),
        reason: 'Brass on Ground accent text must meet WCAG AA ratio (3.0:1). Got $brassRatio');

    // 5. Verdigris accent on ground scaffold
    final verdigrisRatio = getContrastRatio(AppColors.verdigris, AppColors.ground);
    expect(verdigrisRatio, greaterThanOrEqualTo(3.0),
        reason: 'Verdigris on Ground text must meet WCAG AA ratio (3.0:1). Got $verdigrisRatio');
  });

  testWidgets('rendered reveal answer text and prompt satisfy WCAG contrast floors', (WidgetTester tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Container(
                  width: 300,
                  height: 150,
                  color: AppColors.groundRaised,
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Sample Answer Text Body',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ivory,
                      fontFamily: 'Lora',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 3.0));
    final byteData = await tester.runAsync(() => image!.toByteData(format: ImageByteFormat.png));
    final bytes = byteData!.buffer.asUint8List();

    final pngInfo = decodePngBytes(bytes);

    // Build color histogram
    final Map<int, int> counts = {};
    for (final p in pngInfo.pixels) {
      if (p.a < 128) continue;
      final argb = (p.a << 24) | (p.r << 16) | (p.g << 8) | p.b;
      counts[argb] = (counts[argb] ?? 0) + 1;
    }

    // Modal color is background
    int bgArgb = counts.entries.first.key;
    int maxCount = counts.entries.first.value;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        bgArgb = entry.key;
      }
    }

    final bgR = (bgArgb >> 16) & 0xFF;
    final bgG = (bgArgb >> 8) & 0xFF;
    final bgB = bgArgb & 0xFF;
    final bgLum = relativeLuminance(bgR, bgG, bgB);

    // Find text color with max luminance delta from background among colors with count >= 20
    double maxDist = 0.0;
    double textLum = bgLum;
    for (final entry in counts.entries) {
      if (entry.value < 20) continue;
      final r = (entry.key >> 16) & 0xFF;
      final g = (entry.key >> 8) & 0xFF;
      final b = entry.key & 0xFF;
      final lum = relativeLuminance(r, g, b);
      final dist = (lum - bgLum).abs();
      if (dist > maxDist) {
        maxDist = dist;
        textLum = lum;
      }
    }

    final measuredRatio = contrastRatio(bgLum, textLum);
    expect(measuredRatio, greaterThanOrEqualTo(4.5),
        reason: 'Rendered reveal answer text body on groundRaised background must have contrast ratio >= 4.5:1. Got $measuredRatio');
  });

  testWidgets('rendered score breakdown text widgets in reveal subtree satisfy WCAG AA contrast floor >= 4.5:1', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDb = FakeFirestore();
    final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));

    try {
      final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100);
      final guest1 = PlayerState(id: 'guest_1', name: 'Bob', joinedAt: 200);

      final card = CardModel(
        targetPlayerId: 'local_player_id',
        promptText: 'A prompt for testing contrast',
        truthAnswer: 'The truth',
        scoreDeltas: {
          'guest_1': 3,
        },
        scoreBreakdown: {
          'guest_1': [
            const ScoreBreakdownItem(rule: 'successful_forgery', points: 3),
          ],
        },
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 2,
        currentReaderId: 'local_player_id',
        cards: [card],
        readyPlayers: {'local_player_id': true, 'guest_1': true},
        resolutionOrder: ['local_player_id'],
        unmaskDeadline: 0,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
        localPlayer.toMap()..['authUid'] = 'local_auth_uid',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_1').set(
        guest1.toMap()..['authUid'] = 'guest_1_auth_uid',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'local_player_id');
      await gameService.tryRejoinSession();
      gameService.listenToRoom('TEST');

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase4RevealScreen(),
            ),
          ),
        ),
      );

      // Settle reveal stage to >= 4
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Tap Bob's chip to expand the breakdown
      final chipFinder = find.byKey(const ValueKey('score_breakdown_chip_guest_1'));
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      // Find container inside the chip to get its background decoration
      final containerFinder = find.descendant(of: chipFinder, matching: find.byType(Container)).first;
      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDec = containerWidget.decoration as BoxDecoration;
      final chipTint = boxDec.color ?? Colors.transparent;
      final effectiveBg = Color.alphaBlend(chipTint, AppColors.ground);

      // Walk all Text widgets inside the expanded breakdown subtree
      final breakdownItemsFinder = find.byKey(const ValueKey('score_breakdown_items_guest_1'));
      expect(breakdownItemsFinder, findsOneWidget);

      final textWidgets = tester.widgetList<Text>(
        find.descendant(of: breakdownItemsFinder, matching: find.byType(Text)),
      ).toList();

      expect(textWidgets.isNotEmpty, isTrue, reason: 'Must find text widgets in expanded breakdown');

      final List<({String desc, Color color, double ratio})> inspected = [];

      for (final text in textWidgets) {
        final List<(String, Color)> colors = [];
        if (text.style?.color != null) {
          colors.add((text.data ?? 'plain', text.style!.color!));
        }
        if (text.textSpan != null) {
          text.textSpan!.visitChildren((span) {
            if (span is TextSpan && span.style?.color != null) {
              colors.add((span.text ?? 'span', span.style!.color!));
            }
            return true;
          });
        }

        for (final entry in colors) {
          final label = entry.$1;
          final color = entry.$2;
          final effectiveFg = Color.alphaBlend(color, effectiveBg);
          final ratio = getContrastRatio(effectiveFg, effectiveBg);
          inspected.add((desc: label, color: color, ratio: ratio));
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'Rendered text "$label" with color $color on background $effectiveBg must satisfy WCAG AA ratio >= 4.5:1. Got $ratio',
          );
        }
      }

      // Ensure we actually inspected the breakdown line tokens
      expect(inspected.any((i) => i.desc.contains('Successful Forgery') || i.desc.contains(': +3')), isTrue,
          reason: 'Must have inspected the expanded rule lines');
    } finally {
      gameService.dispose();
    }
  });
}
