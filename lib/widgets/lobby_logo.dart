import 'package:flutter/material.dart';

class AnimatedLobbyLogo extends StatefulWidget {
  const AnimatedLobbyLogo({super.key});

  @override
  State<AnimatedLobbyLogo> createState() => _AnimatedLobbyLogoState();
}

class _AnimatedLobbyLogoState extends State<AnimatedLobbyLogo> with SingleTickerProviderStateMixin {
  late AnimationController _flickerController;

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _flickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary; // Burgundy
    final secondaryColor = theme.colorScheme.secondary; // Gold

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // The Mystical Card Backing
            Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: secondaryColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                  )
                ]
              ),
              child: Stack(
                children: [
                   Positioned(top: 8, left: 8, child: Text('A', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold))),
                   Positioned(bottom: 8, right: 8, child: RotatedBox(quarterTurns: 2, child: Text('A', style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold)))),
                   // The Gaslight Mascot
                   Center(
                     child: AnimatedBuilder(
                       animation: _flickerController,
                       builder: (context, child) {
                         return Container(
                           width: 80,
                           height: 100,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             boxShadow: [
                               BoxShadow(
                                 color: primaryColor.withOpacity(0.5 * _flickerController.value),
                                 blurRadius: 20 * _flickerController.value,
                                 spreadRadius: 5 * _flickerController.value,
                               )
                             ]
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(12),
                             child: Image.asset(
                               'assets/images/gaslight_mascot.png',
                               fit: BoxFit.cover,
                             ),
                           ),
                         );
                       },
                     ),
                   )
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // GASLIGHT Text
        Text(
          'GASLIGHT',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            color: secondaryColor,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              Shadow(
                color: primaryColor.withOpacity(0.6),
                blurRadius: 20,
              )
            ]
          ),
        ),
      ],
    );
  }
}
