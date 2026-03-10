import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
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
  int _actualVotes = 0;
  bool _isNavigating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final gs = context.read<GameService>();
      if (gs.gameState != null && gs.gameState?.currentTricksterId != null) {
        _calculateAndShowResults(gs);
        _isInit = true;
      }
    }
  }

  void _calculateAndShowResults(GameService gs) async {
    final state = gs.gameState!;
    final players = gs.players;

    if (gs.currentPlayer?.isHost == true) {
      // Calculate scores uniquely as Host to avoid multiple writes
      int actualVotes = 0;
      Map<String, int> guesses = {};
      int totalVoters = 0;

      for (var p in players) {
        if (p.id == state.currentTricksterId) continue;
        totalVoters++;
        if (p.selectedOption == 'B') actualVotes++;
        if (p.guessedTarget != null) guesses[p.id] = p.guessedTarget!;
      }

      final scoreDeltas = ScoringLogic.calculateScores(
        tricksterId: state.currentTricksterId!,
        target: state.secretTarget ?? 0,
        actualVotes: actualVotes,
        playerGuesses: guesses,
        totalVoters: totalVoters,
      );

      // Apply deltas
      for (var p in players) {
        final delta = scoreDeltas[p.id] ?? 0;
        final updatedPlayer = p.copyWith(score: p.score + delta);
        await gs.updatePlayerState(state.roomCode, updatedPlayer);
      }
    }

    // Determine results for display
    int count = 0;
    for (var p in players) {
      if (p.id != state.currentTricksterId && p.selectedOption == 'B') {
        count++;
      }
    }
    setState(() => _actualVotes = count);
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
    
    if (state.currentPhase == GamePhase.craft && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/craft');
      });
      return const SizedBox.shrink();
    }

    final target = state.secretTarget ?? 0;
    final isBullseye = _actualVotes == target;

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
                'THE TRICKSTER\'S TRAP:',
                style: TextStyle(color: theme.colorScheme.secondary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 10),
              ParchmentCard(
                width: double.infinity,
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                    children: _buildTemplateSpans(
                      state.activeTemplate ?? "Would you rather %A or %B?",
                      state.activePromptFirstHalf ?? "Unknown",
                      state.activePromptSecondHalf ?? "Unknown",
                      theme,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'THE TARGET WAS:',
                style: TextStyle(color: theme.colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              Text('$target', style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: theme.colorScheme.secondary, shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)])),
              const SizedBox(height: 20),
              Text(
                'ACTUAL VOTES FOR OPTION B:',
                style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              Text('$_actualVotes', style: TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)])),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isBullseye ? theme.colorScheme.secondary.withOpacity(0.2) : theme.colorScheme.primary.withOpacity(0.2),
                  border: Border.all(color: isBullseye ? theme.colorScheme.secondary : theme.colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isBullseye ? '🎯 BULLSEYE! PERFECT TRICK!' : '❌ THE TRICKSTER MISSED',
                  style: TextStyle(
                    fontSize: 22, 
                    fontWeight: FontWeight.bold, 
                    color: isBullseye ? theme.colorScheme.secondary : theme.colorScheme.primary,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4)],
                  ),
                ),
              ),
              if (gs.currentPlayer?.isHost == true) ...[
                const SizedBox(height: 50),
                PrimaryButton(
                  text: state.currentRound < state.totalRounds ? 'NEXT ROUND' : 'SEE SUPERLATIVES',
                  onPressed: () async {
                    if (state.currentRound < state.totalRounds) {
                      // Move to next round via batched resets
                      final batch = FirebaseFirestore.instance.batch();
                      final roomRef = FirebaseFirestore.instance.collection('rooms').doc(state.roomCode);
                      
                      batch.update(roomRef, {
                        'currentRound': state.currentRound + 1,
                        'currentPhase': GamePhase.craft.name,
                        'currentTricksterId': FieldValue.delete(),
                        'secretTarget': FieldValue.delete(),
                        'activeTemplate': FieldValue.delete(),
                        'activePromptFirstHalf': FieldValue.delete(),
                        'activePromptSecondHalf': FieldValue.delete(),
                      });
                      
                      for (var p in gs.players) {
                        batch.update(roomRef.collection('players').doc(p.id), {
                          'selectedOption': FieldValue.delete(),
                          'guessedTarget': FieldValue.delete(),
                        });
                      }
                      
                      await batch.commit();
                    } else {
                      gs.updateGameState(state.copyWith(currentPhase: GamePhase.gameOver));
                    }
                  },
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

  List<TextSpan> _buildTemplateSpans(String template, String firstHalf, String secondHalf, ThemeData theme) {
    List<TextSpan> spans = [];
    final parts = template.split('%A');
    if (parts.isNotEmpty) {
      spans.add(TextSpan(text: parts[0]));
      spans.add(TextSpan(text: firstHalf, style: TextStyle(color: theme.colorScheme.tertiary, decoration: TextDecoration.underline)));
      if (parts.length > 1) {
        final bParts = parts[1].split('%B');
        if (bParts.isNotEmpty) {
          spans.add(TextSpan(text: bParts[0]));
          spans.add(TextSpan(text: secondHalf, style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)));
          if (bParts.length > 1) spans.add(TextSpan(text: bParts[1]));
        }
      }
    }
    return spans;
  }
}
