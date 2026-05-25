import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../models/card_model.dart';
import '../utils/scoring_logic.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';

class Phase4RevealScreen extends StatefulWidget {
  const Phase4RevealScreen({super.key});

  @override
  State<Phase4RevealScreen> createState() => _Phase4RevealScreenState();
}

class _Phase4RevealScreenState extends State<Phase4RevealScreen> {
  bool _isInit = false;
  Map<String, int> _latestDeltas = {};
  bool _isNavigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final gs = context.read<GameService>();
      if (gs.gameState != null && gs.players.isNotEmpty) {
        _calculateAndShowResults(gs);
        _isInit = true;
      }
    }
  }

  void _calculateAndShowResults(GameService gs) async {
    final state = gs.gameState!;
    
    final currentTargetId = state.currentReaderId;
    CardModel? currentCard;
    if (currentTargetId != null) {
      try {
        currentCard = state.cards.firstWhere((c) => c.targetPlayerId == currentTargetId);
      } catch (_) {}
    }
    
    if (currentCard == null) return;

    // Use ScoringLogic just to locally determine what to show in the UI tooltips/highlights
    final scoreDeltas = ScoringLogic.calculateScores(
      state: state,
      currentCard: currentCard,
      playerVotes: currentCard.votes,
    );

    if (mounted) {
      setState(() => _latestDeltas = scoreDeltas);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final state = gs.gameState;
    final theme = Theme.of(context);

    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final correctRoute = GameState.getRouteForPhase(state.currentPhase);
    if (correctRoute != '/reveal') {
      if (!_isNavigating) {
        _isNavigating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, correctRoute);
        });
      }
      return const SizedBox.shrink();
    } else {
      _isNavigating = false;
    }

    final currentTargetId = state.currentReaderId;
    CardModel? currentCard;
    if (currentTargetId != null) {
      try {
        currentCard = state.cards.firstWhere((c) => c.targetPlayerId == currentTargetId);
      } catch (_) {}
    }

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('THE REVEAL', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - val)),
              child: Opacity(opacity: val, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentTargetId != null
                      ? 'RESOLVING ${gs.players.firstWhere((p) => p.id == currentTargetId, orElse: () => PlayerState(id: '', name: 'Unknown')).name.toUpperCase()}\'S CARD'
                      : 'RESOLVING CARD',
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                if (currentCard != null) ...[
                  const SizedBox(height: 10),
                  Text(currentCard.promptText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, fontFamily: 'serif')),
                  const SizedBox(height: 24),
                  
                  // Options & Votes List
                  ...[
                    _buildOptionRow('TRUTH', currentCard.truthAnswer, currentCard, gs, theme, isTruth: true),
                    ...currentCard.sabotageAnswers.entries.map((e) => 
                      _buildOptionRow(e.key, e.value, currentCard!, gs, theme)
                    ),
                  ],

                  // Render Points Awarded (locally calculated for presentation only)
                  // WARNING: Do NOT invoke gs.applyScoreDeltas() here. Scores are already
                  // applied atomically during the transition in GameService._advanceRotationOrPhase().
                  if (_latestDeltas.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'POINTS AWARDED THIS CARD', 
                      style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: _latestDeltas.entries.where((e) => e.value > 0).map((e) {
                        final player = gs.players.firstWhere((p) => p.id == e.key, orElse: () => PlayerState(id: e.key, name: 'Unknown'));
                        return Chip(
                          avatar: PlayerAvatar(player: player, size: 20, showName: false),
                          label: Text('${player.name}: +${e.value}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          backgroundColor: theme.colorScheme.secondary.withOpacity(0.2),
                          side: BorderSide(color: theme.colorScheme.secondary),
                        );
                      }).toList(),
                    ),
                  ],
                ],
                const SizedBox(height: 40),
                if (gs.currentPlayer?.isHost == true) ...[
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: 'CONTINUE',
                    onPressed: () => gs.advanceToNextResolution(),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildOptionRow(String authorId, String text, CardModel card, GameService gs, ThemeData theme, {bool isTruth = false}) {
    final voters = gs.players.where((p) => card.votes[p.id] == authorId).toList();
    final cardColor = const Color(0xFF1A1F1C);
    final truthBorderColor = theme.colorScheme.tertiary; // Emerald Green for Truth
    final forgeryBorderColor = theme.colorScheme.primary; // Crimson for Forgery
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isTruth ? truthBorderColor : forgeryBorderColor.withOpacity(0.7),
            width: isTruth ? 3.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isTruth 
                  ? truthBorderColor.withOpacity(0.2) 
                  : forgeryBorderColor.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isTruth ? truthBorderColor : forgeryBorderColor).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isTruth ? 'THE TRUTH' : 'A FORGERY',
                          style: TextStyle(
                            color: isTruth ? truthBorderColor : forgeryBorderColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    text, 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'serif',
                    ),
                  ),
                ],
              ),
            ),
            if (voters.isNotEmpty) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'VOTES',
                    style: TextStyle(
                      color: theme.colorScheme.secondary.withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: voters.map((v) => Tooltip(
                      message: v.name,
                      child: PlayerAvatar(player: v, size: 28),
                    )).toList(),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
