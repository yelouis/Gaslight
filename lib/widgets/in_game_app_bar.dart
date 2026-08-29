import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Computes the dynamic height for in-game AppBars across Craft, Vote, and Reveal screens.
///
/// Lays out each line of text using a [TextPainter] with the live [MediaQuery.textScaler]
/// and actual [TextStyle] against available title area width (accounting for leading
/// and trailing button bounds). Adds existing inter-line spacing and symmetric breathing padding.
/// Guarantees the height is at least Material's [kToolbarHeight].
double inGameAppBarHeight(
  BuildContext context, {
  required List<TextSpan> lines,
}) {
  final mediaQuery = MediaQuery.of(context);
  final screenWidth = mediaQuery.size.width;
  final textScaler = mediaQuery.textScaler;

  // Title area available width: screen width minus leading IconButton (56pt) and right action/reserve (56pt)
  final availableWidth = math.max(0.0, screenWidth - 112.0);

  final theme = Theme.of(context);
  final defaultStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge ?? DefaultTextStyle.of(context).style;
  double textTotalHeight = 0.0;
  for (final line in lines) {
    final effectiveStyle = defaultStyle.merge(line.style);
    final painter = TextPainter(
      text: TextSpan(text: line.text, children: line.children, style: effectiveStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    );
    painter.layout(maxWidth: availableWidth);
    textTotalHeight += painter.height;
  }

  // Inter-line spacing: 2pt per gap between lines
  final double spacing = lines.length > 1 ? (lines.length - 1) * 2.0 : 0.0;

  // Symmetric breathing allowance: 8pt total (4pt above, 4pt below)
  const double breathingPadding = 8.0;

  final double computedHeight = textTotalHeight + spacing + breathingPadding;

  return math.max(kToolbarHeight, computedHeight);
}
