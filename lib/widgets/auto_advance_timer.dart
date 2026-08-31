import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';

class AutoAdvanceTimer extends StatefulWidget {
  final int? endTime;
  final VoidCallback? onTimerExpired;

  const AutoAdvanceTimer({
    super.key,
    required this.endTime,
    this.onTimerExpired,
  });

  @override
  State<AutoAdvanceTimer> createState() => _AutoAdvanceTimerState();
}

class _AutoAdvanceTimerState extends State<AutoAdvanceTimer> with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _secondsRemaining = 0;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updateTime();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.endTime == null) return;

    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _updateTime();
    });
  }

  void _updateTime() {
    if (widget.endTime == null) {
      if (_secondsRemaining != 0) setState(() => _secondsRemaining = 0);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMs = widget.endTime! - now;
    final remainingSecs = (remainingMs / 1000).ceil();

    if (remainingSecs <= 0) {
      if (_secondsRemaining != 0) {
        setState(() => _secondsRemaining = 0);
      }
      _timer?.cancel();
      widget.onTimerExpired?.call();
    } else {
      if (_secondsRemaining != remainingSecs) {
        setState(() => _secondsRemaining = remainingSecs);
      }
    }
  }

  @override
  void didUpdateWidget(AutoAdvanceTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _updateTime();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endTime == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isLowTime = _secondsRemaining <= 10;

    final prefersReducedMotion = AppMotion.reduce(context);
    if (isLowTime && !prefersReducedMotion) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    final timerWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLowTime ? theme.colorScheme.error.withOpacity(0.15) : theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowTime ? theme.colorScheme.error : theme.colorScheme.secondary,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ThematicIcon(
            type: ThematicIconType.timer,
            color: isLowTime ? theme.colorScheme.error : theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '${_secondsRemaining}S',
            style: TextStyle(
              color: isLowTime ? theme.colorScheme.error : theme.colorScheme.secondary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );

    if (isLowTime && !prefersReducedMotion) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _pulseAnimation.value,
            child: child,
          );
        },
        child: timerWidget,
      );
    }

    return timerWidget;
  }
}
