import 'package:flutter/material.dart';
import 'dart:math';

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final Function(bool isRight) onSwiped;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwiped,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _angle = 0;
  Size _screenSize = Size.zero;
  
  late AnimationController _animationController;
  Animation<Offset>? _animation;
  Animation<double>? _angleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animationController.addListener(() {
      if (_animation != null && _angleAnimation != null) {
        setState(() {
          _position = _animation!.value;
          _angle = _angleAnimation!.value;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _angle = 45 * (_position.dx / _screenSize.width) * (pi / 180);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });

    final threshold = _screenSize.width * 0.3;

    if (_position.dx > threshold) {
      _animateOffScreen(true);
    } else if (_position.dx < -threshold) {
      _animateOffScreen(false);
    } else {
      _animateBackToCenter();
    }
  }

  void _animateOffScreen(bool isRight) {
    final endPosition = Offset(isRight ? _screenSize.width * 1.5 : -_screenSize.width * 1.5, _position.dy);
    _animation = Tween<Offset>(begin: _position, end: endPosition).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _angleAnimation = Tween<double>(begin: _angle, end: _angle).animate(_animationController);
    
    _animationController.forward(from: 0).then((_) {
      widget.onSwiped(isRight);
    });
  }

  void _animateBackToCenter() {
    _animation = Tween<Offset>(begin: _position, end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
    _angleAnimation = Tween<double>(begin: _angle, end: 0).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isRight = _position.dx > 0;
    final opacity = min(1.0, (_position.dx.abs() / (_screenSize.width * 0.3)));
    
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _position,
        child: Transform.rotate(
          angle: _angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(4, 4),
                    )
                  ]
                ),
                child: widget.child,
              ),
              if (_isDragging && opacity > 0.1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isRight ? Colors.green.withOpacity(opacity * 0.2) : Colors.red.withOpacity(opacity * 0.2),
                      ),
                      child: Center(
                        child: Transform.rotate(
                          angle: isRight ? -0.2 : 0.2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: isRight ? Colors.green : Colors.red, width: 4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRight ? 'OPTION 1' : 'OPTION 2',
                              style: TextStyle(
                                color: isRight ? Colors.green : Colors.red,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
