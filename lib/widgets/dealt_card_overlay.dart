import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_icons.dart';
import '../services/audio_service.dart';
import '../models/game_state.dart';

class DealtCardOverlay extends StatefulWidget {
  final GamePhase phase;
  final String readerName;
  final String promptText;
  final VoidCallback onDismiss;

  const DealtCardOverlay({
    super.key,
    required this.phase,
    required this.readerName,
    required this.promptText,
    required this.onDismiss,
  });

  @override
  State<DealtCardOverlay> createState() => _DealtCardOverlayState();
}

class _DealtCardOverlayState extends State<DealtCardOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _entryAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    AudioService.instance.playVote(); // stamp thunk sound
    if (AppMotion.reduce(context)) {
      widget.onDismiss();
    } else {
      setState(() {
        _isDismissing = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool prefersReducedMotion = AppMotion.reduce(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final isTruth = widget.phase == GamePhase.truth;

    Widget cardContent = Container(
      width: 300,
      height: 420,
      decoration: BoxDecoration(
        color: AppColors.parchment,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brass, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Faint wax seal watermark
          const Positioned.fill(
            child: Center(
              child: Opacity(
                opacity: 0.05,
                child: WaxSealBadge(size: 150),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              children: [
                // Gold crown header
                const Center(
                  child: ThematicIcon(
                    type: ThematicIconType.host,
                    color: AppColors.brass,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isTruth ? 'THE RECORD OF TRUTH' : 'DECK OF FORGERIES',
                  style: const TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: AppColors.brass,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.brass, thickness: 1),
                const SizedBox(height: 16),
                // Card Prompt Box
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isTruth
                              ? 'You must pen the absolute truth. Reveal a genuine secret from your past.'
                              : 'You have been dealt the ledger of ${widget.readerName.toUpperCase()}.\nCraft a convincing counterfeit to deceive the parlor.',
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.ink,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.promptText,
                          style: const TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.oxblood,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.brass, thickness: 1),
                const SizedBox(height: 16),
                // Dismiss Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.oxblood,
                      foregroundColor: AppColors.ivory,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    onPressed: _handleDismiss,
                    child: Text(
                      isTruth ? 'DISMISS' : 'INSPECT',
                      style: const TextStyle(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Apply dismissal scale-out animation
    Widget animCard = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: _isDismissing ? 0.0 : 1.0),
      duration: _isDismissing ? AppMotion.fast : Duration.zero,
      onEnd: () {
        if (_isDismissing) {
          widget.onDismiss();
        }
      },
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: cardContent,
    );

    // Apply entrance translation & rotation animation
    if (!prefersReducedMotion) {
      animCard = AnimatedBuilder(
        animation: _entryAnimation,
        builder: (context, child) {
          final double translationY = (1.0 - _entryAnimation.value) * (screenHeight + 200);
          final double rotationAngle = (1.0 - _entryAnimation.value) * -math.pi;
          return Transform(
            transform: Matrix4.identity()
              ..translate(0.0, translationY)
              ..rotateZ(rotationAngle),
            alignment: Alignment.center,
            child: child,
          );
        },
        child: animCard,
      );
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Blocks taps to underlying widgets
        child: Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: animCard,
          ),
        ),
      ),
    );
  }
}
