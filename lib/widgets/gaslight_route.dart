import 'package:flutter/material.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';

class GaslightPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  GaslightPageRoute({required this.child, required RouteSettings settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: AppMotion.scene,
          reverseTransitionDuration: AppMotion.standard,
          opaque: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final prefersReducedMotion = AppMotion.reduce(context);
            if (prefersReducedMotion) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            }

            // Flicker TweenSequence
            final flickerOpacity = TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween<double>(begin: 0.0, end: 0.55),
                weight: 35,
              ),
              TweenSequenceItem(
                tween: Tween<double>(begin: 0.55, end: 0.30),
                weight: 10,
              ),
              TweenSequenceItem(
                tween: Tween<double>(begin: 0.30, end: 0.75),
                weight: 15,
              ),
              TweenSequenceItem(
                tween: Tween<double>(begin: 0.75, end: 0.55),
                weight: 10,
              ),
              TweenSequenceItem(
                tween: Tween<double>(begin: 0.55, end: 1.00),
                weight: 30,
              ),
            ]).animate(animation);

            // Settle breath scale transition
            final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            return Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFF090807)),
                ),
                FadeTransition(
                  opacity: flickerOpacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
}

class TitleSettle extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const TitleSettle({
    super.key,
    required this.text,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) {
      return Text(text, style: style);
    }

    final baseStyle = style ?? AppTextStyles.phaseTitle;
    final baseLetterSpacing = baseStyle.letterSpacing ?? 3.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: AppMotion.emphasis,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        // letterSpacing: 9 - 6t (settles at the style's letterSpacing which is normally 3, but let's interpolate from base + 6 down to base)
        return Opacity(
          opacity: t,
          child: Text(
            text,
            style: baseStyle.copyWith(
              letterSpacing: baseLetterSpacing + 6.0 * (1.0 - t),
            ),
          ),
        );
      },
    );
  }
}
