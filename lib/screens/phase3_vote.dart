import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../models/card_model.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';
import '../widgets/auto_advance_timer.dart';
import '../widgets/card_grid.dart';


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
  String? _shuffledCardId;
  String? _localSelectedAuthorId;

  void _generateShuffledAnswers(CardModel card) {
    if (_shuffledAnswers != null && _shuffledCardId == card.targetPlayerId) return;
    
    List<_AnonymizedAnswer> answers = [];
    answers.add(_AnonymizedAnswer('TRUTH', card.truthAnswer));
    card.sabotageAnswers.forEach((authorId, text) {
      answers.add(_AnonymizedAnswer(authorId, text));
    });
    
    answers.shuffle(Random());
    setState(() {
      _shuffledAnswers = answers;
      _shuffledCardId = card.targetPlayerId;
    });
  }

  void _castVote(GameService gs, String votedForId) async {
    final state = gs.gameState;
    final me = gs.currentPlayer;
    if (state == null || me == null) return;
    
    // Determine the current card we are voting on
    final currentTargetId = state.currentReaderId;
    if (currentTargetId == null) return;
    
    if (votedForId == me.id) return; // Self-vote prevention!
    
    setState(() => _submitted = true);
    
    // Service handles readiness update internally
    await gs.castVote(currentTargetId, me.id, votedForId);
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
    if (correctRoute != '/vote') {
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

    // Determine whose card is being resolved. 
    final currentTargetId = state.currentReaderId;
    CardModel? currentCard;
    if (currentTargetId != null) {
      try {
        currentCard = state.cards.firstWhere((c) => c.targetPlayerId == currentTargetId);
      } catch (_) {}
    }

    if (currentCard != null) {
       _generateShuffledAnswers(currentCard);
    }

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            children: [
              Text('THE VOTE', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
              const SizedBox(height: 4),
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
              ? _buildSpectatorVoteUI(state, me, theme, currentCard, gs)
              : _submitted || (state.readyPlayers[me.id] ?? false) 
                ? _buildWaitingUI(theme, gs, state) 
                : _buildVotingUI(state, me, theme, currentCard),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingUI(ThemeData theme, GameService gs, GameState state) {
    int readyCount = state.readyPlayers.values.where((v) => v).length;
    int unready = gs.players.length - readyCount;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: theme.colorScheme.secondary),
        const SizedBox(height: 20),
        const Text('YOUR VOTE IS LOCKED IN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        Text('Waiting for $unready other voters...', style: TextStyle(color: Colors.white70)),
        if (gs.currentPlayer!.isHost) ...[
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: SecondaryButton(
              text: 'PROCEED TO REVEAL (HOST)',
              onPressed: () { 
                gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal));
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => gs.debugSimulateBotResponses(),
            child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        ],
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
          ),
          if (context.read<GameService>().currentPlayer!.isHost)
            TextButton(
              onPressed: () => context.read<GameService>().debugSimulateBotResponses(),
              child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ),
        ],
      );
    }

    final gridAnswers = _shuffledAnswers?.map((a) => VotingAnswer(authorId: a.authorId, text: a.text)).toList() ?? [];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
           PlayerAvatar(player: me, size: 50),
           const SizedBox(height: 16),
           Text(
             'WHICH ONE IS THE TRUTH?',
             style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
           ),
           const SizedBox(height: 16),
           ParchmentCard(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
             child: Column(
               children: [
                 Text(
                   'Prompt:',
                   style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 13),
                 ),
                 const SizedBox(height: 6),
                 Text(
                   currentCard.promptText,
                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                   textAlign: TextAlign.center,
                 ),
               ],
             ),
           ),
           const SizedBox(height: 16),
           Expanded(
             child: SingleChildScrollView(
               child: CardGrid(
                 answers: gridAnswers,
                 selectedAuthorId: _localSelectedAuthorId,
                 currentPlayerId: me.id,
                 onSelect: (authorId) {
                   setState(() {
                     _localSelectedAuthorId = authorId;
                   });
                 },
               ),
             ),
           ),
           const SizedBox(height: 16),
           PrimaryButton(
             text: 'CONFIRM VOTE',
             onPressed: _localSelectedAuthorId == null 
                 ? null 
                 : () => _castVote(context.read<GameService>(), _localSelectedAuthorId!),
           ),
        ],
      ),
    );
  }

  Widget _buildSpectatorVoteUI(GameState state, dynamic me, ThemeData theme, CardModel? currentCard, GameService gs) {
    int readyCount = state.readyPlayers.values.where((v) => v).length;
    int totalActive = gs.players.where((p) => p.role != PlayerRole.spectator).length;
    final currentTargetId = state.currentReaderId;
    String targetName = gs.players.firstWhere((p) => p.id == currentTargetId, orElse: () => me).name;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_red_eye_outlined, size: 64, color: theme.colorScheme.secondary),
            const SizedBox(height: 24),
            Text(
              'SPECTATING VOTE',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Players are voting on ${targetName.toUpperCase()}\'s card.',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            if (currentCard != null) ...[
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
                      currentCard.promptText,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
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
                    'Voting Progress',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Votes Locked In: $readyCount / $totalActive',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (gs.currentPlayer!.isHost) ...[
              const SizedBox(height: 40),
              SecondaryButton(
                text: 'PROCEED TO REVEAL (HOST)',
                onPressed: () { 
                  gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal));
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => gs.debugSimulateBotResponses(),
                child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
