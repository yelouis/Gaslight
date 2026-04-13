import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/card_model.dart';
import '../utils/scoring_logic.dart';
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
    final players = gs.players;
    
    final currentTargetId = state.currentReaderId;
    CardModel? currentCard;
    if (currentTargetId != null) {
      try {
        currentCard = state.cards.firstWhere((c) => c.targetPlayerId == currentTargetId);
      } catch (_) {}
    }
    
    if (currentCard == null) return;

    if (gs.currentPlayer?.isHost == true) {
      final scoreDeltas = ScoringLogic.calculateScores(
        state: state,
        currentCard: currentCard,
        playerVotes: currentCard.votes,
      );

      // Apply deltas
      for (var p in players) {
        final delta = scoreDeltas[p.id] ?? 0;
        if (delta > 0) {
           final updatedPlayer = p.copyWith(totalScore: p.totalScore + delta);
           await gs.updatePlayerState(state.roomCode, updatedPlayer);
        }
      }
      
      if (mounted) {
        setState(() => _latestDeltas = scoreDeltas);
      }
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
    
    if (state.currentPhase == GamePhase.gameOver && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/game-over');
      });
      return const SizedBox.shrink();
    }
    
    if (state.currentPhase == GamePhase.sabotage && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/craft'); // Re-uses Phase 2 UI
      });
      return const SizedBox.shrink();
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
          title: Text('PHASE 4: THE REVEAL', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2)),
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
                  'RESOLVING CARD',
                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
                if (currentCard != null) ...[
                  const SizedBox(height: 10),
                  Text(currentCard.promptId, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, fontFamily: 'serif')),
                  const SizedBox(height: 20),
                  Text('TRUTH WAS:', style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text(currentCard.truthAnswer.isNotEmpty ? currentCard.truthAnswer : '[No Truth Submitted]', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
                ],
                const SizedBox(height: 40),
                if (gs.currentPlayer?.isHost == true) ...[
                  const SizedBox(height: 50),
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
}
