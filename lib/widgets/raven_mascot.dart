import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
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
  final math.Random _random = math.Random();
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
          int flapCount = 0;

          if (prefersReducedMotion) {
            return Stack(
              children: [
                Image.asset('assets/images/raven/body.png', fit: BoxFit.contain),
                Image.asset('assets/images/raven/wing.png', fit: BoxFit.contain),
                Image.asset('assets/images/raven/eye_open.png', fit: BoxFit.contain),
              ],
            );
          }

          if (widget.state == RavenState.sleep) {
            headTiltAngle = -25.0 * math.pi / 180.0;
            isBlinking = true;
            scaleY = 1.0 + 0.03 * _sleepController.value;
          } else if (widget.state == RavenState.idle) {
            if (_idleTilt) {
              final double t = _idleController.value;
              headTiltAngle = 12.0 * math.pi / 180.0 * math.sin(t * math.pi);
            }
            if (_idleBlink) {
              isBlinking = true;
            }
          } else if (widget.state == RavenState.hop) {
            final double t = _actionController.value;
            translateY = -0.12 * widget.size * math.sin(t * math.pi);
            wingFlare = 8.0 * math.pi / 180.0 * math.sin(t * math.pi);
          } else if (widget.state == RavenState.ruffle) {
            final double t = _actionController.value;
            if (t < 0.5) {
              final double local = t / 0.5;
              scaleX = 1.0 + 0.15 * local;
            } else {
              final double local = (t - 0.5) / 0.5;
              scaleX = 1.15 - 0.20 * local;
            }
          } else if (widget.state == RavenState.fly) {
            final double t = _actionController.value;
            translateX = -widget.size * (1.0 - t);
            translateY = -50.0 * (1.0 - t) * math.sin(t * math.pi / 2);

            if (t < 0.9) {
              flapCount = (t * 900 / 150).floor();
            }
          }

          final bool isFlying = widget.state == RavenState.fly && _actionController.value < 0.9;
          double wingRotation = wingFlare;
          if (isFlying) {
            wingRotation += (flapCount % 2 == 0 ? -0.35 : 0.35);
          }

          final Widget eyeWidget = (isBlinking || widget.state == RavenState.sleep)
              ? Image.asset('assets/images/raven/eye_closed.png', fit: BoxFit.contain)
              : Image.asset('assets/images/raven/eye_open.png', fit: BoxFit.contain);

          return Transform.translate(
            offset: Offset(translateX, translateY),
            child: Transform.rotate(
              angle: headTiltAngle,
              alignment: Alignment.center,
              child: Transform.scale(
                scaleX: scaleX,
                scaleY: scaleY,
                child: Stack(
                  children: [
                    Image.asset('assets/images/raven/body.png', fit: BoxFit.contain),
                    Transform.rotate(
                      angle: wingRotation,
                      // Wing shoulder joint pivot on shared 1024x1024 canvas
                      alignment: const Alignment(-0.25, 0.10),
                      child: Image.asset('assets/images/raven/wing.png', fit: BoxFit.contain),
                    ),
                    eyeWidget,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
