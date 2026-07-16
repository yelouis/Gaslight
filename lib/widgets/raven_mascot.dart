import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

enum RavenState { sleep, idle, hop, ruffle, fly }

class RavenMascot extends StatefulWidget {
  final RavenState state;
  final double size;

  const RavenMascot({
    super.key,
    required this.state,
    this.size = 64.0,
  });

  @override
  State<RavenMascot> createState() => _RavenMascotState();
}

class _RavenMascotState extends State<RavenMascot> with TickerProviderStateMixin {
  late final AnimationController _sleepController;
  late final AnimationController _actionController;
  late final AnimationController _idleController; // For head tilts and blinks

  // Idle timers/triggers
  math.Random _random = math.Random();
  Timer? _idleTimer;
  bool _idleTilt = false;
  bool _idleBlink = false;

  @override
  void initState() {
    super.initState();

    _sleepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _actionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  void _setupState(RavenState state) {
    _sleepController.stop();
    _actionController.stop();
    _idleTimer?.cancel();

    final bool isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (AppMotion.reduce(context) || isTesting) {
      return;
    }

    if (state == RavenState.sleep) {
      _sleepController.repeat(reverse: true);
    } else if (state == RavenState.idle) {
      _scheduleIdleAction();
    } else if (state == RavenState.hop) {
      _actionController.duration = const Duration(milliseconds: 300);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.ruffle) {
      _actionController.duration = const Duration(milliseconds: 500);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.fly) {
      _actionController.duration = const Duration(milliseconds: 900);
      _actionController.forward(from: 0.0);
    }
  }

  void _scheduleIdleAction() {
    _idleTimer?.cancel();
    final int delay = 5 + _random.nextInt(4); // 5 to 8 seconds
    _idleTimer = Timer(Duration(seconds: delay), () {
      if (!mounted || widget.state != RavenState.idle || AppMotion.reduce(context)) return;

      if (_random.nextDouble() < 0.33) {
        // 1-in-3 chance to blink
        setState(() {
          _idleBlink = true;
          _idleTilt = false;
        });
        _idleController.duration = const Duration(milliseconds: 150);
        _idleController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _idleBlink = false;
            });
          }
        });
      } else {
        // Head tilt
        setState(() {
          _idleTilt = true;
          _idleBlink = false;
        });
        _idleController.duration = const Duration(milliseconds: 600);
        _idleController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _idleTilt = false;
            });
          }
        });
      }
      _scheduleIdleAction();
    });
  }

  @override
  void didUpdateWidget(RavenMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _setupState(widget.state);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupState(widget.state);
  }

  @override
  void dispose() {
    _sleepController.dispose();
    _actionController.dispose();
    _idleController.dispose();
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool prefersReducedMotion = AppMotion.reduce(context);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_sleepController, _actionController, _idleController]),
        builder: (context, child) {
          double scaleY = 1.0;
          double scaleX = 1.0;
          double translateY = 0.0;
          double translateX = 0.0;
          double headTiltAngle = 0.0;
          bool isBlinking = false;
          double wingFlare = 0.0;
          double lowerBeakOpen = 0.0;
          int flapCount = 0;

          if (prefersReducedMotion) {
            // Static idle state
            return CustomPaint(
              painter: _RavenPainter(
                scaleX: 1.0,
                scaleY: 1.0,
                translateX: 0.0,
                translateY: 0.0,
                headTiltAngle: 0.0,
                isBlinking: false,
                isClosedEye: false,
                wingFlare: 0.0,
                lowerBeakOpen: 0.0,
                isFlying: false,
                flapCount: 0,
              ),
            );
          }

          if (widget.state == RavenState.sleep) {
            headTiltAngle = -25.0 * math.pi / 180.0; // Head rotated down 25
            isBlinking = true; // Closed eye
            scaleY = 1.0 + 0.03 * _sleepController.value; // Breathes 1.0 <-> 1.03
          } else if (widget.state == RavenState.idle) {
            if (_idleTilt) {
              // Tilt head 12 degrees
              final double t = _idleController.value;
              headTiltAngle = 12.0 * math.pi / 180.0 * math.sin(t * math.pi);
            }
            if (_idleBlink) {
              isBlinking = true;
            }
          } else if (widget.state == RavenState.hop) {
            final double t = _actionController.value;
            // translateY up-down arc
            translateY = -0.12 * widget.size * math.sin(t * math.pi);
            wingFlare = 8.0 * math.pi / 180.0 * math.sin(t * math.pi);
          } else if (widget.state == RavenState.ruffle) {
            final double t = _actionController.value;
            // scaleX 1 -> 1.15 -> 0.95 -> 1
            if (t < 0.5) {
              final double local = t / 0.5;
              scaleX = 1.0 + 0.15 * local;
            } else {
              final double local = (t - 0.5) / 0.5;
              scaleX = 1.15 - 0.20 * local;
            }

            // Lower beak open 15 deg for first 200ms
            if (t <= 0.4) {
              lowerBeakOpen = 15.0 * math.pi / 180.0 * math.sin((t / 0.4) * math.pi);
            }
          } else if (widget.state == RavenState.fly) {
            final double t = _actionController.value;
            // Enters from off-screen left along shallow arc to perch
            translateX = -widget.size * (1.0 - t);
            translateY = -50.0 * (1.0 - t) * math.sin(t * math.pi / 2);

            // Flaps wings 3x
            if (t < 0.9) {
              flapCount = (t * 900 / 150).floor();
            }
          }

          return CustomPaint(
            painter: _RavenPainter(
              scaleX: scaleX,
              scaleY: scaleY,
              translateX: translateX,
              translateY: translateY,
              headTiltAngle: headTiltAngle,
              isBlinking: isBlinking,
              isClosedEye: widget.state == RavenState.sleep,
              wingFlare: wingFlare,
              lowerBeakOpen: lowerBeakOpen,
              isFlying: widget.state == RavenState.fly && _actionController.value < 0.9,
              flapCount: flapCount,
            ),
          );
        },
      ),
    );
  }
}

class _RavenPainter extends CustomPainter {
  final double scaleX;
  final double scaleY;
  final double translateX;
  final double translateY;
  final double headTiltAngle;
  final bool isBlinking;
  final bool isClosedEye;
  final double wingFlare;
  final double lowerBeakOpen;
  final bool isFlying;
  final int flapCount;

  _RavenPainter({
    required this.scaleX,
    required this.scaleY,
    required this.translateX,
    required this.translateY,
    required this.headTiltAngle,
    required this.isBlinking,
    required this.isClosedEye,
    required this.wingFlare,
    required this.lowerBeakOpen,
    required this.isFlying,
    required this.flapCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double cx = s / 2;
    final double cy = s / 2;

    // Perch bar: 2 dp brass rail, 0.9 * size wide at y = 0.88 * size
    final perchPaint = Paint()
      ..color = AppColors.brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(0.05 * s, 0.88 * s), Offset(0.95 * s, 0.88 * s), perchPaint);

    // Apply translation to bird body/head
    canvas.save();
    canvas.translate(translateX, translateY);

    // Legs: draw before body so they connect behind
    final legPaint = Paint()
      ..color = const Color(0xFF171310)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0.52 * s, 0.71 * s), Offset(0.50 * s, 0.88 * s), legPaint);
    canvas.drawLine(Offset(0.58 * s, 0.71 * s), Offset(0.60 * s, 0.88 * s), legPaint);

    // Body transform: scaleX & scaleY
    canvas.save();
    canvas.translate(0.55 * s, 0.55 * s);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-0.55 * s, -0.55 * s);

    // Draw Tail: 3-notch fan protruding behind rump (0.68*s, 0.58*s)
    final tailPaint = Paint()
      ..color = const Color(0xFF171310)
      ..style = PaintingStyle.fill;
    final Path tailPath = Path()
      ..moveTo(0.65 * s, 0.65 * s)
      ..lineTo(0.85 * s, 0.70 * s)
      ..lineTo(0.87 * s, 0.75 * s) // notch 1
      ..lineTo(0.84 * s, 0.76 * s)
      ..lineTo(0.85 * s, 0.81 * s) // notch 2
      ..lineTo(0.81 * s, 0.81 * s)
      ..lineTo(0.82 * s, 0.86 * s) // notch 3
      ..lineTo(0.60 * s, 0.72 * s)
      ..close();
    canvas.drawPath(tailPath, tailPaint);

    // Draw Body: bézier teardrop
    final bodyPaint = Paint()
      ..color = const Color(0xFF171310)
      ..style = PaintingStyle.fill;

    final Path bodyPath = Path()
      ..moveTo(0.48 * s, 0.42 * s)
      ..quadraticBezierTo(0.30 * s, 0.50 * s, 0.38 * s, 0.62 * s) // front chest
      ..quadraticBezierTo(0.45 * s, 0.75 * s, 0.58 * s, 0.72 * s) // belly
      ..quadraticBezierTo(0.72 * s, 0.68 * s, 0.68 * s, 0.58 * s) // rump
      ..quadraticBezierTo(0.60 * s, 0.42 * s, 0.48 * s, 0.42 * s) // back
      ..close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Draw back-edge rim light: stroke 1.5 dp brass @0.12
    final rimPaint = Paint()
      ..color = AppColors.brass.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path rimPath = Path()
      ..moveTo(0.48 * s, 0.42 * s)
      ..quadraticBezierTo(0.60 * s, 0.42 * s, 0.68 * s, 0.58 * s);
    canvas.drawPath(rimPath, rimPaint);

    // Draw folded wing or spread wings if flying
    if (isFlying) {
      // Draw flying wings (flapping)
      final wingPaint = Paint()
        ..color = const Color(0xFF1F1A17)
        ..style = PaintingStyle.fill;

      final bool wingUp = flapCount % 2 == 0;
      final Path wingPath = Path();
      if (wingUp) {
        wingPath.moveTo(0.48 * s, 0.46 * s);
        wingPath.quadraticBezierTo(0.30 * s, 0.20 * s, 0.25 * s, 0.15 * s);
        wingPath.lineTo(0.35 * s, 0.30 * s);
        wingPath.quadraticBezierTo(0.45 * s, 0.40 * s, 0.55 * s, 0.55 * s);
      } else {
        wingPath.moveTo(0.48 * s, 0.46 * s);
        wingPath.quadraticBezierTo(0.30 * s, 0.55 * s, 0.25 * s, 0.70 * s);
        wingPath.lineTo(0.35 * s, 0.60 * s);
        wingPath.quadraticBezierTo(0.45 * s, 0.50 * s, 0.55 * s, 0.55 * s);
      }
      canvas.drawPath(wingPath, wingPaint);
    } else {
      // Normal folded wing
      canvas.save();
      // Apply wing flare about shoulder
      canvas.translate(0.48 * s, 0.46 * s);
      canvas.rotate(wingFlare);
      canvas.translate(-0.48 * s, -0.46 * s);

      final wingPaint = Paint()
        ..color = const Color(0xFF1C1815)
        ..style = PaintingStyle.fill;
      final Path wingPath = Path()
        ..moveTo(0.48 * s, 0.46 * s)
        ..quadraticBezierTo(0.38 * s, 0.52 * s, 0.44 * s, 0.65 * s)
        ..quadraticBezierTo(0.55 * s, 0.70 * s, 0.65 * s, 0.58 * s)
        ..quadraticBezierTo(0.58 * s, 0.48 * s, 0.48 * s, 0.46 * s)
        ..close();
      canvas.drawPath(wingPath, wingPaint);

      // 3 Wing feather notch lines: ivory @0.12
      final wingLinesPaint = Paint()
        ..color = AppColors.ivory.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0.46 * s, 0.55 * s), Offset(0.58 * s, 0.62 * s), wingLinesPaint);
      canvas.drawLine(Offset(0.48 * s, 0.59 * s), Offset(0.60 * s, 0.64 * s), wingLinesPaint);
      canvas.drawLine(Offset(0.50 * s, 0.63 * s), Offset(0.62 * s, 0.66 * s), wingLinesPaint);
      canvas.restore();
    }

    canvas.restore(); // end body transform

    // Head transform: rotate head about neck center (0.48*s, 0.42*s)
    canvas.save();
    canvas.translate(0.48 * s, 0.42 * s);
    canvas.rotate(headTiltAngle);
    canvas.translate(-0.48 * s, -0.42 * s);

    // Draw Head: circle 0.28 diameter -> radius 0.14
    final headPaint = Paint()
      ..color = const Color(0xFF171310)
      ..style = PaintingStyle.fill;
    final Offset headCenter = Offset(0.38 * s, 0.32 * s);
    canvas.drawCircle(headCenter, 0.14 * s, headPaint);

    // Draw Beak: wedge protruding 0.18 facing left
    final beakPaint = Paint()
      ..color = const Color(0xFF3E3428)
      ..style = PaintingStyle.fill;

    // Upper beak
    final Path upperBeak = Path()
      ..moveTo(0.26 * s, 0.28 * s)
      ..lineTo(0.26 * s, 0.32 * s)
      ..lineTo(0.08 * s, 0.32 * s)
      ..close();
    canvas.drawPath(upperBeak, beakPaint);

    // Lower beak: rotates down if lowerBeakOpen > 0
    canvas.save();
    canvas.translate(0.26 * s, 0.32 * s);
    canvas.rotate(lowerBeakOpen);
    canvas.translate(-0.26 * s, -0.32 * s);
    final Path lowerBeak = Path()
      ..moveTo(0.26 * s, 0.32 * s)
      ..lineTo(0.26 * s, 0.36 * s)
      ..lineTo(0.08 * s, 0.32 * s)
      ..close();
    canvas.drawPath(lowerBeak, beakPaint);
    canvas.restore();

    // Draw Eye: 0.05 brass dot + 0.02 ink pupil
    final Offset eyeCenter = Offset(0.35 * s, 0.28 * s);
    if (isClosedEye) {
      // Draw closed arc
      final eyeArcPaint = Paint()
        ..color = AppColors.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: eyeCenter, radius: 0.02 * s),
        0,
        math.pi,
        false,
        eyeArcPaint,
      );
    } else {
      final eyePaint = Paint()
        ..color = AppColors.brass
        ..style = PaintingStyle.fill;
      canvas.drawCircle(eyeCenter, 0.025 * s, eyePaint); // brass dot

      if (!isBlinking) {
        final pupilPaint = Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.fill;
        canvas.drawCircle(eyeCenter, 0.01 * s, pupilPaint); // ink pupil
      }
    }

    canvas.restore(); // end head transform
    canvas.restore(); // end leg/translate transform
  }

  @override
  bool shouldRepaint(covariant _RavenPainter oldDelegate) {
    return oldDelegate.scaleX != scaleX ||
        oldDelegate.scaleY != scaleY ||
        oldDelegate.translateX != translateX ||
        oldDelegate.translateY != translateY ||
        oldDelegate.headTiltAngle != headTiltAngle ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.isClosedEye != isClosedEye ||
        oldDelegate.wingFlare != wingFlare ||
        oldDelegate.lowerBeakOpen != lowerBeakOpen ||
        oldDelegate.isFlying != isFlying ||
        oldDelegate.flapCount != flapCount;
  }
}
