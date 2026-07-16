import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_icons.dart';
import '../theme/candle_paths.dart';
import '../models/player_state.dart';
import '../widgets/player_avatar.dart';

class CandleFlameIndicator extends StatefulWidget {
  const CandleFlameIndicator({super.key});

  @override
  State<CandleFlameIndicator> createState() => _CandleFlameIndicatorState();
}

class _CandleFlameIndicatorState extends State<CandleFlameIndicator> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _gutterController;
  late final Animation<double> _gutterAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _gutterController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _gutterAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.85, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_gutterController);
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
        _controller.repeat(reverse: true);
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 3600), (timer) {
          if (mounted && !AppMotion.reduce(context)) {
            _gutterController.forward(from: 0.0);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _gutterController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = AppMotion.reduce(context);

    return SizedBox(
      width: 48,
      height: 64,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _gutterAnimation]),
        builder: (context, child) {
          return CustomPaint(
            painter: _CandleFlamePainter(
              animationValue: prefersReducedMotion ? 0.5 : _controller.value,
              gutterScale: prefersReducedMotion ? 1.0 : _gutterAnimation.value,
              isStatic: prefersReducedMotion,
            ),
          );
        },
      ),
    );
  }
}

class _CandleFlamePainter extends CustomPainter {
  final double animationValue;
  final double gutterScale;
  final bool isStatic;

  _CandleFlamePainter({
    required this.animationValue,
    required this.gutterScale,
    required this.isStatic,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Wick: bottom center
    final wickPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.fill;
    
    final Rect wickRect = Rect.fromLTWH(w / 2 - 1, h - 8, 2, 8);
    canvas.drawRRect(RRect.fromRectAndRadius(wickRect, const Radius.circular(1)), wickPaint);

    final Offset wickTop = Offset(w / 2, h - 8);

    // Glow: radial circle behind flame, radius 26dp, brass @ 0.15
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.brass.withOpacity(0.15),
          AppColors.brass.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: wickTop, radius: 26))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(wickTop, 26, glowPaint);

    // Outer flame path base height: static = 31dp, animated = 28 to 34 dp
    double flameHeight = isStatic ? 31.0 : (28.0 + (34.0 - 28.0) * animationValue);
    flameHeight *= gutterScale;

    // Sway: tip x offset by sin(controllerValue * 2pi) * 2.5 dp
    double swayX = isStatic ? 0.0 : math.sin(animationValue * 2 * math.pi) * 2.5;

    final double baseWidth = 14.0;
    final Offset flameTip = Offset(wickTop.dx + swayX, wickTop.dy - flameHeight);

    // Outer flame: brass @ 0.85
    final outerPaint = Paint()
      ..color = AppColors.brass.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final Path outerPath = CandlePaths.flamePath(
      wickTop: wickTop,
      baseWidth: baseWidth,
      flameHeight: flameHeight,
      swayX: swayX,
    );
    canvas.drawPath(outerPath, outerPaint);

    // Core flame: anchor to wick, 55% scale, ivory @ 0.9
    final corePaint = Paint()
      ..color = AppColors.ivory.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final double coreHeight = flameHeight * 0.55;
    final double coreWidth = baseWidth * 0.55;

    final Path corePath = CandlePaths.flamePath(
      wickTop: wickTop,
      baseWidth: coreWidth,
      flameHeight: coreHeight,
      swayX: swayX * 0.55,
    );
    canvas.drawPath(corePath, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CandleFlamePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.gutterScale != gutterScale ||
        oldDelegate.isStatic != isStatic;
  }
}

class WaitingOnRow extends StatefulWidget {
  final List<PlayerState> players;
  final Map<String, bool> readyMap;

  const WaitingOnRow({
    super.key,
    required this.players,
    required this.readyMap,
  });

  @override
  State<WaitingOnRow> createState() => _WaitingOnRowState();
}

class _WaitingOnRowState extends State<WaitingOnRow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefersReducedMotion = AppMotion.reduce(context);
    if (prefersReducedMotion) {
      _pulseController.stop();
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = AppMotion.reduce(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: widget.players.map((player) {
        final bool isReady = widget.readyMap[player.id] ?? false;

        Widget avatarWidget = PlayerAvatar(player: player, size: 44, showName: false);

        if (isReady) {
          avatarWidget = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.verdigris,
                    width: 1.5,
                  ),
                ),
                child: avatarWidget,
              ),
              const Positioned(
                right: -2,
                bottom: -2,
                child: WaxSealBadge(size: 16),
              ),
            ],
          );
        } else {
          avatarWidget = Opacity(
            opacity: 0.45,
            child: prefersReducedMotion
                ? avatarWidget
                : ScaleTransition(
                    scale: _pulseAnimation,
                    child: avatarWidget,
                  ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatarWidget,
            const SizedBox(height: 4),
            Text(
              player.name,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Lora',
                color: isReady ? AppColors.ivory : AppColors.ivory.withOpacity(0.5),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
