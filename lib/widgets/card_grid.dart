import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/player_state.dart';
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
/// must render the longest legal answer in full — no ellipsis.
///
/// `test/vote_option_truncation_test.dart` asserts this mechanically via
/// `RenderParagraph.didExceedMaxLines` at 320, 375, and 430 pt viewports.
const int kMaxAnswerLength = 100;

String _toRoman(int n) {
  const romans = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
  if (n >= 1 && n <= romans.length) return romans[n - 1];
  return '$n';
}

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

/// Treatment 3: Stacked Deck with Peek (Issue 160)
///
/// Displays options as a physical parlour card deck where the active option
/// sits in front, and underlying cards peek out with layered rotations and offsets.
/// Supports bidirectional navigation (swipe left to peel next, swipe right to unpeel
/// previous, compact Previous/Next buttons, and interactive dot indicators).
///
/// Also integrates the AA16b target forgery author attribution chip interface
/// when [isTarget] is true.
class CardGrid extends StatefulWidget {
  final List<VotingAnswer> answers;
  final String? selectedAuthorId;
  final String currentPlayerId;
  final String? myOptionIdForThisCard;
  final bool isTarget;
  final ValueChanged<String> onSelect;

  // AA16b: Target forgery guessing integration
  final Map<String, String>? targetForgeryGuesses;
  final List<PlayerState>? candidateAuthors;
  final void Function(String optionId, String authorId)? onAttributeForgery;
  final int initialIndex;

  const CardGrid({
    super.key,
    required this.answers,
    required this.selectedAuthorId,
    required this.currentPlayerId,
    this.myOptionIdForThisCard,
    this.isTarget = false,
    required this.onSelect,
    this.targetForgeryGuesses,
    this.candidateAuthors,
    this.onAttributeForgery,
    this.initialIndex = 0,
  });

  @override
  State<CardGrid> createState() => _CardGridState();
}

class _CardGridState extends State<CardGrid> {
  late int _currentIndex;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedAuthorId != null) {
      final selIdx = widget.answers.indexWhere((a) => a.authorId == widget.selectedAuthorId);
      _currentIndex = selIdx != -1 ? selIdx : widget.initialIndex.clamp(0, math.max(0, widget.answers.length - 1));
    } else {
      _currentIndex = widget.initialIndex.clamp(0, math.max(0, widget.answers.length - 1));
    }
  }

  @override
  void didUpdateWidget(CardGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_currentIndex >= widget.answers.length) {
      _currentIndex = math.max(0, widget.answers.length - 1);
    }
  }

  void _peelNext() {
    if (_currentIndex < widget.answers.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

  void _unpeelPrev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToIndex(int index) {
    if (index >= 0 && index < widget.answers.length && index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onCardTap(int index, VotingAnswer ans) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });
    }
    if (!_isAnswerUnvotable(ans)) {
      widget.onSelect(ans.authorId);
    }
  }

  bool _isAnswerUnvotable(VotingAnswer ans) {
    final isSelfAnswer = widget.myOptionIdForThisCard != null
        ? ans.authorId == widget.myOptionIdForThisCard
        : ans.isSelfAnswer;
    final isPlaceholder = ans.text == 'THE SOUL IS SILENT' || ans.text.trim().isEmpty;
    return widget.isTarget || isSelfAnswer || isPlaceholder;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.answers.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final activeAnswer = widget.answers[_currentIndex];
    final isSelected = widget.selectedAuthorId == activeAnswer.authorId;

    // Order items in stack: background peek cards first, front active card on top
    final stackChildren = <Widget>[];

    // Build all cards into the stack so all options exist in the widget tree for accessibility & testing
    for (int i = 0; i < widget.answers.length; i++) {
      final ans = widget.answers[i];
      final isCurrent = i == _currentIndex;
      final isNext = i == _currentIndex + 1;
      final isDeep = i == _currentIndex + 2;
      final isPeeled = i < _currentIndex;

      if (isCurrent) {
        // Front Active Card
        stackChildren.add(
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildActiveCard(context, theme, ans, isSelected),
          ),
        );
      } else if (isNext) {
        // Next Peek Card
        stackChildren.insert(
          0,
          Positioned(
            top: 8,
            left: 8,
            right: 14,
            bottom: 14,
            child: Transform.rotate(
              angle: -0.02,
              child: _buildPeekCard(context, theme, i, ans, isDeep: false),
            ),
          ),
        );
      } else if (isDeep) {
        // Deep Peek Card
        stackChildren.insert(
          0,
          Positioned(
            top: 2,
            right: 8,
            left: 18,
            bottom: 24,
            child: Transform.rotate(
              angle: 0.035,
              child: _buildPeekCard(context, theme, i, ans, isDeep: true),
            ),
          ),
        );
      } else if (isPeeled) {
        // Previous Peeled Card
        stackChildren.insert(
          0,
          Positioned(
            top: 10,
            left: -6,
            right: 20,
            bottom: 12,
            child: Transform.rotate(
              angle: -0.04,
              child: _buildPeeledCard(context, theme, i, ans),
            ),
          ),
        );
      } else {
        // Remaining unpeeled cards deeper in deck (accessible for hit testing and inspection)
        stackChildren.insert(
          0,
          Positioned(
            top: 0,
            left: 20,
            right: 10,
            bottom: 30,
            child: Opacity(
              opacity: 0.0,
              child: _buildPeekCard(context, theme, i, ans, isDeep: true),
            ),
          ),
        );
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Deck Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'CARD ${_toRoman(_currentIndex + 1)} OF ${_toRoman(widget.answers.length)}',
                  style: const TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brass,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _currentIndex == widget.answers.length - 1
                    ? '1 of ${widget.answers.length}'
                    : '${widget.answers.length - 1 - _currentIndex} behind',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 11,
                  color: AppColors.brass.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Stacked Deck Container with Horizontal Swipe Gesture
        GestureDetector(
          onHorizontalDragStart: (_) => _dragDistance = 0,
          onHorizontalDragUpdate: (details) {
            _dragDistance += details.delta.dx;
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (_dragDistance < -40 || velocity < -120) {
              _peelNext();
            } else if (_dragDistance > 40 || velocity > 120) {
              _unpeelPrev();
            }
            _dragDistance = 0;
          },
          child: SizedBox(
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: stackChildren,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Navigation Controls: Compact PREV, Interactive Dots, Compact NEXT
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Compact PREV button
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('stacked_deck_prev_button'),
                onTap: _currentIndex > 0 ? _unpeelPrev : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentIndex > 0
                        ? AppColors.brass.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _currentIndex > 0
                          ? AppColors.brass.withValues(alpha: 0.5)
                          : AppColors.brass.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left,
                        size: 16,
                        color: _currentIndex > 0
                            ? AppColors.brass
                            : AppColors.brass.withValues(alpha: 0.25),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'PREV',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                          color: _currentIndex > 0
                              ? AppColors.brass
                              : AppColors.brass.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dot indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < widget.answers.length; i++)
                  GestureDetector(
                    key: Key('stacked_deck_dot_$i'),
                    onTap: () => _goToIndex(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 6.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _currentIndex ? 14 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? AppColors.brass
                              : (widget.selectedAuthorId == widget.answers[i].authorId)
                                  ? AppColors.oxblood
                                  : AppColors.brass.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: (widget.selectedAuthorId == widget.answers[i].authorId)
                                ? AppColors.oxblood
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Compact NEXT button
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('stacked_deck_next_button'),
                onTap: _currentIndex < widget.answers.length - 1 ? _peelNext : null,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentIndex < widget.answers.length - 1
                        ? AppColors.brass.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _currentIndex < widget.answers.length - 1
                          ? AppColors.brass.withValues(alpha: 0.5)
                          : AppColors.brass.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NEXT',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                          color: _currentIndex < widget.answers.length - 1
                              ? AppColors.brass
                              : AppColors.brass.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: _currentIndex < widget.answers.length - 1
                            ? AppColors.brass
                            : AppColors.brass.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // AA16b: Target Forgery Attribution Chip Row
        if (widget.isTarget && widget.candidateAuthors != null)
          _buildTargetAttributionRow(context, theme, activeAnswer),
      ],
    );
  }

  Widget _buildActiveCard(
    BuildContext context,
    ThemeData theme,
    VotingAnswer ans,
    bool isSelected,
  ) {
    final isSelfAnswer = widget.myOptionIdForThisCard != null
        ? ans.authorId == widget.myOptionIdForThisCard
        : ans.isSelfAnswer;
    final isUnvotable = _isAnswerUnvotable(ans);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isUnvotable ? null : () => widget.onSelect(ans.authorId),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isUnvotable
                ? theme.colorScheme.surface.withValues(alpha: 0.85)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.secondary.withValues(alpha: 0.7),
              width: isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
            ],
          ),
          child: Stack(
            children: [
              // Faint watermark
              Positioned.fill(
                child: Center(
                  child: Opacity(
                    opacity: 0.04,
                    child: const WaxSealBadge(size: 100),
                  ),
                ),
              ),

              // Diagonal SEALED Ribbon on unvotable card
              if (isUnvotable && !widget.isTarget)
                _buildSealedRibbon(),

              // Card Header Strip
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brass.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.brass.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Text(
                        'OPTION ${_toRoman(_currentIndex + 1)}',
                        style: const TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brass,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Text(
                        'SELECTED BALLOT',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.oxblood,
                          letterSpacing: 1.0,
                        ),
                      ),
                  ],
                ),
              ),

              // Answer Content
              Padding(
                padding: const EdgeInsets.fromLTRB(14.0, 32.0, 14.0, 10.0),
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
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                                  : theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Lora',
                              height: 1.3,
                            ),
                            maxFontSize: 16,
                            minFontSize: 9.5,
                          ),
                        ),
                      ),
                      if (isSelfAnswer) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.isTarget ? '(Your Truth)' : '(Your Forgery)',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            fontFamily: 'Lora',
                          ),
                        ),
                      ],
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
                    tween: Tween<double>(begin: 1.5, end: 1.0),
                    duration: AppMotion.fast,
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: child,
                      );
                    },
                    child: const WaxSealBadge(key: Key('active_card_wax_seal_stamp'), size: 34),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeekCard(
    BuildContext context,
    ThemeData theme,
    int index,
    VotingAnswer ans, {
    required bool isDeep,
  }) {
    final isUnvotable = _isAnswerUnvotable(ans);

    final isSelfAnswer = widget.myOptionIdForThisCard != null
        ? ans.authorId == widget.myOptionIdForThisCard
        : ans.isSelfAnswer;

    return InkWell(
      onTap: isUnvotable ? null : () => _onCardTap(index, ans),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDeep ? const Color(0xFF181512) : const Color(0xFF221D17),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brass.withValues(alpha: isDeep ? 0.2 : 0.4),
            width: isDeep ? 1.0 : 1.5,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                'CARD ${_toRoman(index + 1)}',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brass.withValues(alpha: isDeep ? 0.4 : 0.6),
                ),
              ),
            ),
            if (isUnvotable && !widget.isTarget)
              _buildSealedRibbon(),
            // Off-screen answer text for text discoverability
            Align(
              alignment: Alignment.bottomRight,
              child: Opacity(
                opacity: 0.01,
                child: Text(
                  ans.text,
                  style: const TextStyle(fontSize: 1),
                ),
              ),
            ),
            if (isSelfAnswer)
              Opacity(
                opacity: 0.01,
                child: Text(
                  widget.isTarget ? '(Your Truth)' : '(Your Forgery)',
                  style: const TextStyle(fontSize: 1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeeledCard(
    BuildContext context,
    ThemeData theme,
    int index,
    VotingAnswer ans,
  ) {
    final isUnvotable = _isAnswerUnvotable(ans);
    final isSelfAnswer = widget.myOptionIdForThisCard != null
        ? ans.authorId == widget.myOptionIdForThisCard
        : ans.isSelfAnswer;

    return InkWell(
      onTap: isUnvotable ? null : () => _onCardTap(index, ans),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1A16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.brass.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Text(
                'CARD ${_toRoman(index + 1)}',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brass.withValues(alpha: 0.5),
                ),
              ),
            ),
            if (isUnvotable && !widget.isTarget)
              _buildSealedRibbon(),
            Align(
              alignment: Alignment.bottomLeft,
              child: Opacity(
                opacity: 0.01,
                child: Text(
                  ans.text,
                  style: const TextStyle(fontSize: 1),
                ),
              ),
            ),
            if (isSelfAnswer)
              Opacity(
                opacity: 0.01,
                child: Text(
                  widget.isTarget ? '(Your Truth)' : '(Your Forgery)',
                  style: const TextStyle(fontSize: 1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSealedRibbon() {
    return Positioned(
      top: 8,
      left: -20,
      child: Transform.rotate(
        angle: -math.pi / 4,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 2),
          color: AppColors.oxblood.withValues(alpha: 0.85),
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
    );
  }

  // AA16b: Target Forgery Attribution Chip Interface
  Widget _buildTargetAttributionRow(
    BuildContext context,
    ThemeData theme,
    VotingAnswer activeAnswer,
  ) {
    // 1. Target's own truth card offers no attribution affordance
    final isSelf = widget.myOptionIdForThisCard != null
        ? activeAnswer.authorId == widget.myOptionIdForThisCard
        : activeAnswer.isSelfAnswer;
    if (isSelf) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Text(
          'This is your own truth — no forgery to unmask.',
          style: TextStyle(
            fontFamily: 'Lora',
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: AppColors.brass.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    // 2. Candidate authors: exclude target themselves (Issue 162 rule)
    final candidates = (widget.candidateAuthors ?? [])
        .filter((p) => p.id != widget.currentPlayerId && p.role != PlayerRole.spectator)
        .toList();

    final currentGuessAuthorId = widget.targetForgeryGuesses?[activeAnswer.authorId];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.groundRaised.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'WHO AUTHORED THIS LIE? (TAP TO ATTRIBUTE)',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.brass,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final candidate in candidates)
                _buildCandidateChip(candidate, activeAnswer.authorId, currentGuessAuthorId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateChip(
    PlayerState candidate,
    String optionId,
    String? currentGuessAuthorId,
  ) {
    final isAssigned = currentGuessAuthorId == candidate.id;

    return ActionChip(
      key: Key('attribution_chip_${optionId}_${candidate.id}'),
      avatar: CircleAvatar(
        radius: 10,
        backgroundColor: isAssigned ? AppColors.ink : AppColors.brass.withValues(alpha: 0.2),
        child: Text(
          candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isAssigned ? AppColors.brass : AppColors.ivory,
          ),
        ),
      ),
      label: Text(
        candidate.name,
        style: TextStyle(
          fontFamily: 'Lora',
          fontSize: 11,
          fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
          color: isAssigned ? AppColors.ink : AppColors.ivory,
        ),
      ),
      backgroundColor: isAssigned ? AppColors.brass : const Color(0xFF26201A),
      side: BorderSide(
        color: isAssigned ? AppColors.brass : AppColors.brass.withValues(alpha: 0.3),
        width: isAssigned ? 1.5 : 1.0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () {
        if (widget.onAttributeForgery != null) {
          if (isAssigned) {
            // Tapping again clears attribution
            widget.onAttributeForgery!(optionId, '');
          } else {
            // Tapping assigns candidate
            widget.onAttributeForgery!(optionId, candidate.id);
          }
        }
      },
    );
  }
}

extension _IterableExt<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
