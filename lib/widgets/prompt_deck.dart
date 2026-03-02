import 'package:flutter/material.dart';
import 'dart:math';

class PromptDeck extends StatefulWidget {
  final int submittedCount;
  final int totalCount;

  const PromptDeck({super.key, required this.submittedCount, required this.totalCount});

  @override
  State<PromptDeck> createState() => _PromptDeckState();
}

class _PromptDeckState extends State<PromptDeck> with TickerProviderStateMixin {
  int _displayedCards = 0;
  final List<Widget> _deckStack = [];
  AnimationController? _slideController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _displayedCards = widget.submittedCount;
    _buildInitialDeck();
  }

  void _buildInitialDeck() {
    for (int i = 0; i < _displayedCards; i++) {
      _deckStack.add(_buildStaticCard(i));
    }
  }

  @override
  void didUpdateWidget(PromptDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submittedCount > oldWidget.submittedCount) {
      _animateNewCard();
    } else if (widget.submittedCount < oldWidget.submittedCount) {
      // Handle edge case of reset
      setState(() {
        _displayedCards = widget.submittedCount;
        _deckStack.clear();
        _buildInitialDeck();
      });
    }
  }

  void _animateNewCard() {
    final int newIndex = _displayedCards;
    
    _slideController?.dispose();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    
    // Animate from top right off screen
    _slideAnimation = Tween<Offset>(begin: const Offset(1.5, -2.0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController!, curve: Curves.easeOutCubic));

    _deckStack.add(
      SlideTransition(
        position: _slideAnimation!,
        child: _buildStaticCard(newIndex),
      )
    );

    setState(() {}); // Trigger rebuild to show the animating card

    _slideController!.forward().then((_) {
      if (mounted) {
        setState(() {
          _displayedCards++;
          _deckStack.removeLast();
          _deckStack.add(_buildStaticCard(newIndex)); // Replace with static card
        });
      }
    });
  }

  Widget _buildStaticCard(int index) {
    final random = Random(index); // Stable randomness per card
    final angle = (random.nextDouble() - 0.5) * 0.2; // Slight rotation
    final offsetX = (random.nextDouble() - 0.5) * 10;
    final offsetY = index * -2.0;

    return Transform.translate(
      offset: Offset(offsetX, offsetY),
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(2, 2),
              )
            ],
          ),
          child: index == widget.totalCount - 1 && _displayedCards >= widget.totalCount - 1
            ? const Center(child: CircularProgressIndicator()) 
            : _buildCardBackPattern(),
        ),
      ),
    );
  }

  Widget _buildCardBackPattern() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Icon(Icons.diamond, color: Colors.white.withOpacity(0.5), size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base shadow placeholder
          Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
               color: Colors.black12,
               borderRadius: BorderRadius.circular(8),
            ),
          ),
          ..._deckStack,
          
          // Count overlay
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.submittedCount} / ${widget.totalCount}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _slideController?.dispose();
    super.dispose();
  }
}
