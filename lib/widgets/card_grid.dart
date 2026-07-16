import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_motion.dart';

class VotingAnswer {
  final String authorId;
  final String text;
  VotingAnswer({required this.authorId, required this.text});
}

class CardGrid extends StatelessWidget {
  final List<VotingAnswer> answers;
  final String? selectedAuthorId;
  final String currentPlayerId;
  final ValueChanged<String> onSelect;

  const CardGrid({
    super.key,
    required this.answers,
    required this.selectedAuthorId,
    required this.currentPlayerId,
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
        final isSelfAnswer = ans.authorId == currentPlayerId;
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lora',
                                  height: 1.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 4,
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
