import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedThinkingBackground extends StatefulWidget {
  final Widget child;
  const AnimatedThinkingBackground({super.key, required this.child});

  @override
  State<AnimatedThinkingBackground> createState() => _AnimatedThinkingBackgroundState();
}

class _AnimatedThinkingBackgroundState extends State<AnimatedThinkingBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final List<_ThoughtParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    
    // Initialize particles
    for (int i = 0; i < 15; i++) {
      _particles.add(_generateParticle(initial: true));
    }
  }

  _ThoughtParticle _generateParticle({bool initial = false}) {
    return _ThoughtParticle(
      x: _random.nextDouble(),
      y: initial ? _random.nextDouble() : 1.1, // Start below screen if not initial
      speed: 0.1 + _random.nextDouble() * 0.2, // Speed of floating up
      size: 24 + _random.nextDouble() * 40,
      opacity: 0.1 + _random.nextDouble() * 0.4, // More visible glowing embers
      symbol: _random.nextBool() ? '✦' : '✧', // Magical sparks
      wobbleSpeed: 2.0 + _random.nextDouble() * 5.0,
      wobbleAmount: 10.0 + _random.nextDouble() * 20.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark gradient
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.6),
              radius: 1.5,
              colors: [
                Color(0xFF6A2A18),
                Color(0xFF141A17),
                Color(0xFF070A08),
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Update particles
            for (int i = 0; i < _particles.length; i++) {
              // Time delta approximation (assume 60fps)
              _particles[i].y -= _particles[i].speed * 0.016;
              // Reset at top
              if (_particles[i].y < -0.1) {
                _particles[i] = _generateParticle();
              }
            }
            
            return CustomPaint(
              painter: _ThinkingPainter(_particles),
              child: Container(),
            );
          },
        ),
        
        // Placed above the particles
        widget.child,
      ],
    );
  }
}

class _ThoughtParticle {
  double x;
  double y;
  double speed;
  double size;
  double opacity;
  String symbol;
  double wobbleSpeed;
  double wobbleAmount;

  _ThoughtParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.symbol,
    required this.wobbleSpeed,
    required this.wobbleAmount,
  });
}

class _ThinkingPainter extends CustomPainter {
  final List<_ThoughtParticle> particles;
  
  _ThinkingPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      // Fade out smoothly at the top 20% of the screen
      double currentOpacity = p.opacity;
      if (p.y < 0.2) {
        currentOpacity = p.opacity * (p.y / 0.2); 
      }
      if (currentOpacity < 0) currentOpacity = 0;

      final textStyle = TextStyle(
        color: Colors.amber.withOpacity(currentOpacity), // Amber glowing embers
        fontSize: p.size,
        shadows: [
          Shadow(color: Colors.orange.withOpacity(currentOpacity), blurRadius: p.size / 2)
        ],
      );
      
      final textSpan = TextSpan(text: p.symbol, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      // Wobble effect based on y position (simulate drifting side to side)
      final xOffset = sin(p.y * p.wobbleSpeed) * p.wobbleAmount;
      
      textPainter.paint(
        canvas,
        Offset((p.x * size.width) - (textPainter.width / 2) + xOffset, p.y * size.height),
      );
    }
  }

  @override
  bool shouldRepaint(_ThinkingPainter oldDelegate) => true; // Constantly animating
}
