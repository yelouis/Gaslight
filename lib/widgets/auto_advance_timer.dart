import 'package:flutter/material.dart';
import 'dart:async';

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

class _AutoAdvanceTimerState extends State<AutoAdvanceTimer> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endTime == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isLowTime = _secondsRemaining <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLowTime ? theme.colorScheme.error.withOpacity(0.1) : theme.colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLowTime ? theme.colorScheme.error : theme.colorScheme.secondary,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer,
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
  }
}
