import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui' show FontFeature;
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/audio_service.dart';
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
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_motion.dart';
import '../widgets/gaslight_route.dart';
import '../widgets/waiting_indicator.dart';
import '../widgets/flipping_card.dart';
import '../widgets/blinking_eye.dart';
import '../widgets/lamp_loading.dart';
import '../widgets/raven_mascot.dart';
import '../widgets/raven_pose_host.dart';


import '../theme/app_icons.dart';

class Phase3VoteScreen extends StatefulWidget {
  const Phase3VoteScreen({super.key});

  @override
  State<Phase3VoteScreen> createState() => _Phase3VoteScreenState();
}

class _Phase3VoteScreenState extends State<Phase3VoteScreen> with RavenPoseHost<Phase3VoteScreen> {
  bool _submitted = false;
  bool _isNavigating = false;
  final Set<String> _sealedSoundPlayed = {};
  String? _lastReaderId;
  String? _localSelectedAuthorId;

  void _castVote(GameService gs, String votedForId) async {
    final state = gs.gameState;
    final me = gs.currentPlayer;
    if (state == null || me == null) return;
    
    // Determine the current card we are voting on
    final currentTargetId = state.currentReaderId;
    if (currentTargetId == null) return;
    
    if (votedForId == me.id) return; // Self-vote prevention!
    
    setState(() => _submitted = true);
    
    try {
      await gs.castVote(currentTargetId, me.id, votedForId);
      if (mounted) {
        AudioService.instance.playVote();
      }
    } catch (e) {
      debugPrint('castVote error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _submitted = false);
      }
    }
  }


  void _confirmLeaveGame(BuildContext context, GameService gs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this game?'),
        content: const Text('Your card and answers will be removed from this round. You cannot rejoin a game in progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('STAY'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await gs.leaveRoom();
            },
            child: const Text('LEAVE GAME'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final state = gs.gameState;
    final me = gs.currentPlayer;
    final theme = Theme.of(context);

    if (state == null || me == null) {
      if (!_isNavigating) {
        _isNavigating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        });
      }
      return const Scaffold(backgroundColor: AppColors.ground, body: Center(child: LampLightingIndicator()));
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

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: ThematicIcon(
              type: ThematicIconType.depart,
              color: theme.colorScheme.secondary,
            ),
            onPressed: () => _confirmLeaveGame(context, gs),
            tooltip: 'Leave game',
          ),
          title: Column(
            children: [
              TitleSettle(
                text: 'THE VOTE',
                style: AppTextStyles.phaseTitle.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 2),
              Text(
                'ROOM: ${state.roomCode}',
                style: AppTextStyles.sectionLabel.copyWith(
                  letterSpacing: 1.5,
                  fontSize: 11,
                  color: theme.colorScheme.secondary.withOpacity(0.8),
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
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: me.role == PlayerRole.spectator
                ? _buildSpectatorVoteUI(state, me, theme, currentCard, gs)
                : _submitted || (state.readyPlayers[me.id] ?? false) 
                  ? _buildWaitingUI(state, gs, theme) 
                  : _buildVotingUI(state, me, theme, currentCard),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAndProceed(BuildContext context, GameService gs) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('End Voting?'),
          content: const Text('End voting now? Players who have not voted will score nothing on this card, and their vote cannot be cast later.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                gs.forceAdvance();
              },
              child: const Text('PROCEED'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaitingUI(GameState state, GameService gs, ThemeData theme) {
    int readyCount = state.readyPlayers.values.where((v) => v).length;
    final activeNonSpectators = gs.players.where((p) => p.role != PlayerRole.spectator).toList();
    final activeCount = activeNonSpectators.length;
    int unready = (activeCount - readyCount).clamp(0, activeCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RavenMascot(
          state: ravenPose,
          size: 72,
        ),
        const SizedBox(height: 12),
        const CandleFlameIndicator(),
        const SizedBox(height: 24),
        Text(
          'YOUR BALLOT IS SEALED',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 10),
        Text('Waiting for $unready players...', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 16),
        WaitingOnRow(players: activeNonSpectators, readyMap: state.readyPlayers),
        if (gs.currentPlayer!.isHost) ...[
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: SecondaryButton(
              text: 'PROCEED TO REVEAL (HOST)',
              onPressed: () => _confirmAndProceed(context, gs),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => gs.debugSimulateBotResponses(),
              child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildVotingUI(GameState state, dynamic me, ThemeData theme, CardModel? currentCard) {
    if (currentCard == null) return const Text('No card to vote on.');

    final gs = context.watch<GameService>();
    final cardId = currentCard.targetPlayerId;
    gs.fetchMyOptionId(cardId);
    final myOptionId = gs.getMyOptionIdForCard(cardId);

    final bool isTarget = (me.id == currentCard.targetPlayerId);

    final expectedVoters = gs.players
        .where((p) =>
            p.role != PlayerRole.spectator &&
            p.id != state.currentReaderId &&
            p.id != currentCard.targetPlayerId)
        .toList();

    if (_lastReaderId != state.currentReaderId) {
      _sealedSoundPlayed.clear();
      _lastReaderId = state.currentReaderId;
      if (AppMotion.reduce(context)) {
        for (var voter in expectedVoters) {
          if (state.readyPlayers[voter.id] ?? false) {
            _sealedSoundPlayed.add(voter.id);
          }
        }
      }
    }

    for (var voter in expectedVoters) {
      if (state.readyPlayers[voter.id] == true && !_sealedSoundPlayed.contains(voter.id)) {
        _sealedSoundPlayed.add(voter.id);
        if (!AppMotion.reduce(context)) {
          AudioService.instance.playVote(volume: 0.4);
        }
      }
      if (state.readyPlayers[voter.id] == true) {
        playRavenPose(RavenState.peck, onceKey: 'vote:${voter.id}:${currentCard.targetPlayerId}');
      }
    }

    final M = expectedVoters.length;
    final N = expectedVoters.where((voter) => state.readyPlayers[voter.id] ?? false).length;

    // Whose card this is.
    PlayerState? targetPlayer;
    for (final p in gs.players) {
      if (p.id == cardId) {
        targetPlayer = p;
        break;
      }
    }

    final gridAnswers = currentCard.options.map((opt) {
      final isSelf = gs.isMySubmittedAnswer(currentCard.targetPlayerId, opt.text);
      return VotingAnswer(authorId: opt.id, text: opt.text, isSelfAnswer: isSelf);
    }).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        children: [
          if (isTarget) ...[
            PlayerAvatar(player: me, size: 50),
            const SizedBox(height: 8),
            Text(
              'THEY ARE VOTING ON YOUR TRUTH',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Keep a straight face while the parlor deliberates.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (targetPlayer != null) ...[
            Text(
              'VOTING ON',
              style: TextStyle(
                color: theme.colorScheme.secondary.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            PlayerAvatar(player: targetPlayer, size: 50),
            const SizedBox(height: 10),
            Text(
              "One of these is ${targetPlayer.name}'s truth.",
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.75),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'WHICH ONE IS THE TRUTH?',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
          ] else ...[
            PlayerAvatar(player: me, size: 50),
            const SizedBox(height: 16),
            Text(
              'WHICH ONE IS THE TRUTH?',
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ParchmentCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Text(
                  'Prompt:',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentCard.promptText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Lora',
                  ),
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
                selectedAuthorId: isTarget ? null : _localSelectedAuthorId,
                currentPlayerId: me.id,
                myOptionIdForThisCard: myOptionId,
                isTarget: isTarget,
                onSelect: isTarget ? (_) {} : (authorId) {
                  setState(() {
                    _localSelectedAuthorId = authorId;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isTarget) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BlinkingEye(size: 18),
                const SizedBox(width: 8),
                Text(
                  '$N of $M ballots sealed',
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 14,
                    color: AppColors.ivory,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: "I'M READY",
              onPressed: () async {
                setState(() => _submitted = true);
                try {
                  await context.read<GameService>().setPlayerReady(true);
                  AudioService.instance.playVote();
                } catch (e) {
                  debugPrint('setPlayerReady error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Something went wrong. Try again.'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                    setState(() => _submitted = false);
                  }
                }
              },
            ),
            if (kDebugMode && context.read<GameService>().currentPlayer!.isHost)
              TextButton(
                onPressed: () => context.read<GameService>().debugSimulateBotResponses(),
                child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
              ),
          ] else ...[
            PrimaryButton(
              text: 'CONFIRM VOTE',
              onPressed: _localSelectedAuthorId == null
                  ? null
                  : () => _castVote(context.read<GameService>(), _localSelectedAuthorId!),
            ),
          ],
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
            ThematicIcon(type: ThematicIconType.observe, size: 64, color: theme.colorScheme.secondary),
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'Lora'),
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
                onPressed: () => _confirmAndProceed(context, gs),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => gs.debugSimulateBotResponses(),
                  child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
                ),
              ],
            ]
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    super.dispose();
  }
}
