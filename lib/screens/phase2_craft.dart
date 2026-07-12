import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../models/card_model.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';
import '../widgets/auto_advance_timer.dart';
import '../utils/prompt_decks.dart';
import '../utils/semantic_filter.dart';
import '../theme/app_colors.dart';


class Phase2CraftScreen extends StatefulWidget {
  const Phase2CraftScreen({super.key});

  @override
  State<Phase2CraftScreen> createState() => _Phase2CraftScreenState();
}

class _Phase2CraftScreenState extends State<Phase2CraftScreen> {
  final _answerController = TextEditingController();
  bool _isNavigating = false;
  bool _isSubmitting = false;

  void _submitAnswer(GameService gs) async {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final state = gs.gameState!;
    final me = gs.currentPlayer!;
    
    // 1. Semantic Similarity Check
    final targetId = state.currentCardAssignments[me.id];
    if (targetId == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    final targetCard = state.cards.firstWhere((c) => c.targetPlayerId == targetId);
    final comparisonAnswers = [
      targetCard.truthAnswer,
      ...targetCard.sabotageAnswers.values
    ].where((a) => a.isNotEmpty).toList();

    final isUnique = await SemanticFilter.isAnswerUnique(text, comparisonAnswers);
    
    if (!isUnique) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Too similar to an existing answer! Be more creative.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isSubmitting = false);
      }
      return;
    }

    // 2. Proceed with submission
    bool isTruth = state.currentPhase == GamePhase.truth;
    await gs.submitCardAnswer(targetId, me.id, text, isTruth);
    
    await gs.setPlayerReady(true);
    
    
    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _answerController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final state = gs.gameState;
    final me = gs.currentPlayer;
    final theme = Theme.of(context);

    if (state == null || me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final correctRoute = GameState.getRouteForPhase(state.currentPhase);
    if (correctRoute != '/craft') {
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

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                state.currentPhase == GamePhase.truth ? 'TRUTH' : 'FORGERY', 
                style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)
              ),
              const SizedBox(height: 4),

              if (state.currentPhase == GamePhase.forgery)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Rotation ${state.currentRotationIndex} of ${state.sabotageAnswersCount}',
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12, letterSpacing: 1),
                  ),
                ),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: state.isTimerDisabled
                    ? const SizedBox.shrink()
                    : AutoAdvanceTimer(
                        endTime: state.endTime,
                        onTimerExpired: () {
                          if (me.isHost) {
                            gs.forceAdvance();
                          }
                        },
                      ),
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: me.role == PlayerRole.spectator
                ? _buildSpectatorUI(state, gs, theme)
                : (state.readyPlayers[me.id] ?? false)
                    ? _buildWaitingUI(state, gs, theme)
                    : _buildWriteUI(state, me, theme, gs),
          ),
        ),
      ),
    );
  }

  Widget _buildSpectatorUI(GameState state, GameService gs, ThemeData theme) {
    int readyCount = state.readyPlayers.values.where((v) => v).length;
    int totalActive = gs.players.where((p) => p.role != PlayerRole.spectator).length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 64, color: theme.colorScheme.secondary),
        const SizedBox(height: 24),
        Text(
          'SPECTATOR MODE',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'You joined mid-game. Enjoy watching the match!',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'Game Progress',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Players ready: $readyCount / $totalActive',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        if (gs.currentPlayer!.isHost) ...[
          const SizedBox(height: 40),
          SecondaryButton(
            text: 'EVALUATE READY STATE (HOST)',
            onPressed: () => gs.evaluateReadyState(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => gs.debugSimulateBotResponses(),
            child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        ]
      ],
    );
  }

  Widget _buildWaitingUI(GameState state, GameService gs, ThemeData theme) {
    int readyCount = state.readyPlayers.values.where((v) => v).length;
    final activeCount = gs.players.where((p) => p.role != PlayerRole.spectator).length;
    int unready = (activeCount - readyCount).clamp(0, activeCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: theme.colorScheme.secondary),
        const SizedBox(height: 30),
        Text(
          'HOLDING TIGHT...',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 10),
        Text('Waiting for $unready players...', style: const TextStyle(color: Colors.white)),
        
        if (gs.currentPlayer!.isHost) ...[
          const SizedBox(height: 40),
          SecondaryButton(
            text: 'EVALUATE READY STATE (HOST)',
            onPressed: () => gs.evaluateReadyState(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => gs.debugSimulateBotResponses(),
            child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        ]
      ],
    );
  }

  Widget _buildWriteUI(GameState state, dynamic me, ThemeData theme, GameService gs) {
    String? targetId = state.currentCardAssignments[me.id];
    if (targetId == null) return const Text('Error: No target assigned');

    CardModel targetCard = state.cards.firstWhere((c) => c.targetPlayerId == targetId);
    String targetName = gs.players.firstWhere((p) => p.id == targetId, orElse: () => me).name;
    bool isTruthRound = state.currentPhase == GamePhase.truth;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PlayerAvatar(player: me, size: 50),
            const SizedBox(height: 20),
            Text(
              isTruthRound ? "WRITE YOUR TRUTH" : "FORGERY FOR ${targetName.toUpperCase()}",
              style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
            ),
            const SizedBox(height: 24),
            CrimsonShadowCard(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                children: [
                  Text(
                    "CASE PROMPT",
                    style: TextStyle(
                      color: theme.colorScheme.primary, 
                      fontWeight: FontWeight.w800, 
                      fontSize: 13, 
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    targetCard.promptText,
                    style: TextStyle(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.onSurface, 
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _answerController,
                    maxLines: 3,
                    enabled: !_isSubmitting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your answer...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (isTruthRound) ...[
                    () {
                      final bool isTimerLast5Sec = state.endTime != null && 
                          (state.endTime! - DateTime.now().millisecondsSinceEpoch) < 5000;
                      final bool canReroll = !me.hasRerolled && !isTimerLast5Sec && !_isSubmitting;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(me.hasRerolled ? 'RE-ROLL USED' : 'RE-ROLL PROMPT'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ground,
                              foregroundColor: AppColors.brass,
                              side: BorderSide(
                                color: canReroll ? AppColors.brass : AppColors.brass.withOpacity(0.3),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: canReroll
                                ? () async {
                                    setState(() => _isSubmitting = true);
                                    try {
                                      await gs.rerollMyPrompt();
                                      _answerController.clear();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Prompt re-rolled successfully!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSubmitting = false);
                                      }
                                    }
                                  }
                                : null,
                          ),
                        ),
                      );
                    }(),
                  ],
                  _isSubmitting
                      ? CircularProgressIndicator(color: theme.colorScheme.primary)
                      : PrimaryButton(
                          text: 'SUBMIT',
                          onPressed: () => _submitAnswer(gs),
                        ),
                  if (gs.currentPlayer!.isHost)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextButton(
                        onPressed: () => gs.debugSimulateBotResponses(),
                        child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
}
