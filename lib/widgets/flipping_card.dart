import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlippingRevealCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isRevealed;

  const FlippingRevealCard({
    super.key,
    required this.front,
    required this.back,
    required this.isRevealed,
  });

  @override
  State<FlippingRevealCard> createState() => _FlippingRevealCardState();
}

class _FlippingRevealCardState extends State<FlippingRevealCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRevealed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FlippingRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed) {
        _controller.forward();
        HapticFeedback.mediumImpact();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = MediaQuery.of(context).accessibleNavigation;
    if (prefersReducedMotion) {
      return widget.isRevealed ? widget.front : widget.back;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isFront = angle >= pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: widget.front,
                )
              : widget.back,
        );
      },
    );
  }
}
