import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class CrimsonShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const CrimsonShadowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.groundRaised, // Deep dark coal background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.8), // Crimson outline
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.35), // Vibrant crimson glow shadow
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ]
      ),
      child: child,
    );
  }
}

class ParchmentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;

  const ParchmentCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Parchment
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.secondary, width: 3), // Gold
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: theme.colorScheme.secondary.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ]
      ),
      child: child,
    );
  }
}
class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double fontSize;
  final Widget? icon;
  final bool loading;
  final bool showTextOnLoading;
  
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.fontSize = 20,
    this.icon,
    this.loading = false,
    this.showTextOnLoading = false,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _loadingController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _flashAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.loading) {
      _startLoadingAnimation();
    }
  }

  void _startLoadingAnimation() {
    final prefersReducedMotion = AppMotion.reduce(context);
    if (!prefersReducedMotion) {
      _loadingController.repeat();
    }
  }

  @override
  void didUpdateWidget(PrimaryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading != oldWidget.loading) {
      if (widget.loading) {
        _startLoadingAnimation();
      } else {
        _loadingController.stop();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.loading) {
      _startLoadingAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Widget _buildLoadingDots(BuildContext context) {
    final bool prefersReducedMotion = AppMotion.reduce(context);
    
    if (prefersReducedMotion) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 6.0),
            child: Opacity(
              opacity: 0.6,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.ivory,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      );
    }

    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        final t = _loadingController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = 2 * math.pi * t - i * 2 * math.pi / 3.0;
            final double value = math.sin(phase);
            final double opacity = 0.25 + 0.75 * math.max(0.0, value);
            final double scale = 0.8 + 0.2 * math.max(0.0, value);
            
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6.0),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.ivory,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.loading;

    return Listener(
      onPointerDown: (event) {
        if (isEnabled) _controller.forward();
      },
      onPointerUp: (event) {
        if (isEnabled) _controller.reverse();
      },
      onPointerCancel: (event) {
        if (isEnabled) _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isEnabled
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.4 * (1.0 - _flashAnimation.value)),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: const Color(0xFFF5EEDB),
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isEnabled
                              ? Color.lerp(
                                  theme.colorScheme.primary.withOpacity(0.5),
                                  theme.colorScheme.secondary,
                                  _flashAnimation.value,
                                )!
                              : Colors.transparent,
                          width: isEnabled ? (1.5 + 1.0 * _flashAnimation.value) : 1.0,
                        ),
                      ),
                      elevation: isEnabled ? 6 : 0,
                      shadowColor: Colors.black.withOpacity(0.5),
                    ),
                    onPressed: widget.loading || widget.onPressed == null
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            widget.onPressed!();
                          },
                    child: widget.loading
                        ? (widget.showTextOnLoading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLoadingDots(context),
                                  const SizedBox(width: 12),
                                  Text(widget.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.fontSize, letterSpacing: 2)),
                                ],
                              )
                            : _buildLoadingDots(context))
                        : (widget.icon == null
                            ? Text(widget.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.fontSize, letterSpacing: 2))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  widget.icon!,
                                  const SizedBox(width: 8),
                                  Text(widget.text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: widget.fontSize, letterSpacing: 2)),
                                ],
                              )),
                  ),
                ),
                if (isEnabled && _flashAnimation.value > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.secondary.withOpacity(0.3 * _flashAnimation.value),
                            width: 3.0 * _flashAnimation.value,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.tertiary, // Emerald
          foregroundColor: const Color(0xFFF5EEDB), // Ivory
          minimumSize: const Size(200, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4), width: 1.5), // Crimson
          ),
          elevation: 6,
        ),
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: Text(
          text, 
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ),
    );
  }
}
