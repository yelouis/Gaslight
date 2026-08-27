import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import '../utils/prompt_decks.dart';
import 'shared_ui.dart';

class DeckPeekSheet extends StatefulWidget {
  final String deckId;

  const DeckPeekSheet({super.key, required this.deckId});

  static Future<void> show(BuildContext context, String deckId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.groundRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DeckPeekSheet(deckId: deckId),
    );
  }

  @override
  State<DeckPeekSheet> createState() => _DeckPeekSheetState();
}

class _DeckPeekSheetState extends State<DeckPeekSheet> {
  late List<String> _sampledPrompts;

  @override
  void initState() {
    super.initState();
    _samplePrompts();
  }

  void _samplePrompts() {
    final deck = PromptDecks.getDeck(widget.deckId);
    if (deck == null || deck.prompts.isEmpty) {
      _sampledPrompts = const [];
      return;
    }
    final int sampleCount = min(8, deck.prompts.length);
    final shuffled = List<String>.from(deck.prompts)..shuffle();
    setState(() {
      _sampledPrompts = shuffled.take(sampleCount).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = PromptDecks.getDeck(widget.deckId);
    if (deck == null) {
      return const SizedBox.shrink();
    }

    final rating = deck.rating;
    final bool hasSeal = rating != null;
    final String? sealLabel = rating == null ? null : AppColors.sealLabelFor(rating);
    final Color sealColor = rating == null ? AppColors.oxblood : AppColors.sealColorFor(rating);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.ivory.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasSeal) ...[
                    WaxSealBadge(
                      size: 32,
                      color: sealColor,
                      label: sealLabel,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deck.displayName,
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brass,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${deck.prompts.length} PROMPTS',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: AppColors.ivory.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.ivory, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.brass, thickness: 0.8),
              const SizedBox(height: 8),
              // Section Header & Shuffle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      "A TASTE OF WHAT'S INSIDE",
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AppColors.ivory,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const ValueKey('deck_peek_shuffle'),
                    onPressed: _samplePrompts,
                    icon: const ThematicIcon(
                      type: ThematicIconType.redraw,
                      size: 14,
                      color: AppColors.brass,
                    ),
                    label: const Text(
                      'SHUFFLE',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brass,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Prompts List
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int idx = 0; idx < _sampledPrompts.length; idx++) ...[
                        if (idx > 0) const SizedBox(height: 8),
                        Container(
                          key: ValueKey('peek_prompt_$idx'),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.ground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.brass.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '• ',
                                style: TextStyle(
                                  color: AppColors.brass.withOpacity(0.8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _sampledPrompts[idx],
                                  style: const TextStyle(
                                    fontFamily: 'Lora',
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.ivory,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
