import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'helpers/png_decoder.dart';

void main() {
  double getContrastRatio(Color fg, Color bg) {
    final l1 = relativeLuminance(fg.red, fg.green, fg.blue);
    final l2 = relativeLuminance(bg.red, bg.green, bg.blue);
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
}
