import 'package:flutter/material.dart';

class AnimatedLobbyBackground extends StatefulWidget {
  final Widget child;

  const AnimatedLobbyBackground({super.key, required this.child});

  @override
  State<AnimatedLobbyBackground> createState() => _AnimatedLobbyBackgroundState();
}

class _AnimatedLobbyBackgroundState extends State<AnimatedLobbyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.6), // Light from above
              radius: 1.8 * _breathingController.value, // Breathing spotlight
              colors: const [
                Color(0xFF6A2A18), // Warm ember/lantern glow
                Color(0xFF141A17), // Deep shadowy tavern/forest
                Color(0xFF070A08), // Near black edges
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/lobby_background.gif',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.5), // Darken slightly so text remains readable
            colorBlendMode: BlendMode.darken,
          ),
          Positioned.fill(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
