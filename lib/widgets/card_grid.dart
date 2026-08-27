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
/// must render the longest legal answer in full — no ellipsis. In portrait,
/// answers render one option per row, bounded between 72 and 132 logical
/// pixels high so [AutoSizedAnswerText] scales cleanly without truncation.
///
/// `test/vote_option_truncation_test.dart` asserts this mechanically via
/// `RenderParagraph.didExceedMaxLines` at 320, 375, and 430 pt viewports.
const int kMaxAnswerLength = 100;

class AutoSizedAnswerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double minFontSize;
  final double maxFontSize;
  final TextAlign textAlign;
  final int maxLines;

  const AutoSizedAnswerText({
    super.key,
    required this.text,
    required this.style,
    this.minFontSize = 9.5,
    this.maxFontSize = 16.0,
    this.textAlign = TextAlign.center,
    this.maxLines = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        double optimalFontSize = minFontSize;
        for (double size = maxFontSize; size >= minFontSize; size -= 0.5) {
          final testStyle = style.copyWith(fontSize: size);
          final textPainter = TextPainter(
            text: TextSpan(text: text, style: testStyle),
            textAlign: textAlign,
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: maxLines,
          );
          textPainter.layout(maxWidth: constraints.maxWidth);
          if (!textPainter.didExceedMaxLines && textPainter.height <= constraints.maxHeight) {
            optimalFontSize = size;
            break;
          }
        }

        return Text(
          text,
          style: style.copyWith(fontSize: optimalFontSize),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class CardGrid extends StatelessWidget {
  final List<VotingAnswer> answers;
  final String? selectedAuthorId;
  final String currentPlayerId;
  final String? myOptionIdForThisCard;
  final bool isTarget;
  final ValueChanged<String> onSelect;

  const CardGrid({
    super.key,
    required this.answers,
    required this.selectedAuthorId,
    required this.currentPlayerId,
    this.myOptionIdForThisCard,
    this.isTarget = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: answers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final ans = answers[index];
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72, maxHeight: 132),
            child: SizedBox(
              height: 92,
              child: _buildCardItem(context, ans),
            ),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: answers.length,
      itemBuilder: (context, index) => _buildCardItem(context, answers[index]),
    );
  }

  Widget _buildCardItem(BuildContext context, VotingAnswer ans) {
    final theme = Theme.of(context);
    final isSelfAnswer = myOptionIdForThisCard != null
        ? ans.authorId == myOptionIdForThisCard
        : ans.isSelfAnswer;
    final isPlaceholder = ans.text == 'THE SOUL IS SILENT' || ans.text.trim().isEmpty;
    final isUnvotable = isTarget || isSelfAnswer || isPlaceholder;
    final isSelected = selectedAuthorId == ans.authorId;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isUnvotable ? null : () => onSelect(ans.authorId),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isUnvotable 
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
                  if (isUnvotable && !isTarget)
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
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: AutoSizedAnswerText(
                                text: ans.text,
                                style: TextStyle(
                                  color: isSelfAnswer 
                                      ? theme.colorScheme.onSurface.withOpacity(0.4) 
                                      : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lora',
                                  height: 1.25,
                                ),
                                maxFontSize: 16,
                                minFontSize: 9.5,
                              ),
                            ),
                          ),
                          if (isSelfAnswer) ...[
                            const SizedBox(height: 2),
                            Text(
                              isTarget ? '(Your Truth)' : '(Your Forgery)',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 10,
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
  }
}
