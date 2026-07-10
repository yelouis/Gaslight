import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AtmosphereBackground extends StatelessWidget {
  final Widget child;

  const AtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6), // Light pool from top-center
          radius: 1.5,
          colors: [
            Color(0xFF2E2218), // Warm lamplight glow
            AppColors.ground, // Falls off to warm soot ground
            Color(0xFF090807), // Dark vignette edges
          ],
          stops: [0.0, 0.7, 1.0],
        ),
      ),
      child: child,
    );
  }
}
