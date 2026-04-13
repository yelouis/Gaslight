import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/card_model.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';
import '../utils/prompt_decks.dart';

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
    
    final targetId = state.currentCardAssignments[me.id];
    if (targetId != null) {
      CardModel targetCard = state.cards.firstWhere((c) => c.targetPlayerId == targetId);
      
      if (state.currentPhase == GamePhase.truth) {
        targetCard = targetCard.copyWith(truthAnswer: text);
      } else {
        Map<String, String> newSabs = Map.from(targetCard.sabotageAnswers);
        newSabs[me.id] = text;
        targetCard = targetCard.copyWith(sabotageAnswers: newSabs);
      }

      List<CardModel> newCards = state.cards.map((c) => c.targetPlayerId == targetId ? targetCard : c).toList();
      
      await gs.updateGameState(state.copyWith(cards: newCards));
    }
    
    await gs.setPlayerReady(true);
    
    // Evaluate if host
    if (me.isHost) {
      await gs.evaluateReadyState();
    }
    
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

    if (state.currentPhase == GamePhase.vote && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/vote');
      });
      return const SizedBox.shrink();
    }

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            state.currentPhase == GamePhase.truth ? 'TRUTH PHASE' : 'SABOTAGE PHASE', 
            style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2)
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: me.isReadyForNextRotation ? _buildWaitingUI(state, gs, theme) : _buildWriteUI(state, me, theme, gs),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingUI(GameState state, GameService gs, ThemeData theme) {
    int unready = gs.players.where((p) => !p.isReadyForNextRotation).length;
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
              isTruthRound ? "WRITE YOUR TRUTH" : "SABOTAGE FOR ${targetName.toUpperCase()}",
              style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5),
            ),
            const SizedBox(height: 24),
            ParchmentCard(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    "Prompt:",
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    targetCard.promptId, // Contains the full prompt string based on PromptDecks
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _answerController,
                    maxLines: 3,
                    enabled: !_isSubmitting,
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                    decoration: InputDecoration(
                      hintText: 'Complete the sentence...',
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isSubmitting
                      ? CircularProgressIndicator(color: theme.colorScheme.primary)
                      : PrimaryButton(
                          text: 'SUBMIT',
                          onPressed: () => _submitAnswer(gs),
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
