import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_motion.dart';

enum RavenState {
  sleep,
  idle,
  hop,
  ruffle,
  fly,
  alert,
  peck,
  preen,
  startle,
  bow,
  caw,
  flap,
}

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

    if (AppMotion.reduce(context)) {
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
    } else if (state == RavenState.alert) {
      _actionController.duration = const Duration(milliseconds: 300);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.peck) {
      _actionController.duration = const Duration(milliseconds: 180);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.preen) {
      _actionController.duration = const Duration(milliseconds: 600);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.startle) {
      _actionController.duration = const Duration(milliseconds: 300);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.bow) {
      _actionController.duration = const Duration(milliseconds: 600);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.caw) {
      _actionController.duration = const Duration(milliseconds: 300);
      _actionController.forward(from: 0.0);
    } else if (state == RavenState.flap) {
      _actionController.duration = const Duration(milliseconds: 660);
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
          bool useWingUp = false;
          bool useBeakOpen = false;

          if (prefersReducedMotion) {
            final Widget eye = (widget.state == RavenState.sleep)
                ? Image.asset('assets/images/raven/eye_closed.png', fit: BoxFit.contain)
                : Image.asset('assets/images/raven/eye_open.png', fit: BoxFit.contain);
            return Stack(
              children: [
                Image.asset('assets/images/raven/body.png', fit: BoxFit.contain),
                Image.asset('assets/images/raven/wing.png', fit: BoxFit.contain),
                eye,
              ],
            );
          }

          final double actionT = _actionController.value;

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
            translateY = -0.12 * widget.size * math.sin(actionT * math.pi);
            wingFlare = 8.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
          } else if (widget.state == RavenState.ruffle) {
            if (actionT < 0.5) {
              final double local = actionT / 0.5;
              scaleX = 1.0 + 0.15 * local;
            } else {
              final double local = (actionT - 0.5) / 0.5;
              scaleX = 1.15 - 0.20 * local;
            }
          } else if (widget.state == RavenState.fly) {
            translateX = -widget.size * (1.0 - actionT);
            translateY = -50.0 * (1.0 - actionT) * math.sin(actionT * math.pi / 2);
            if (actionT < 0.9) {
              flapCount = (actionT * 900 / 150).floor();
            }
          } else if (widget.state == RavenState.alert) {
            headTiltAngle = -10.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
          } else if (widget.state == RavenState.peck) {
            headTiltAngle = 18.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
          } else if (widget.state == RavenState.preen) {
            headTiltAngle = -8.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
            wingFlare = -25.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
          } else if (widget.state == RavenState.startle) {
            final double pop = math.sin(actionT * math.pi);
            scaleX = 1.0 + 0.08 * pop;
            scaleY = 1.0 + 0.08 * pop;
            translateY = -0.10 * widget.size * pop;
            wingFlare = 14.0 * math.pi / 180.0 * pop;
          } else if (widget.state == RavenState.bow) {
            headTiltAngle = 22.0 * math.pi / 180.0 * math.sin(actionT * math.pi);
          } else if (widget.state == RavenState.caw) {
            final double pop = math.sin(actionT * math.pi);
            scaleX = 1.0 + 0.04 * pop;
            scaleY = 1.0 + 0.04 * pop;
            headTiltAngle = -6.0 * math.pi / 180.0 * pop;
            useBeakOpen = actionT > 0.1 && actionT < 0.9;
          } else if (widget.state == RavenState.flap) {
            final double pop = math.sin(actionT * math.pi);
            translateY = -0.15 * widget.size * pop;
            useWingUp = ((actionT * 660 / 110).floor() % 2 == 1);
          }

          final bool isFlying = widget.state == RavenState.fly && _actionController.value < 0.9;
          double wingRotation = wingFlare;
          if (isFlying) {
            wingRotation += (flapCount % 2 == 0 ? -0.35 : 0.35);
          }

          final Widget eyeWidget = (isBlinking || widget.state == RavenState.sleep)
              ? Image.asset('assets/images/raven/eye_closed.png', fit: BoxFit.contain)
              : Image.asset('assets/images/raven/eye_open.png', fit: BoxFit.contain);

          final String wingAsset = useWingUp ? 'assets/images/raven/wing_up.png' : 'assets/images/raven/wing.png';

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
                    if (useBeakOpen)
                      Image.asset('assets/images/raven/beak_open.png', fit: BoxFit.contain),
                    Transform.rotate(
                      angle: wingRotation,
                      // Wing shoulder joint pivot on shared 1024x1024 canvas
                      alignment: const Alignment(-0.25, 0.10),
                      child: Image.asset(wingAsset, fit: BoxFit.contain),
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
