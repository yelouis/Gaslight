import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:async';
import 'app_colors.dart';
import 'app_motion.dart';

enum ThematicIconType {
  // Avatar Sigils
  flame,
  moth,
  key,
  raven,
  moon,
  hourglass,
  
  // Game Actions & States
  observe,
  timer,
  writing,
  confirm,
  secret,
  host,
  sound,
  mute,

  // New Types
  ledger,
  envelope,
  redraw,
}

class ThematicIcon extends StatelessWidget {
  final ThematicIconType type;
  final double size;
  final Color color;

  const ThematicIcon({
    super.key,
    required this.type,
    this.size = 24.0,
    this.color = const Color(0xFFC5A059), // Antique Brass / Gold
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ThematicIconPainter(type, color),
      ),
    );
  }
}

class _ThematicIconPainter extends CustomPainter {
  final ThematicIconType type;
  final Color color;

  _ThematicIconPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width / 16)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    switch (type) {
      case ThematicIconType.flame:
        final path = Path();
        path.moveTo(w * 0.5, h * 0.1);
        path.quadraticBezierTo(w * 0.2, h * 0.45, w * 0.25, h * 0.7);
        path.quadraticBezierTo(w * 0.3, h * 0.9, w * 0.5, h * 0.9);
        path.quadraticBezierTo(w * 0.7, h * 0.9, w * 0.75, h * 0.7);
        path.quadraticBezierTo(w * 0.8, h * 0.4, w * 0.5, h * 0.1);
        
        // Inner detail flame
        final innerPath = Path();
        innerPath.moveTo(w * 0.5, h * 0.4);
        innerPath.quadraticBezierTo(w * 0.35, h * 0.6, w * 0.38, h * 0.75);
        innerPath.quadraticBezierTo(w * 0.5, h * 0.85, w * 0.5, h * 0.85);
        innerPath.quadraticBezierTo(w * 0.5, h * 0.85, w * 0.62, h * 0.75);
        innerPath.quadraticBezierTo(w * 0.65, h * 0.6, w * 0.5, h * 0.4);

        canvas.drawPath(path, paint);
        canvas.drawPath(innerPath, paint);
        break;

      case ThematicIconType.moth:
        // Body
        final bodyPath = Path()
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.45, h * 0.5, w * 0.5, h * 0.75)
          ..quadraticBezierTo(w * 0.55, h * 0.5, w * 0.5, h * 0.25);
        canvas.drawPath(bodyPath, fillPaint);

        // Antennae
        final antennaePath = Path()
          ..moveTo(w * 0.47, h * 0.2)
          ..quadraticBezierTo(w * 0.4, h * 0.12, w * 0.35, h * 0.14)
          ..moveTo(w * 0.53, h * 0.2)
          ..quadraticBezierTo(w * 0.6, h * 0.12, w * 0.65, h * 0.14);
        canvas.drawPath(antennaePath, paint);

        // Wings
        final leftWing = Path()
          ..moveTo(w * 0.49, h * 0.35)
          ..cubicTo(w * 0.2, h * 0.15, w * 0.1, h * 0.35, w * 0.15, h * 0.55)
          ..quadraticBezierTo(w * 0.3, h * 0.65, w * 0.49, h * 0.5);
        canvas.drawPath(leftWing, paint);

        final rightWing = Path()
          ..moveTo(w * 0.51, h * 0.35)
          ..cubicTo(w * 0.8, h * 0.15, w * 0.9, h * 0.35, w * 0.85, h * 0.55)
          ..quadraticBezierTo(w * 0.7, h * 0.65, w * 0.51, h * 0.5);
        canvas.drawPath(rightWing, paint);

        // Inner Wing detail lines
        canvas.drawLine(Offset(w * 0.4, h * 0.4), Offset(w * 0.25, h * 0.45), paint);
        canvas.drawLine(Offset(w * 0.6, h * 0.4), Offset(w * 0.75, h * 0.45), paint);
        break;

      case ThematicIconType.key:
      case ThematicIconType.secret:
        // Key Head (Oval/Fancy loop)
        canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.18, paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.08, paint);
        
        // Shaft
        canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.5, h * 0.85), paint);
        
        // Bit / Teeth
        final bitPath = Path()
          ..moveTo(w * 0.5, h * 0.68)
          ..lineTo(w * 0.7, h * 0.68)
          ..lineTo(w * 0.7, h * 0.75)
          ..lineTo(w * 0.58, h * 0.75)
          ..lineTo(w * 0.58, h * 0.79)
          ..lineTo(w * 0.7, h * 0.79)
          ..lineTo(w * 0.7, h * 0.85)
          ..lineTo(w * 0.5, h * 0.85);
        canvas.drawPath(bitPath, paint);
        break;

      case ThematicIconType.raven:
        // Stylized silhouette of a sitting raven / bird
        final path = Path()
          ..moveTo(w * 0.35, h * 0.25) // Beak tip (pointing left)
          ..lineTo(w * 0.48, h * 0.28)
          ..quadraticBezierTo(w * 0.55, h * 0.18, w * 0.62, h * 0.25) // Head top
          ..quadraticBezierTo(w * 0.75, h * 0.45, w * 0.7, h * 0.7)   // Back
          ..quadraticBezierTo(w * 0.6, h * 0.85, w * 0.45, h * 0.8)  // Tail/body base
          ..quadraticBezierTo(w * 0.4, h * 0.55, w * 0.48, h * 0.4)   // Chest
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.25));

        // Eye dot
        canvas.drawCircle(Offset(w * 0.56, h * 0.32), w * 0.04, fillPaint..color = color);
        break;

      case ThematicIconType.moon:
        // Crescent Moon
        final path = Path()
          ..moveTo(w * 0.35, h * 0.2)
          ..cubicTo(w * 0.7, h * 0.2, w * 0.7, h * 0.8, w * 0.35, h * 0.8)
          ..cubicTo(w * 0.55, h * 0.7, w * 0.55, h * 0.3, w * 0.35, h * 0.2)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.2));
        break;

      case ThematicIconType.hourglass:
      case ThematicIconType.timer:
        // Top and bottom plates
        canvas.drawLine(Offset(w * 0.25, h * 0.15), Offset(w * 0.75, h * 0.15), paint);
        canvas.drawLine(Offset(w * 0.25, h * 0.85), Offset(w * 0.75, h * 0.85), paint);
        
        // Pillars / frame
        canvas.drawLine(Offset(w * 0.28, h * 0.15), Offset(w * 0.28, h * 0.85), paint);
        canvas.drawLine(Offset(w * 0.72, h * 0.15), Offset(w * 0.72, h * 0.85), paint);

        // Glass bulbs
        final glassPath = Path()
          ..moveTo(w * 0.32, h * 0.2)
          ..cubicTo(w * 0.35, h * 0.45, w * 0.46, h * 0.48, w * 0.46, h * 0.5)
          ..cubicTo(w * 0.46, h * 0.52, w * 0.35, h * 0.55, w * 0.32, h * 0.8)
          ..moveTo(w * 0.68, h * 0.2)
          ..cubicTo(w * 0.65, h * 0.45, w * 0.54, h * 0.48, w * 0.54, h * 0.5)
          ..cubicTo(w * 0.54, h * 0.52, w * 0.65, h * 0.55, w * 0.68, h * 0.8);
        canvas.drawPath(glassPath, paint);

        // Sand pile top
        final sandTop = Path()
          ..moveTo(w * 0.4, h * 0.35)
          ..quadraticBezierTo(w * 0.5, h * 0.38, w * 0.6, h * 0.35)
          ..lineTo(w * 0.52, h * 0.49)
          ..lineTo(w * 0.48, h * 0.49)
          ..close();
        canvas.drawPath(sandTop, fillPaint..color = color.withOpacity(0.5));

        // Sand pile bottom
        final sandBottom = Path()
          ..moveTo(w * 0.48, h * 0.5)
          ..lineTo(w * 0.52, h * 0.5)
          ..lineTo(w * 0.65, h * 0.8)
          ..lineTo(w * 0.35, h * 0.8)
          ..close();
        canvas.drawPath(sandBottom, fillPaint..color = color);
        break;

      case ThematicIconType.observe:
        // Monocle / magnifying glass
        canvas.drawCircle(Offset(w * 0.42, h * 0.42), w * 0.24, paint);
        
        // Handle
        canvas.drawLine(Offset(w * 0.59, h * 0.59), Offset(w * 0.85, h * 0.85), paint);
        
        // Glass sheen line
        final sheenPath = Path()
          ..moveTo(w * 0.3, h * 0.3)
          ..quadraticBezierTo(w * 0.38, h * 0.22, w * 0.48, h * 0.28);
        canvas.drawPath(sheenPath, paint);
        break;

      case ThematicIconType.writing:
        // Stylized feather quill
        final quillPath = Path()
          ..moveTo(w * 0.8, h * 0.15)
          ..cubicTo(w * 0.6, h * 0.1, w * 0.35, h * 0.35, w * 0.2, h * 0.7)
          ..lineTo(w * 0.15, h * 0.85) // nib point
          ..lineTo(w * 0.3, h * 0.8)
          ..cubicTo(w * 0.55, h * 0.65, w * 0.8, h * 0.4, w * 0.8, h * 0.15);
        canvas.drawPath(quillPath, paint);
        canvas.drawPath(quillPath, fillPaint..color = color.withOpacity(0.15));

        // Shaft center line
        canvas.drawLine(Offset(w * 0.8, h * 0.15), Offset(w * 0.2, h * 0.75), paint);
        
        // Splits/ribs on feather
        canvas.drawLine(Offset(w * 0.5, h * 0.4), Offset(w * 0.42, h * 0.32), paint);
        canvas.drawLine(Offset(w * 0.6, h * 0.3), Offset(w * 0.52, h * 0.22), paint);
        canvas.drawLine(Offset(w * 0.4, h * 0.5), Offset(w * 0.32, h * 0.42), paint);
        break;

      case ThematicIconType.confirm:
        // Wax seal outline
        final path = Path();
        final points = 12;
        final innerRadius = w * 0.36;
        final outerRadius = w * 0.45;
        for (int i = 0; i < points * 2; i++) {
          final angle = i * math.pi / points;
          final r = (i % 2 == 0) ? outerRadius : innerRadius;
          final x = center.dx + r * math.cos(angle);
          final y = center.dy + r * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.3));

        // Monogram / Inner stamp detail (wax seal stamp impression)
        canvas.drawCircle(center, w * 0.22, paint);
        
        // Initial letter/sigil stamp look
        final monogramPath = Path()
          ..moveTo(w * 0.45, h * 0.42)
          ..lineTo(w * 0.55, h * 0.42)
          ..moveTo(w * 0.5, h * 0.42)
          ..lineTo(w * 0.5, h * 0.58)
          ..moveTo(w * 0.45, h * 0.58)
          ..lineTo(w * 0.55, h * 0.58);
        canvas.drawPath(monogramPath, paint);
        break;

      case ThematicIconType.host:
        // Gas Lamp / Lantern
        final base = Path()
          ..moveTo(w * 0.3, h * 0.8)
          ..lineTo(w * 0.7, h * 0.8)
          ..lineTo(w * 0.65, h * 0.87)
          ..lineTo(w * 0.35, h * 0.87)
          ..close();
        canvas.drawPath(base, fillPaint);

        // Glass frame
        final glass = Path()
          ..moveTo(w * 0.3, h * 0.8)
          ..lineTo(w * 0.35, h * 0.4)
          ..lineTo(w * 0.65, h * 0.4)
          ..lineTo(w * 0.7, h * 0.8)
          ..close();
        canvas.drawPath(glass, paint);

        // Top dome
        final dome = Path()
          ..moveTo(w * 0.35, h * 0.4)
          ..quadraticBezierTo(w * 0.5, h * 0.15, w * 0.65, h * 0.4)
          ..close();
        canvas.drawPath(dome, fillPaint);

        // Carry handle ring
        canvas.drawCircle(Offset(w * 0.5, h * 0.15), w * 0.08, paint);

        // Little gas flame inside
        final flame = Path()
          ..moveTo(w * 0.5, h * 0.55)
          ..quadraticBezierTo(w * 0.44, h * 0.68, w * 0.5, h * 0.75)
          ..quadraticBezierTo(w * 0.56, h * 0.68, w * 0.5, h * 0.55);
        canvas.drawPath(flame, fillPaint);
        break;

      case ThematicIconType.sound:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.5, h * 0.15, w * 0.5, h * 0.15)
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.35, h * 0.35, w * 0.3, h * 0.65)
          ..lineTo(w * 0.70, h * 0.65)
          ..quadraticBezierTo(w * 0.65, h * 0.35, w * 0.5, h * 0.25)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.2));

        canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.06, fillPaint);
        canvas.drawLine(Offset(w * 0.25, h * 0.65), Offset(w * 0.75, h * 0.65), paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.16), w * 0.05, paint);
        break;

      case ThematicIconType.mute:
        final path = Path()
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.5, h * 0.15, w * 0.5, h * 0.15)
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.35, h * 0.35, w * 0.3, h * 0.65)
          ..lineTo(w * 0.70, h * 0.65)
          ..quadraticBezierTo(w * 0.65, h * 0.35, w * 0.5, h * 0.25)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.1));

        canvas.drawCircle(Offset(w * 0.5, h * 0.72), w * 0.06, fillPaint);
        canvas.drawLine(Offset(w * 0.25, h * 0.65), Offset(w * 0.75, h * 0.65), paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.16), w * 0.05, paint);

        // Mute slash line
        canvas.drawLine(Offset(w * 0.2, h * 0.2), Offset(w * 0.8, h * 0.8), paint..color = color);
        break;

      case ThematicIconType.ledger:
        // Left page
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.12, h * 0.2, w * 0.48, h * 0.8),
            Radius.circular(w * 0.04),
          ),
          paint,
        );
        // Right page
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(w * 0.52, h * 0.2, w * 0.88, h * 0.8),
            Radius.circular(w * 0.04),
          ),
          paint,
        );
        // Spine
        canvas.drawLine(Offset(w * 0.5, h * 0.18), Offset(w * 0.5, h * 0.82), paint);
        break;

      case ThematicIconType.envelope:
        final double rectW = w * 0.9;
        final double rectH = h * 0.62;
        final double left = (w - rectW) / 2;
        final double top = (h - rectH) / 2;
        final double right = left + rectW;
        final double bottom = top + rectH;
        canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
        // Flaps
        canvas.drawLine(Offset(left, top), Offset(w * 0.5, top + rectH * 0.5), paint);
        canvas.drawLine(Offset(right, top), Offset(w * 0.5, top + rectH * 0.5), paint);
        break;

      case ThematicIconType.redraw:
        final double r = w * 0.38;
        final double endAngle = -math.pi / 2 + 300.0 * math.pi / 180.0;
        final double endX = center.dx + r * math.cos(endAngle);
        final double endY = center.dy + r * math.sin(endAngle);
        
        final redrawPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08 * w
          ..strokeCap = StrokeCap.round;
        
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi / 2,
          300.0 * math.pi / 180.0,
          false,
          redrawPaint,
        );
        
        // Arrowhead
        final double tangentAngle = endAngle + math.pi / 2;
        final double angle1 = tangentAngle + 5 * math.pi / 4;
        final double angle2 = tangentAngle + 3 * math.pi / 4;
        final double arrowLen = 0.18 * w;
        
        canvas.drawLine(
          Offset(endX, endY),
          Offset(endX + arrowLen * math.cos(angle1), endY + arrowLen * math.sin(angle1)),
          redrawPaint..strokeWidth = paint.strokeWidth,
        );
        canvas.drawLine(
          Offset(endX, endY),
          Offset(endX + arrowLen * math.cos(angle2), endY + arrowLen * math.sin(angle2)),
          redrawPaint..strokeWidth = paint.strokeWidth,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaxSealBadge extends StatelessWidget {
  final double size;
  final Color color;
  final String? label;

  const WaxSealBadge({
    super.key,
    this.size = 24,
    this.color = AppColors.oxblood,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WaxSealPainter(color: color, label: label),
      ),
    );
  }
}

class _WaxSealPainter extends CustomPainter {
  final Color color;
  final String? label;

  _WaxSealPainter({required this.color, this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final double sz = size.width;
    final Offset center = Offset(sz / 2, sz / 2);
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Wax blob
    final path = Path();
    for (int i = 0; i <= 360; i += 10) {
      double rad = i * math.pi / 180;
      double r = 0.42 * sz * (1.0 + 0.06 * math.sin(5.0 * rad + 1.3) + 0.04 * math.cos(3.0 * rad));
      double x = center.dx + r * math.cos(rad);
      double y = center.dy + r * math.sin(rad);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fillPaint);

    // 2. Pressed ring
    final ringPaint = Paint()
      ..color = Color.lerp(color, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * sz;
    canvas.drawCircle(center, 0.26 * sz, ringPaint);

    // 3. Emboss starburst or label text
    if (label != null && label!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontSize: 0.32 * sz,
            fontWeight: FontWeight.bold,
            color: AppColors.brass,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
      );
    } else {
      final starPaint = Paint()
        ..color = AppColors.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04 * sz
        ..strokeCap = StrokeCap.round;
      final double spokeLen = 0.14 * sz;
      for (int i = 0; i < 6; i++) {
        double angle = i * math.pi / 3;
        double x = center.dx + spokeLen * math.cos(angle);
        double y = center.dy + spokeLen * math.sin(angle);
        canvas.drawLine(center, Offset(x, y), starPaint);
      }
      final centerPaint = Paint()
        ..color = AppColors.brass
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 0.05 * sz, centerPaint);
    }

    // 4. Highlight
    final highlightPaint = Paint()
      ..color = AppColors.ivory.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * sz
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 0.36 * sz),
      200.0 * math.pi / 180.0,
      50.0 * math.pi / 180.0,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _WaxSealPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.label != label;
  }
}

class SigilTicker {
  static final SigilTicker _instance = SigilTicker._internal();
  factory SigilTicker() => _instance;
  SigilTicker._internal() {
    autoStartEnabled = !WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  bool autoStartEnabled = true;

  final List<VoidCallback> _subscribers = [];
  math.Random? _random;
  Timer? _timer;

  List<VoidCallback> get subscribers => _subscribers;

  void register(VoidCallback onPulse) {
    _subscribers.add(onPulse);
    if (autoStartEnabled) {
      _ensureTimerRunning();
    }
  }

  void unregister(VoidCallback onPulse) {
    _subscribers.remove(onPulse);
    if (_subscribers.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _ensureTimerRunning() {
    if (_timer != null) return;
    _random ??= math.Random();
    _scheduleNextPulse();
  }

  void _scheduleNextPulse() {
    _timer?.cancel();
    if (!autoStartEnabled) return;
    final delaySeconds = 6 + _random!.nextInt(5);
    _timer = Timer(Duration(seconds: delaySeconds), () {
      _pulseRandomSubscriber();
      _scheduleNextPulse();
    });
  }

  void _pulseRandomSubscriber() {
    if (_subscribers.isEmpty) return;
    _random ??= math.Random();
    final index = _random!.nextInt(_subscribers.length);
    _subscribers[index]();
  }

  void manualPulse() {
    _pulseRandomSubscriber();
  }
}

class AnimatedThematicIcon extends StatefulWidget {
  final ThematicIconType type;
  final double size;
  final Color color;

  const AnimatedThematicIcon({
    super.key,
    required this.type,
    this.size = 24.0,
    this.color = const Color(0xFFC5A059),
  });

  @override
  State<AnimatedThematicIcon> createState() => _AnimatedThematicIconState();
}

class _AnimatedThematicIconState extends State<AnimatedThematicIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    SigilTicker().register(_pulse);
  }

  void _pulse() {
    if (mounted && !AppMotion.reduce(context)) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    SigilTicker().unregister(_pulse);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _AnimatedThematicIconPainter(
              widget.type,
              widget.color,
              _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _AnimatedThematicIconPainter extends CustomPainter {
  final ThematicIconType type;
  final Color color;
  final double t;

  _AnimatedThematicIconPainter(this.type, this.color, this.t);

  double getFlameScaleY(double t) {
    if (t <= 0.35) {
      return 1.0 + 0.12 * (t / 0.35);
    } else if (t <= 0.6) {
      final double ratio = (t - 0.35) / 0.25;
      return 1.12 - 0.18 * ratio;
    } else {
      final double ratio = (t - 0.6) / 0.4;
      return 0.94 + 0.06 * ratio;
    }
  }

  double getMothRotation(double t) {
    if (t <= 0.0 || t >= 0.7) return 0.0;
    return 18.0 * math.pi / 180.0 * math.sin(2 * math.pi * t / 0.7) * math.sin(math.pi * t / 0.7);
  }

  double getRavenEyeScaleY(double t) {
    if (t >= 0.3 && t <= 0.5) {
      final double phase = (t - 0.3) / 0.2;
      return 1.0 - 0.9 * math.sin(phase * math.pi);
    }
    return 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width / 16)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    switch (type) {
      case ThematicIconType.flame:
        canvas.save();
        // Scale flame vertically about its base
        canvas.translate(w / 2, h * 0.9);
        canvas.scale(1.0, getFlameScaleY(t));
        canvas.translate(-w / 2, -h * 0.9);

        final path = Path();
        path.moveTo(w * 0.5, h * 0.1);
        path.quadraticBezierTo(w * 0.2, h * 0.45, w * 0.25, h * 0.7);
        path.quadraticBezierTo(w * 0.3, h * 0.9, w * 0.5, h * 0.9);
        path.quadraticBezierTo(w * 0.7, h * 0.9, w * 0.75, h * 0.7);
        path.quadraticBezierTo(w * 0.8, h * 0.4, w * 0.5, h * 0.1);
        
        final innerPath = Path();
        innerPath.moveTo(w * 0.5, h * 0.4);
        innerPath.quadraticBezierTo(w * 0.35, h * 0.6, w * 0.38, h * 0.75);
        innerPath.quadraticBezierTo(w * 0.5, h * 0.85, w * 0.5, h * 0.85);
        innerPath.quadraticBezierTo(w * 0.5, h * 0.85, w * 0.62, h * 0.75);
        innerPath.quadraticBezierTo(w * 0.65, h * 0.6, w * 0.5, h * 0.4);

        canvas.drawPath(path, paint);
        canvas.drawPath(innerPath, paint);
        canvas.restore();
        break;

      case ThematicIconType.moth:
        // Body
        final bodyPath = Path()
          ..moveTo(w * 0.5, h * 0.25)
          ..quadraticBezierTo(w * 0.45, h * 0.5, w * 0.5, h * 0.75)
          ..quadraticBezierTo(w * 0.55, h * 0.5, w * 0.5, h * 0.25);
        canvas.drawPath(bodyPath, fillPaint);

        // Antennae
        final antennaePath = Path()
          ..moveTo(w * 0.47, h * 0.2)
          ..quadraticBezierTo(w * 0.4, h * 0.12, w * 0.35, h * 0.14)
          ..moveTo(w * 0.53, h * 0.2)
          ..quadraticBezierTo(w * 0.6, h * 0.12, w * 0.65, h * 0.14);
        canvas.drawPath(antennaePath, paint);

        // Left Wing
        canvas.save();
        canvas.translate(w * 0.49, h * 0.35);
        canvas.rotate(-getMothRotation(t));
        canvas.translate(-w * 0.49, -h * 0.35);
        final leftWing = Path()
          ..moveTo(w * 0.49, h * 0.35)
          ..cubicTo(w * 0.2, h * 0.15, w * 0.1, h * 0.35, w * 0.15, h * 0.55)
          ..quadraticBezierTo(w * 0.3, h * 0.65, w * 0.49, h * 0.5);
        canvas.drawPath(leftWing, paint);
        canvas.drawLine(Offset(w * 0.4, h * 0.4), Offset(w * 0.25, h * 0.45), paint);
        canvas.restore();

        // Right Wing
        canvas.save();
        canvas.translate(w * 0.51, h * 0.35);
        canvas.rotate(getMothRotation(t));
        canvas.translate(-w * 0.51, -h * 0.35);
        final rightWing = Path()
          ..moveTo(w * 0.51, h * 0.35)
          ..cubicTo(w * 0.8, h * 0.15, w * 0.9, h * 0.35, w * 0.85, h * 0.55)
          ..quadraticBezierTo(w * 0.7, h * 0.65, w * 0.51, h * 0.5);
        canvas.drawPath(rightWing, paint);
        canvas.drawLine(Offset(w * 0.6, h * 0.4), Offset(w * 0.75, h * 0.45), paint);
        canvas.restore();
        break;

      case ThematicIconType.key:
      case ThematicIconType.secret:
        // Key Head (Oval/Fancy loop)
        canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.18, paint);
        canvas.drawCircle(Offset(w * 0.5, h * 0.3), w * 0.08, paint);
        
        // Shaft
        canvas.drawLine(Offset(w * 0.5, h * 0.48), Offset(w * 0.5, h * 0.85), paint);
        
        // Bit / Teeth
        final bitPath = Path()
          ..moveTo(w * 0.5, h * 0.68)
          ..lineTo(w * 0.7, h * 0.68)
          ..lineTo(w * 0.7, h * 0.75)
          ..lineTo(w * 0.58, h * 0.75)
          ..lineTo(w * 0.58, h * 0.79)
          ..lineTo(w * 0.7, h * 0.79)
          ..lineTo(w * 0.7, h * 0.85)
          ..lineTo(w * 0.5, h * 0.85);
        canvas.drawPath(bitPath, paint);

        // Sweeping highlight along the shaft
        if (t > 0.0) {
          final double shaftStartY = h * 0.48;
          final double shaftEndY = h * 0.85;
          final double highlightY = shaftStartY + (shaftEndY - shaftStartY) * t;
          final double halfWidth = 0.075 * w;

          final highlightPaint = Paint()
            ..color = AppColors.ivory.withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = paint.strokeWidth * 1.5
            ..strokeCap = StrokeCap.round;

          final double startY = math.max(shaftStartY, highlightY - halfWidth);
          final double endY = math.min(shaftEndY, highlightY + halfWidth);
          if (startY < endY) {
            canvas.drawLine(Offset(w * 0.5, startY), Offset(w * 0.5, endY), highlightPaint);
          }
        }
        break;

      case ThematicIconType.raven:
        // Stylized silhouette of a sitting raven / bird
        final path = Path()
          ..moveTo(w * 0.35, h * 0.25)
          ..lineTo(w * 0.48, h * 0.28)
          ..quadraticBezierTo(w * 0.55, h * 0.18, w * 0.62, h * 0.25)
          ..quadraticBezierTo(w * 0.75, h * 0.45, w * 0.7, h * 0.7)
          ..quadraticBezierTo(w * 0.6, h * 0.85, w * 0.45, h * 0.8)
          ..quadraticBezierTo(w * 0.4, h * 0.55, w * 0.48, h * 0.4)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.25));

        // Eye dot
        final eyeCenter = Offset(w * 0.56, h * 0.32);
        canvas.save();
        canvas.translate(eyeCenter.dx, eyeCenter.dy);
        canvas.scale(1.0, getRavenEyeScaleY(t));
        canvas.drawCircle(Offset.zero, w * 0.04, fillPaint..color = color);
        canvas.restore();
        break;

      case ThematicIconType.moon:
        final double drift = 0.08 * w * math.sin(math.pi * t);
        final path = Path()
          ..moveTo(w * 0.35, h * 0.2)
          ..cubicTo(w * 0.7, h * 0.2, w * 0.7, h * 0.8, w * 0.35, h * 0.8)
          ..cubicTo(w * 0.55 + drift, h * 0.7, w * 0.55 + drift, h * 0.3, w * 0.35, h * 0.2)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(path, fillPaint..color = color.withOpacity(0.2));
        break;

      case ThematicIconType.hourglass:
      case ThematicIconType.timer:
        // Top and bottom plates
        canvas.drawLine(Offset(w * 0.25, h * 0.15), Offset(w * 0.75, h * 0.15), paint);
        canvas.drawLine(Offset(w * 0.25, h * 0.85), Offset(w * 0.75, h * 0.85), paint);
        
        // Pillars / frame
        canvas.drawLine(Offset(w * 0.28, h * 0.15), Offset(w * 0.28, h * 0.85), paint);
        canvas.drawLine(Offset(w * 0.72, h * 0.15), Offset(w * 0.72, h * 0.85), paint);

        // Glass bulbs
        final glassPath = Path()
          ..moveTo(w * 0.32, h * 0.2)
          ..cubicTo(w * 0.35, h * 0.45, w * 0.46, h * 0.48, w * 0.46, h * 0.5)
          ..cubicTo(w * 0.46, h * 0.52, w * 0.35, h * 0.55, w * 0.32, h * 0.8)
          ..moveTo(w * 0.68, h * 0.2)
          ..cubicTo(w * 0.65, h * 0.45, w * 0.54, h * 0.48, w * 0.54, h * 0.5)
          ..cubicTo(w * 0.54, h * 0.52, w * 0.65, h * 0.55, w * 0.68, h * 0.8);
        canvas.drawPath(glassPath, paint);

        // Sand pile top
        final sandTop = Path()
          ..moveTo(w * 0.4, h * 0.35)
          ..quadraticBezierTo(w * 0.5, h * 0.38, w * 0.6, h * 0.35)
          ..lineTo(w * 0.52, h * 0.49)
          ..lineTo(w * 0.48, h * 0.49)
          ..close();
        canvas.drawPath(sandTop, fillPaint..color = color.withOpacity(0.5));

        // Sand pile bottom
        final double growth = (t >= 0.2 && t <= 0.8) ? ((t - 0.2) / 0.6) * 1.5 : (t > 0.8 ? 1.5 : 0.0);
        final sandBottom = Path()
          ..moveTo(w * 0.48, h * 0.5)
          ..lineTo(w * 0.52, h * 0.5)
          ..lineTo(w * 0.65, h * 0.8)
          ..lineTo(w * 0.35, h * 0.8)
          ..close();
        canvas.drawPath(sandBottom, fillPaint..color = color);

        if (growth > 0) {
          final pilePath = Path()
            ..moveTo(w * 0.42, h * 0.8)
            ..quadraticBezierTo(w * 0.5, h * 0.8 - growth - 2.0, w * 0.58, h * 0.8)
            ..close();
          canvas.drawPath(pilePath, fillPaint..color = color);
        }

        // Falling grain
        if (t >= 0.2 && t <= 0.8) {
          final double phase = (t - 0.2) / 0.6;
          final double grainY = h * 0.38 + (h * 0.8 - h * 0.38) * phase;
          canvas.drawCircle(Offset(w * 0.5, grainY), 1.5, fillPaint..color = color);
        }
        break;

      default:
        // Fall back to static painter
        _ThematicIconPainter(type, color).paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedThematicIconPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color || oldDelegate.t != t;
  }
}

