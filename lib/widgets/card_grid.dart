import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';

class VotingAnswer {
  final String authorId;
  final String text;
  final bool isSelfAnswer;
  VotingAnswer({required this.authorId, required this.text, this.isSelfAnswer = false});
}

/// Answers are capped at [kMaxAnswerLength] characters on both the client
/// (`phase2_craft.dart`) and the server (`submitAnswer`), and an option card
/// must render the longest legal answer in full — no ellipsis. The font steps
/// down with length so 100 characters still fit the smallest card: two columns
/// at 375 px wide with `childAspectRatio` 1.1, which gives the text 136.5 x
/// 121.6 logical pixels. At 12 px with height 1.3 that is 7 lines of headroom,
/// and 100 characters need at most 7 even with pathological wrapping.
///
/// `test/vote_option_truncation_test.dart` asserts this mechanically via
/// `RenderParagraph.didExceedMaxLines`; it fails if this table is loosened or
/// the cap is raised without re-tuning.
const int kMaxAnswerLength = 100;

double answerFontSizeFor(int length) {
  if (length <= 40) return 16;
  if (length <= 70) return 14;
  return 12;
}

class CardGrid extends StatelessWidget {
  final List<VotingAnswer> answers;
  final String? selectedAuthorId;
  final String currentPlayerId;
  final String? myOptionIdForThisCard;
  final ValueChanged<String> onSelect;

  const CardGrid({
    super.key,
    required this.answers,
    required this.selectedAuthorId,
    required this.currentPlayerId,
    this.myOptionIdForThisCard,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isPortrait ? 2 : 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: isPortrait ? 1.1 : 1.3,
      ),
      itemCount: answers.length,
      itemBuilder: (context, index) {
        final ans = answers[index];
        final isSelfAnswer = myOptionIdForThisCard != null
            ? ans.authorId == myOptionIdForThisCard
            : ans.isSelfAnswer;
        final isSelected = selectedAuthorId == ans.authorId;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isSelfAnswer ? null : () => onSelect(ans.authorId),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isSelfAnswer 
                    ? theme.colorScheme.surface.withOpacity(0.5) 
                    : theme.colorScheme.surface, // Parchment
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.secondary.withOpacity(0.6),
                  width: isSelected ? 3.0 : 1.5,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    )
                ],
              ),
              child: Stack(
                children: [
                  // Faint wax-seal watermark in background
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: 0.05,
                        child: const WaxSealBadge(
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                  if (isSelfAnswer)
                    Positioned(
                      top: 8,
                      left: -20,
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Container(
                          width: 80,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: AppColors.oxblood.withOpacity(0.85),
                          child: const Center(
                            child: Text(
                              'SEALED',
                              style: TextStyle(
                                color: AppColors.ivory,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Card Content
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                ans.text,
                                style: TextStyle(
                                  color: isSelfAnswer 
                                      ? theme.colorScheme.onSurface.withOpacity(0.4) 
                                      : theme.colorScheme.onSurface,
                                  fontSize: answerFontSizeFor(ans.text.length),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lora',
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 7,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (isSelfAnswer) ...[
                            const SizedBox(height: 4),
                            Text(
                              '(Your Forgery)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),

                  // Red Wax Seal Stamp when selected
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 1.6, end: 1.0),
                        duration: AppMotion.fast,
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: const WaxSealBadge(size: 34),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
