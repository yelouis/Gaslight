import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/card_model.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';

class Phase3VoteScreen extends StatefulWidget {
  const Phase3VoteScreen({super.key});

  @override
  State<Phase3VoteScreen> createState() => _Phase3VoteScreenState();
}

class _AnonymizedAnswer {
  final String authorId;
  final String text;
  _AnonymizedAnswer(this.authorId, this.text);
}

class _Phase3VoteScreenState extends State<Phase3VoteScreen> {
  bool _submitted = false;
  bool _isNavigating = false;
  List<_AnonymizedAnswer>? _shuffledAnswers;

  void _generateShuffledAnswers(CardModel card) {
    if (_shuffledAnswers != null) return;
    
    List<_AnonymizedAnswer> answers = [];
    answers.add(_AnonymizedAnswer('TRUTH', card.truthAnswer));
    card.sabotageAnswers.forEach((authorId, text) {
      answers.add(_AnonymizedAnswer(authorId, text));
    });
    
    answers.shuffle(Random());
    setState(() {
      _shuffledAnswers = answers;
    });
  }

  void _castVote(GameService gs, String votedForId) async {
    setState(() => _submitted = true);
    
    // In a full implementation, we'd write this vote to a specific map in GameState/CardModel
    // For now we just flag the player ready to proceed to Phase 4
    await gs.setPlayerReady(true);
    
    if (gs.currentPlayer!.isHost) {
      // Manual trigger for Host just in case
      gs.evaluateReadyState();
    }
    
    _checkPhaseTransition(gs);
  }

  void _checkPhaseTransition(GameService gs) {
    if (!gs.currentPlayer!.isHost) return;
    
    final voters = gs.players;
    final allVoted = voters.every((p) => p.isReadyForNextRotation);
    
    if (allVoted) {
      final newGameState = gs.gameState!.copyWith(currentPhase: GamePhase.reveal);
      gs.updateGameState(newGameState);
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

    if (state.currentPhase == GamePhase.reveal && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/reveal');
      });
      return const SizedBox.shrink();
    }

    // Determine whose card is being resolved. For Phase 3 stub, we pick the first card.
    // In a fully dynamic multi-card step-through, this would index via state.currentReaderId or similar.
    CardModel? currentCard = state.cards.isNotEmpty ? state.cards.first : null;

    if (currentCard != null) {
       _generateShuffledAnswers(currentCard);
    }

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('PHASE 3: THE VOTE', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _submitted || me.isReadyForNextRotation 
              ? _buildWaitingUI(theme, gs, state) 
              : _buildVotingUI(state, me, theme, currentCard),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingUI(ThemeData theme, GameService gs, GameState state) {
    int unready = gs.players.where((p) => !p.isReadyForNextRotation).length;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: theme.colorScheme.secondary),
        const SizedBox(height: 20),
        const Text('YOUR VOTE IS LOCKED IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        Text('Waiting for $unready other voters...', style: TextStyle(color: Colors.white70)),
        if (gs.currentPlayer!.isHost)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: SecondaryButton(
              text: 'PROCEED TO REVEAL (HOST)',
              onPressed: () { 
                gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal));
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVotingUI(GameState state, dynamic me, ThemeData theme, CardModel? currentCard) {
    if (currentCard == null) return const Text('No card to vote on.');

    if (me.id == state.currentReaderId || me.id == currentCard.targetPlayerId) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_red_eye, size: 80, color: theme.colorScheme.secondary),
          const SizedBox(height: 24),
          Text(
            'THEY ARE VOTING ON YOUR CARD...',
            style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Keep a straight face.',
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
          ),
          const SizedBox(height: 40),
          PrimaryButton(
            text: 'I\'M READY',
            onPressed: () async {
              setState(() => _submitted = true);
              await context.read<GameService>().setPlayerReady(true);
            },
          )
        ],
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
           PlayerAvatar(player: me, size: 50),
           const SizedBox(height: 20),
           Text(
             'WHICH ONE IS THE TRUTH?',
             style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
           ),
           const SizedBox(height: 20),
           ParchmentCard(
             padding: const EdgeInsets.all(20),
             child: Column(
               children: [
                 Text(
                   'Prompt:',
                   style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold),
                 ),
                 const SizedBox(height: 10),
                 Text(
                   currentCard.promptId,
                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                   textAlign: TextAlign.center,
                 ),
               ],
             ),
           ),
           const SizedBox(height: 24),
           Expanded(
             child: ListView.builder(
               itemCount: _shuffledAnswers?.length ?? 0,
               itemBuilder: (context, idx) {
                 final ans = _shuffledAnswers![idx];
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 12.0),
                   child: InkWell(
                     onTap: () => _castVote(context.read<GameService>(), ans.authorId),
                     borderRadius: BorderRadius.circular(8),
                     child: Container(
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: theme.colorScheme.surface.withOpacity(0.9),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: theme.colorScheme.secondary.withOpacity(0.5)),
                         boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                         ]
                       ),
                       child: Center(
                         child: Text(
                           ans.text,
                           style: TextStyle(
                             color: theme.colorScheme.primary,
                             fontSize: 18,
                             fontWeight: FontWeight.bold,
                             fontFamily: 'serif'
                           ),
                           textAlign: TextAlign.center,
                         ),
                       ),
                     ),
                   ),
                 );
               },
             ),
           ),
        ],
      ),
    );
  }
}
