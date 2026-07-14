import 'package:flutter/material.dart';
import 'dart:math' as math;

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
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
