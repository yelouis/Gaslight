import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class BlinkingEye extends StatefulWidget {
  final double size;
  final Color? color;

  const BlinkingEye({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  State<BlinkingEye> createState() => _BlinkingEyeState();
}

class _BlinkingEyeState extends State<BlinkingEye> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleYAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleYAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefersReducedMotion = AppMotion.reduce(context);
    if (prefersReducedMotion) {
      _controller.stop();
      _timer?.cancel();
    } else {
      if (!_controller.isAnimating) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 4500), (timer) {
          if (mounted && !AppMotion.reduce(context)) {
            _controller.forward(from: 0.0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = AppMotion.reduce(context);
    final eyeColor = widget.color ?? AppColors.brass;

    return SizedBox(
      width: widget.size * 1.4,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _scaleYAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _BlinkingEyePainter(
              scaleY: prefersReducedMotion ? 1.0 : _scaleYAnimation.value,
              color: eyeColor,
            ),
          );
        },
      ),
    );
  }
}

class _BlinkingEyePainter extends CustomPainter {
  final double scaleY;
  final Color color;

  _BlinkingEyePainter({
    required this.scaleY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Eye contour path
    final path = Path();
    path.moveTo(0, h / 2);
    path.quadraticBezierTo(w / 2, h / 2 - (h / 2) * scaleY, w, h / 2);
    path.quadraticBezierTo(w / 2, h / 2 + (h / 2) * scaleY, 0, h / 2);
    path.close();

    canvas.save();
    canvas.clipPath(path);

    // Draw iris: brass/chosen color circle
    final irisPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.25, irisPaint);

    // Draw pupil: ground (dark) color circle
    final pupilPaint = Paint()
      ..color = AppColors.ground
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.12, pupilPaint);

    canvas.restore();

    // Draw eyelids stroke
    final strokePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _BlinkingEyePainter oldDelegate) {
    return oldDelegate.scaleY != scaleY || oldDelegate.color != color;
  }
}
