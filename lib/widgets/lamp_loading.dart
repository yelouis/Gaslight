import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_motion.dart';
import '../theme/candle_paths.dart';

class LampLightingIndicator extends StatefulWidget {
  final double size;

  const LampLightingIndicator({super.key, this.size = 96.0});

  @override
  State<LampLightingIndicator> createState() => _LampLightingIndicatorState();
}

class _LampLightingIndicatorState extends State<LampLightingIndicator> with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _sustainController;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _sustainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _sustainController.repeat(reverse: true);
      }
    });

    _introController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduce(context)) {
      _introController.stop();
      _sustainController.stop();
    } else if (!_introController.isAnimating && !_sustainController.isAnimating) {
      _introController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _introController.dispose();
    _sustainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool prefersReducedMotion = AppMotion.reduce(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: Listenable.merge([_introController, _sustainController]),
            builder: (context, child) {
              return CustomPaint(
                painter: _LampPainter(
                  introValue: prefersReducedMotion ? 1.0 : _introController.value,
                  sustainValue: prefersReducedMotion ? 0.5 : _sustainController.value,
                  isStatic: prefersReducedMotion,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'LIGHTING THE LAMPS…',
          style: AppTextStyles.sectionLabel,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LampPainter extends CustomPainter {
  final double introValue;
  final double sustainValue;
  final bool isStatic;

  _LampPainter({
    required this.introValue,
    required this.sustainValue,
    required this.isStatic,
  });

  Offset _getSparkOffset(double phase, Size size, Offset endPoint) {
    final start = Offset(size.width, size.height);
    final control = Offset(size.width * 0.8, size.height * 0.4);

    final double x = (1 - phase) * (1 - phase) * start.dx +
        2 * (1 - phase) * phase * control.dx +
        phase * phase * endPoint.dx;
    final double y = (1 - phase) * (1 - phase) * start.dy +
        2 * (1 - phase) * phase * control.dy +
        phase * phase * endPoint.dy;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Offset bulbCenter = Offset(w / 2, 0.38 * h);
    final double bulbRadius = 0.22 * w;

    // Draw radial glow
    double glowOpacity = 0.0;
    double glowRadius = 0.0;

    if (isStatic) {
      glowOpacity = 0.3;
      glowRadius = 0.55 * w;
    } else if (introValue < 0.5) {
      glowOpacity = 0.0;
      glowRadius = 0.0;
    } else if (introValue < 1.0) {
      // Bloom phase
      final double bloomPhase = Curves.easeOut.transform((introValue - 0.5) / 0.5);
      glowOpacity = 0.35 * bloomPhase;
      glowRadius = 0.55 * w * bloomPhase;
    } else {
      // Sustain phase
      glowOpacity = 0.25 + (0.40 - 0.25) * sustainValue;
      glowRadius = 0.55 * w;
    }

    if (glowOpacity > 0.0 && glowRadius > 0.0) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.brass.withOpacity(glowOpacity),
            AppColors.brass.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: bulbCenter, radius: glowRadius))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(bulbCenter, glowRadius, glowPaint);
    }

    // Static fixture: vertical brass stem 3 dp wide from bottom to 40% height (so top of stem is at 60% height)
    final stemPaint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, 0.6 * h), stemPaint);

    // Glass bulb: circle r 0.22*size, stroke 2 dp brass @0.7, centered at 0.38*size from top
    final bulbPaint = Paint()
      ..color = AppColors.brass.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(bulbCenter, bulbRadius, bulbPaint);

    // Intro t 0–0.25 "strike" spark
    if (!isStatic && introValue < 0.25) {
      final double sparkPhase = introValue / 0.25;
      final sparkPaint = Paint()
        ..color = AppColors.ivory
        ..style = PaintingStyle.fill;
      canvas.drawCircle(_getSparkOffset(sparkPhase, size, bulbCenter), 3.0, sparkPaint);

      // Trailing tail
      for (int i = 1; i <= 5; i++) {
        final double tailPhase = sparkPhase - i * 0.02;
        if (tailPhase > 0) {
          final tailPaint = Paint()
            ..color = AppColors.ivory.withOpacity(0.4 * (1 - i / 5.0))
            ..style = PaintingStyle.fill;
          canvas.drawCircle(_getSparkOffset(tailPhase, size, bulbCenter), 2.0 * (1 - i / 5.0), tailPaint);
        }
      }
    }

    // Intro t 0.25–0.5 "catch" teardrop flame
    double flameScale = 0.0;
    double swayX = 0.0;

    if (isStatic) {
      flameScale = 1.0;
      swayX = 0.0;
    } else if (introValue >= 0.25 && introValue < 0.5) {
      final double catchPhase = (introValue - 0.25) / 0.25;
      flameScale = Curves.easeOutBack.transform(catchPhase);
      swayX = 0.0;
    } else if (introValue >= 0.5) {
      flameScale = 1.0;
      if (introValue >= 1.0) {
        swayX = math.sin(sustainValue * 2 * math.pi) * 2.0;
      }
    }

    if (flameScale > 0.0) {
      final double baseFlameHeight = 24.0 * flameScale;
      final double baseFlameWidth = 10.0 * flameScale;

      final Offset flameWickTop = Offset(bulbCenter.dx, bulbCenter.dy + baseFlameHeight * 0.4);

      // Outer flame path
      final outerPaint = Paint()
        ..color = AppColors.brass.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      final Path outerPath = CandlePaths.flamePath(
        wickTop: flameWickTop,
        baseWidth: baseFlameWidth,
        flameHeight: baseFlameHeight,
        swayX: swayX,
      );
      canvas.drawPath(outerPath, outerPaint);

      // Core flame path
      final corePaint = Paint()
        ..color = AppColors.ivory.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      final double coreHeight = baseFlameHeight * 0.55;
      final double coreWidth = baseFlameWidth * 0.55;

      final Path corePath = CandlePaths.flamePath(
        wickTop: flameWickTop,
        baseWidth: coreWidth,
        flameHeight: coreHeight,
        swayX: swayX * 0.55,
      );
      canvas.drawPath(corePath, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LampPainter oldDelegate) {
    return oldDelegate.introValue != introValue ||
        oldDelegate.sustainValue != sustainValue ||
        oldDelegate.isStatic != isStatic;
  }
}
