import 'package:flutter/material.dart';
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
}
