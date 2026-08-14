import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_motion.dart';
import '../theme/app_icons.dart';
import '../utils/prompt_decks.dart';
import '../services/game_service.dart';
import '../models/player_state.dart';

class DeckCarousel extends StatefulWidget {
  final String selectedDeckId;
  final List<String> availableDecks;
  final ValueChanged<String> onDeckSelected;
  final bool isHost;
  final GameService gameService;

  const DeckCarousel({
    super.key,
    required this.selectedDeckId,
    required this.availableDecks,
    required this.onDeckSelected,
    required this.isHost,
    required this.gameService,
  });

  @override
  State<DeckCarousel> createState() => _DeckCarouselState();
}

class _DeckCarouselState extends State<DeckCarousel> with TickerProviderStateMixin {
  late final PageController _pageController;
  double _currentPage = 0.0;
  Timer? _debounceTimer;
  DateTime? _lastSwipeTime;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.availableDecks.indexOf(widget.selectedDeckId);
    _pageController = PageController(
      viewportFraction: 0.48,
      initialPage: initialIndex >= 0 ? initialIndex : 0,
    );
    _currentPage = (initialIndex >= 0 ? initialIndex : 0).toDouble();

    _pageController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = _pageController.page ?? 0.0;
        });
      }
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.96).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(DeckCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDeckId != oldWidget.selectedDeckId) {
      final targetIndex = widget.availableDecks.indexOf(widget.selectedDeckId);
      if (targetIndex >= 0 && _pageController.hasClients) {
        final now = DateTime.now();
        final recentSwipe = _lastSwipeTime != null &&
            now.difference(_lastSwipeTime!) < const Duration(seconds: 3);
        if (!recentSwipe) {
          if (AppMotion.reduce(context)) {
            _pageController.jumpToPage(targetIndex);
          } else {
            _pageController.animateToPage(
              targetIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      }
    }
  }

  void _onPageChanged(int index) {
    _lastSwipeTime = DateTime.now();
    if (!widget.isHost) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        final newDeckId = widget.availableDecks[index];
        widget.onDeckSelected(newDeckId);
        _playStampPulse();
      }
    });
  }

  void _playStampPulse() {
    if (!widget.isHost) return;
    if (!AppMotion.reduce(context)) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final carouselWidget = SizedBox(
      height: 130,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.availableDecks.length,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final deckId = widget.availableDecks[index];
          final double delta = (index - _currentPage).abs();
          final double scale = (1.0 - 0.1 * delta).clamp(0.9, 1.0);
          final double opacity = (1.0 - 0.4 * delta).clamp(0.6, 1.0);

          final bool isSelected = deckId == widget.selectedDeckId;

          Widget card = _FolderCard(
            deckId: deckId,
            gameService: widget.gameService,
          );

          if (isSelected) {
            if (widget.isHost) {
              card = ScaleTransition(
                scale: _pulseAnimation,
                child: card,
              );
            } else {
              card = Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  card,
                  Positioned(
                    top: 14,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.oxblood,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.brass, width: 1),
                      ),
                      child: const Text(
                        'CHOSEN',
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.parchment,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          }

          return GestureDetector(
            key: ValueKey('deck_$deckId'),
            onTap: () {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Center(child: card),
              ),
            ),
          );
        },
      ),
    );

    if (!widget.isHost) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'THE CHOSEN FILE',
            style: AppTextStyles.sectionLabel,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          carouselWidget,
        ],
      );
    }

    return carouselWidget;
  }
}

class _FolderCard extends StatelessWidget {
  final String deckId;
  final GameService gameService;

  const _FolderCard({
    required this.deckId,
    required this.gameService,
  });

  @override
  Widget build(BuildContext context) {
    if (deckId == 'custom') {
      // Compute live prompts and contributors count
      int totalContributions = 0;
      int contributorsCount = 0;
      for (var p in gameService.players) {
        if (p.role != PlayerRole.spectator && p.customPrompts.isNotEmpty) {
          totalContributions += p.customPrompts.length;
          contributorsCount++;
        }
      }

      return SizedBox(
        width: 150,
        height: 110,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Tab top-left
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 30,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.parchment,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ),
            // Body
            Positioned(
              left: 0,
              top: 10,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.parchment,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _FolderStringTiePainter(),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ThematicIcon(
                              type: ThematicIconType.writing,
                              size: 30,
                              color: AppColors.ink,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'CUSTOM DECK',
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalContributions prompts from $contributorsCount players',
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 8,
                                fontStyle: FontStyle.italic,
                                color: AppColors.ink.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final name = PromptDecks.getDeckName(deckId);
    final size = PromptDecks.getDeckSize(deckId);
    final prompts = PromptDecks.drawPrompts(deckId, size);
    final firstPrompt = prompts.isNotEmpty ? prompts.first : '';

    // Determine seal properties
    String? sealLabel;
    Color sealColor = AppColors.oxblood;
    bool hasSeal = false;

    if (deckId == 'rated_r_nsfw') {
      sealLabel = 'R';
      sealColor = AppColors.oxblood;
      hasSeal = true;
    } else if (deckId == 'cah_dark_humor') {
      sealLabel = 'X';
      sealColor = const Color(0xFF2A2226);
      hasSeal = true;
    } else if (deckId == 'the_daily_grind' ||
        deckId == 'deep_fears_and_phobias' ||
        deckId == 'unhinged_quirks' ||
        deckId == 'romantic_disasters') {
      sealLabel = 'PG';
      sealColor = const Color(0xFF7A6A3A);
      hasSeal = true;
    }

    return SizedBox(
      width: 150,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tab top-left
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 30,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
          // Body
          Positioned(
            left: 0,
            top: 10,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _FolderStringTiePainter(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    children: [
                      // Deck Name
                      Positioned(
                        left: 2,
                        top: 4,
                        right: 25,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // First Prompt Peek Strip
                      Positioned(
                        left: 2,
                        bottom: 2,
                        right: 32,
                        child: Text(
                          firstPrompt,
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                            color: AppColors.ink.withOpacity(0.6),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Wax Seal
                      if (hasSeal)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: WaxSealBadge(
                            size: 26,
                            color: sealColor,
                            label: sealLabel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderStringTiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final buttonCenter = Offset(size.width - 16, size.height / 2);

    // Draw two crossing lines to the button
    canvas.drawLine(Offset(8, size.height * 0.25), buttonCenter, paint);
    canvas.drawLine(Offset(8, size.height * 0.75), buttonCenter, paint);

    // Draw button circle
    final buttonPaint = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.fill;
    canvas.drawCircle(buttonCenter, 4.0, buttonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
