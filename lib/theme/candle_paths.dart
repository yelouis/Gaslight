import 'package:flutter/material.dart';

class CandlePaths {
  static Path flamePath({
    required Offset wickTop,
    required double baseWidth,
    required double flameHeight,
    required double swayX,
  }) {
    final Path path = Path();
    final Offset flameTip = Offset(wickTop.dx + swayX, wickTop.dy - flameHeight);
    path.moveTo(wickTop.dx - baseWidth / 2, wickTop.dy);
    path.quadraticBezierTo(
      wickTop.dx - baseWidth / 2, wickTop.dy - flameHeight * 0.4,
      flameTip.dx, flameTip.dy,
    );
    path.quadraticBezierTo(
      wickTop.dx + baseWidth / 2, wickTop.dy - flameHeight * 0.4,
      wickTop.dx + baseWidth / 2, wickTop.dy,
    );
    path.close();
    return path;
  }
}
