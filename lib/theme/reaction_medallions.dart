import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'candle_paths.dart';

enum ReactionType {
  laugh,
  monocle,
  serpent,
  applause,
  flame,
  fallback,
}

class ReactionMedallion extends StatelessWidget {
  final ReactionType type;
  final String fallbackEmoji;
  final double size;

  const ReactionMedallion({
    super.key,
    required this.type,
    this.fallbackEmoji = '',
    this.size = 44.0,
  });

  factory ReactionMedallion.fromEmoji(String emoji, {double size = 44.0}) {
    ReactionType type;
    switch (emoji) {
      case '😂':
        type = ReactionType.laugh;
        break;
      case '🤨':
        type = ReactionType.monocle;
        break;
      case '🐍':
        type = ReactionType.serpent;
        break;
      case '👏':
        type = ReactionType.applause;
        break;
      case '🔥':
        type = ReactionType.flame;
        break;
      default:
        type = ReactionType.fallback;
    }
    return ReactionMedallion(
      type: type,
      fallbackEmoji: emoji,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MedallionPainter(
          type: type,
          fallbackEmoji: fallbackEmoji,
          size: size,
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  final ReactionType type;
  final String fallbackEmoji;
  final double size;

  _MedallionPainter({
    required this.type,
    required this.fallbackEmoji,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double s = size.width;

    // 1. Disc: circle fill parchment, r 0.5 * size
    final discPaint = Paint()
      ..color = AppColors.parchment
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), 0.5 * s, discPaint);

    // 2. Rim: brass stroke at r 0.49 * size (width 0.08 * size)
    final outerRimPaint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.08 * s;
    canvas.drawCircle(Offset(cx, cy), 0.45 * s, outerRimPaint);

    // Inner rim: brass stroke at r 0.39 * size (width 0.02 * size)
    final innerRimPaint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02 * s;
    canvas.drawCircle(Offset(cx, cy), 0.38 * s, innerRimPaint);

    // 3. Motif engraved in ink, stroke width 0.05 * size, contained in r 0.35 * size
    final motifPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case ReactionType.laugh:
        // Wide inverted-U face
        final maskPath = Path();
        maskPath.moveTo(cx - 0.16 * s, cy + 0.10 * s);
        maskPath.cubicTo(
          cx - 0.16 * s, cy - 0.25 * s,
          cx + 0.16 * s, cy - 0.25 * s,
          cx + 0.16 * s, cy + 0.10 * s,
        );
        maskPath.lineTo(cx - 0.16 * s, cy + 0.10 * s);
        canvas.drawPath(maskPath, motifPaint);

        // Downturned-arc eyes (curving up like ^)
        final eyeL = Path();
        eyeL.moveTo(cx - 0.10 * s, cy - 0.05 * s);
        eyeL.quadraticBezierTo(cx - 0.07 * s, cy - 0.10 * s, cx - 0.04 * s, cy - 0.05 * s);
        canvas.drawPath(eyeL, motifPaint);

        final eyeR = Path();
        eyeR.moveTo(cx + 0.04 * s, cy - 0.05 * s);
        eyeR.quadraticBezierTo(cx + 0.07 * s, cy - 0.10 * s, cx + 0.10 * s, cy - 0.05 * s);
        canvas.drawPath(eyeR, motifPaint);

        // Wide smile arc
        final smile = Path();
        smile.moveTo(cx - 0.09 * s, cy + 0.03 * s);
        smile.quadraticBezierTo(cx, cy + 0.12 * s, cx + 0.09 * s, cy + 0.03 * s);
        canvas.drawPath(smile, motifPaint);
        break;

      case ReactionType.monocle:
        // circle offset up-left
        canvas.drawCircle(Offset(cx - 0.06 * s, cy - 0.06 * s), 0.15 * s, motifPaint);

        // handle line down-right
        canvas.drawLine(Offset(cx + 0.03 * s, cy + 0.03 * s), Offset(cx + 0.15 * s, cy + 0.15 * s), motifPaint);

        // raised-eyebrow arc above
        final eyebrow = Path();
        eyebrow.moveTo(cx - 0.20 * s, cy - 0.20 * s);
        eyebrow.quadraticBezierTo(cx - 0.06 * s, cy - 0.30 * s, cx + 0.08 * s, cy - 0.20 * s);
        canvas.drawPath(eyebrow, motifPaint);
        break;

      case ReactionType.serpent:
        // S-curve (two joined cubics)
        final serpentPath = Path();
        serpentPath.moveTo(cx + 0.05 * s, cy - 0.15 * s);
        serpentPath.cubicTo(
          cx + 0.20 * s, cy - 0.15 * s,
          cx - 0.20 * s, cy + 0.02 * s,
          cx, cy + 0.02 * s,
        );
        serpentPath.cubicTo(
          cx + 0.20 * s, cy + 0.02 * s,
          cx - 0.20 * s, cy + 0.18 * s,
          cx - 0.05 * s, cy + 0.18 * s,
        );
        canvas.drawPath(serpentPath, motifPaint);

        // head dot 0.06 * size diameter -> radius 0.03 * size
        canvas.drawCircle(Offset(cx + 0.05 * s, cy - 0.15 * s), 0.03 * s, Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.fill);

        // two-line forked tongue
        final tonguePaint = Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.03 * s;
        canvas.drawLine(Offset(cx + 0.05 * s, cy - 0.15 * s), Offset(cx + 0.09 * s, cy - 0.23 * s), tonguePaint);
        canvas.drawLine(Offset(cx + 0.09 * s, cy - 0.23 * s), Offset(cx + 0.08 * s, cy - 0.28 * s), tonguePaint);
        canvas.drawLine(Offset(cx + 0.09 * s, cy - 0.23 * s), Offset(cx + 0.14 * s, cy - 0.25 * s), tonguePaint);
        break;

      case ReactionType.applause:
        // Left hand glove shape
        canvas.save();
        canvas.translate(cx - 0.08 * s, cy);
        canvas.rotate(math.pi / 12);
        final Path gloveL = Path();
        gloveL.moveTo(-0.12 * s, 0.08 * s);
        gloveL.lineTo(-0.12 * s, -0.08 * s);
        gloveL.quadraticBezierTo(-0.12 * s, -0.15 * s, -0.05 * s, -0.15 * s);
        gloveL.lineTo(0.08 * s, -0.15 * s);
        gloveL.quadraticBezierTo(0.12 * s, -0.10 * s, 0.12 * s, -0.05 * s);
        gloveL.lineTo(0.12 * s, 0.05 * s);
        gloveL.quadraticBezierTo(0.12 * s, 0.08 * s, 0.05 * s, 0.08 * s);
        gloveL.close();
        canvas.drawPath(gloveL, motifPaint);
        canvas.drawPath(Path()..moveTo(0.04 * s, -0.05 * s)..quadraticBezierTo(0.08 * s, 0.05 * s, 0.08 * s, 0.08 * s), motifPaint);
        canvas.restore();

        // Right hand glove shape
        canvas.save();
        canvas.translate(cx + 0.08 * s, cy);
        canvas.rotate(-math.pi / 12);
        final Path gloveR = Path();
        gloveR.moveTo(0.12 * s, 0.08 * s);
        gloveR.lineTo(0.12 * s, -0.08 * s);
        gloveR.quadraticBezierTo(0.12 * s, -0.15 * s, 0.05 * s, -0.15 * s);
        gloveR.lineTo(-0.08 * s, -0.15 * s);
        gloveR.quadraticBezierTo(-0.12 * s, -0.10 * s, -0.12 * s, -0.05 * s);
        gloveR.lineTo(-0.12 * s, 0.05 * s);
        gloveR.quadraticBezierTo(-0.12 * s, 0.08 * s, -0.05 * s, 0.08 * s);
        gloveR.close();
        canvas.drawPath(gloveR, motifPaint);
        canvas.drawPath(Path()..moveTo(-0.04 * s, -0.05 * s)..quadraticBezierTo(-0.08 * s, 0.05 * s, -0.08 * s, 0.08 * s), motifPaint);
        canvas.restore();

        // Three small motion arcs between (width 0.04 * size)
        final arcPaint = Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.04 * s
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 0.12 * s), -math.pi / 3, math.pi / 6, false, arcPaint);
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 0.16 * s), -math.pi / 3 - 0.1, math.pi / 6 + 0.2, false, arcPaint);
        canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: 0.08 * s), -math.pi / 3 + 0.1, math.pi / 6 - 0.2, false, arcPaint);
        break;

      case ReactionType.flame:
        final double flameHeight = 0.40 * s;
        final double baseFlameWidth = 0.18 * s;
        final Offset flameWickTop = Offset(cx, cy + flameHeight * 0.35);

        // Outer flame path stroked in ink
        final Path outerPath = CandlePaths.flamePath(
          wickTop: flameWickTop,
          baseWidth: baseFlameWidth,
          flameHeight: flameHeight,
          swayX: 0,
        );
        canvas.drawPath(outerPath, motifPaint);

        // Core flame path: filled with oxblood
        final corePaint = Paint()
          ..color = AppColors.oxblood
          ..style = PaintingStyle.fill;
        final Path corePath = CandlePaths.flamePath(
          wickTop: flameWickTop,
          baseWidth: baseFlameWidth * 0.45,
          flameHeight: flameHeight * 0.45,
          swayX: 0,
        );
        canvas.drawPath(corePath, corePaint);
        break;

      case ReactionType.fallback:
        final textPainter = TextPainter(
          text: TextSpan(
            text: fallbackEmoji,
            style: TextStyle(fontSize: 0.48 * s),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.fallbackEmoji != fallbackEmoji || oldDelegate.size != size;
  }
}
