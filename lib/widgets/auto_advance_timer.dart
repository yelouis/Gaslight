import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_icons.dart';

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
      duration: const Duration(milliseconds: 500),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startTimer();
  }

  @override
  void didUpdateWidget(AutoAdvanceTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTime != widget.endTime) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.endTime == null) return;

    _updateSeconds();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateSeconds();
        });
      }
    });
  }

  void _updateSeconds() {
    if (widget.endTime == null) {
      _secondsRemaining = 0;
      return;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = ((widget.endTime! - now) / 1000).ceil();
    
    if (_secondsRemaining <= 0) {
      _secondsRemaining = 0;
      _timer?.cancel();
      widget.onTimerExpired?.call();
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

    if (isLowTime) {
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

    if (isLowTime) {
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
