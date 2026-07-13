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
import '../theme/app_colors.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:clock/clock.dart';

class Phase4RevealScreen extends StatefulWidget {
  const Phase4RevealScreen({super.key});

  @override
  State<Phase4RevealScreen> createState() => _Phase4RevealScreenState();
}

class _FloatingReaction {
  final String id;
  final String emoji;
  final String playerName;
  final double xPercent;
  _FloatingReaction({
    required this.id,
    required this.emoji,
    required this.playerName,
    required this.xPercent,
  });
}

class _Phase4RevealScreenState extends State<Phase4RevealScreen> {
  bool _isInit = false;
  bool _isNavigating = false;
  
  late final int _mountTime;
  final Map<String, int> _lastSeenReactionAt = {};
  final List<_FloatingReaction> _floatingReactions = [];
  int _lastReactionSentTime = 0;

  int _revealStartTime = 0;
  String? _previousTargetId;
  Timer? _countdownTimer;

  int _computeStage(int now, GameState? state) {
    final elapsed = now - _revealStartTime;

    // Beat 1: 0 to 1800ms
    if (elapsed < 1800) {
      return 1;
    }

    // Beat 2: 1800ms to 3600ms
    if (elapsed < 3600) {
      return 2;
    }

    if (state == null) return 2;

    final unmaskDeadline = state.unmaskDeadline;
    if (unmaskDeadline != null && now < unmaskDeadline) {
      // Beat 3: unmask window
      return 3;
    }

    // Beat 4 starts either at 3.6s elapsed, or when unmaskDeadline passes.
    final int beat4Start = unmaskDeadline == null
        ? _revealStartTime + 3600
        : (unmaskDeadline > _revealStartTime + 3600 ? unmaskDeadline : _revealStartTime + 3600);

    if (now < beat4Start + 1800) {
      return 4;
    }

    // Beat 5
    return 5;
  }

  @override
  void initState() {
    super.initState();
    _mountTime = clock.now().millisecondsSinceEpoch;
    _revealStartTime = _mountTime;
    context.read<GameService>().addListener(_onGameServiceUpdate);
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    try {
      context.read<GameService>().removeListener(_onGameServiceUpdate);
    } catch (_) {}
    super.dispose();
  }

  void _onGameServiceUpdate() {
    if (!mounted) return;
    final gs = context.read<GameService>();
    _checkForNewReactions(gs.players);
  }

  void _triggerFloatingReaction(String playerName, String emoji) {
    final id = const Uuid().v4();
    final randomX = 0.1 + Random().nextDouble() * 0.8;
    final reaction = _FloatingReaction(
      id: id,
      emoji: emoji,
      playerName: playerName,
      xPercent: randomX,
    );
    if (mounted) {
      setState(() {
        _floatingReactions.add(reaction);
      });
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _floatingReactions.removeWhere((r) => r.id == id);
        });
      }
    });
  }

  void _checkForNewReactions(List<PlayerState> players) {
    for (var player in players) {
      final lastAt = player.lastReactionAt;
      final reaction = player.lastReaction;
      if (lastAt != null && reaction != null && lastAt > _mountTime) {
        final previousLastAt = _lastSeenReactionAt[player.id];
        if (previousLastAt == null || lastAt > previousLastAt) {
          _lastSeenReactionAt[player.id] = lastAt;
          _triggerFloatingReaction(player.name, reaction);
        }
      }
    }
  }

  Widget? _buildBestForgeryBanner(CardModel card, GameService gs) {
    final voteCounts = <String, int>{};
    for (var entry in card.votes.entries) {
      final votedFor = entry.value;
      if (votedFor != 'TRUTH') {
        voteCounts[votedFor] = (voteCounts[votedFor] ?? 0) + 1;
      }
    }
    
    if (voteCounts.isEmpty) return null;
    
    var maxVotes = 0;
    String? bestAuthorId;
    for (var entry in voteCounts.entries) {
      if (entry.value > maxVotes) {
        maxVotes = entry.value;
        bestAuthorId = entry.key;
      }
    }
    
    if (bestAuthorId == null || maxVotes == 0) return null;
    
    final bestPlayer = gs.players.firstWhere(
      (p) => p.id == bestAuthorId, 
      orElse: () => PlayerState(id: '', name: 'Unknown'),
    );
    
    if (bestPlayer.id.isEmpty) return null;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.oxblood.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brass, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.oxblood.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PlayerAvatar(player: bestPlayer, size: 32, showName: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🏆 BEST FORGERY OF THE ROUND',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.brass,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bestPlayer.name}\'s lie fooled $maxVotes player${maxVotes > 1 ? 's' : ''}!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.ivory,
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

    final _latestDeltas = currentCard != null
        ? ScoringLogic.calculateScores(
            state: state,
            currentCard: currentCard,
            playerVotes: currentCard.votes,
          )
        : <String, int>{};

    if (currentTargetId != _previousTargetId) {
      _previousTargetId = currentTargetId;
      _revealStartTime = clock.now().millisecondsSinceEpoch;
    }

    final now = clock.now().millisecondsSinceEpoch;
    final revealStage = _computeStage(now, state);

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'THE REVEAL',
            style: TextStyle(
              color: theme.colorScheme.secondary,
              fontFamily: 'CormorantGaramond',
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            Center(
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currentTargetId != null
                              ? 'RESOLVING ${gs.players.firstWhere((p) => p.id == currentTargetId, orElse: () => PlayerState(id: '', name: 'Unknown')).name.toUpperCase()}\'S CARD'
                              : 'RESOLVING CARD',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontFamily: 'Lora',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        if (currentCard != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            currentCard.promptText,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                              fontFamily: 'Lora',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          // Options & Votes List
                          if (revealStage >= 1) ...[
                            _buildOptionRow('TRUTH', currentCard.truthAnswer, currentCard, gs, theme, revealStage, isTruth: true),
                            ...currentCard.sabotageAnswers.entries.map((e) => 
                              _buildOptionRow(e.key, e.value, currentCard!, gs, theme, revealStage)
                            ),
                          ],

                          // Revenge Guess Tray (only shown in unmask window stage 3)
                          if (revealStage == 3 && state.unmaskDeadline != null)
                            _buildRevengeGuessTray(state, currentCard, gs, theme),

                          if (revealStage >= 4) ...[
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

                            // REVENGE results
                            if (state.unmaskDeadline != null && currentCard.unmaskGuesses.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Text(
                                'REVENGE UNMASKING RESULTS', 
                                style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                              ),
                              const SizedBox(height: 8),
                              ...currentCard.unmaskGuesses.entries.map((entry) {
                                final guesserId = entry.key;
                                final guessedAuthorId = entry.value;
                                final guesser = gs.players.firstWhere((p) => p.id == guesserId, orElse: () => PlayerState(id: guesserId, name: 'Unknown'));
                                final guessed = gs.players.firstWhere((p) => p.id == guessedAuthorId, orElse: () => PlayerState(id: guessedAuthorId, name: 'Unknown'));
                                final actualForgerId = currentCard!.votes[guesserId];
                                final isCorrect = guessedAuthorId == actualForgerId;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      PlayerAvatar(player: guesser, size: 20, showName: false),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${guesser.name} accused ${guessed.name} — ',
                                        style: const TextStyle(color: AppColors.ivory, fontSize: 13),
                                      ),
                                      Text(
                                        isCorrect ? 'SUCCESS! (+1)' : 'FAILED',
                                        style: TextStyle(
                                          color: isCorrect ? AppColors.verdigris : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                            
                            // Best Forgery Banner
                            () {
                              final banner = _buildBestForgeryBanner(currentCard!, gs);
                              if (banner != null) {
                                return banner;
                              }
                              return const SizedBox.shrink();
                            }(),
                          ],
                          
                          // D1 Running Leaderboard Strip
                          if (gs.players.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'STANDINGS',
                              style: TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brass.withOpacity(0.7),
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: (gs.players.where((p) => p.role != PlayerRole.spectator).toList()
                                      ..sort((a, b) => b.totalScore.compareTo(a.totalScore)))
                                    .map((player) {
                                      final delta = revealStage >= 4 ? (_latestDeltas[player.id] ?? 0) : 0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.groundRaised,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AppColors.brass.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PlayerAvatar(player: player, size: 24, showName: false),
                                              const SizedBox(width: 6),
                                              Text(
                                                player.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: AppColors.ivory,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${player.totalScore}',
                                                style: const TextStyle(
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: AppColors.brass,
                                                ),
                                              ),
                                              if (delta > 0) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '▲+$delta',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.verdigris,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 40),
                        if (gs.currentPlayer?.isHost == true) ...[
                          const SizedBox(height: 20),
                          Builder(
                            builder: (context) {
                              final isTimerActive = revealStage == 3;
                              return Opacity(
                                opacity: !isTimerActive ? 1.0 : 0.4,
                                child: PrimaryButton(
                                  text: 'CONTINUE',
                                  onPressed: !isTimerActive ? () => gs.advanceToNextResolution() : null,
                                ),
                              );
                            }
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Floating emoji reactions stack overlay
            ..._floatingReactions.map((r) {
              return Positioned(
                bottom: 80,
                left: MediaQuery.of(context).size.width * r.xPercent - 25,
                child: FloatingEmojiWidget(
                  emoji: r.emoji,
                  playerName: r.playerName,
                ),
              );
            }),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['😂', '🤨', '🐍', '👏', '🔥'].map((emoji) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Material(
                    color: AppColors.groundRaised,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        final now = clock.now().millisecondsSinceEpoch;
                        if (now - _lastReactionSentTime < 500) return;
                        _lastReactionSentTime = now;
                        gs.sendReaction(emoji);
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevengeGuessTray(GameState state, CardModel card, GameService gs, ThemeData theme) {
    final me = gs.currentPlayer;
    if (me == null) return const SizedBox.shrink();

    final isFooled = card.votes[me.id] != null && card.votes[me.id] != 'TRUTH';
    final now = clock.now().millisecondsSinceEpoch;
    final isTimerActive = state.unmaskDeadline != null && now < state.unmaskDeadline!;
    
    final remainingMs = state.unmaskDeadline != null ? state.unmaskDeadline! - now : 0;
    final remainingSec = (remainingMs / 1000).clamp(0, 20).ceil();
    final isLowTime = isTimerActive && remainingSec <= 5;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.groundRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLowTime ? Colors.redAccent : AppColors.brass,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isLowTime ? Colors.redAccent.withOpacity(0.3) : AppColors.brass.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isFooled ? Icons.gavel : Icons.hourglass_empty,
                      color: isLowTime ? Colors.redAccent : AppColors.brass,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isFooled ? 'REVENGE UNMASKING!' : 'UNMASKING IN PROGRESS...',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isLowTime ? Colors.redAccent : AppColors.brass,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (isTimerActive)
                  AnimatedScale(
                    scale: isLowTime ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLowTime ? Colors.redAccent.withOpacity(0.2) : AppColors.ground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isLowTime ? Colors.redAccent : AppColors.brass.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        '${remainingSec}s',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isLowTime ? Colors.redAccent : AppColors.ivory,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isFooled) ...[
              () {
                final submittedGuessId = card.unmaskGuesses[me.id];
                if (submittedGuessId != null) {
                  final guessedPlayer = gs.players.firstWhere(
                    (p) => p.id == submittedGuessId,
                    orElse: () => PlayerState(id: '', name: 'Unknown'),
                  );
                  if (isTimerActive) {
                    return Text(
                      'You accused ${guessedPlayer.name}! Waiting for the timer to reveal results...',
                      style: const TextStyle(color: AppColors.ivory, fontSize: 14, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    );
                  } else {
                    final actualForgerId = card.votes[me.id];
                    final isCorrect = submittedGuessId == actualForgerId;
                    return Column(
                      children: [
                        Text(
                          isCorrect ? 'REVENGE SUCCESSFUL!' : 'REVENGE FAILED!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? AppColors.verdigris : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isCorrect
                              ? 'You correctly accused ${guessedPlayer.name}! (+1 Point to you, -1 to forger)'
                              : 'You accused ${guessedPlayer.name}, but the real forger was ${gs.players.firstWhere((p) => p.id == actualForgerId, orElse: () => PlayerState(id: '', name: 'Unknown')).name}!',
                          style: const TextStyle(color: AppColors.ivory, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  }
                } else {
                  if (isTimerActive) {
                    final candidates = gs.players
                        .where((p) => p.id != me.id && p.role != PlayerRole.spectator)
                        .toList();
                    return Column(
                      children: [
                        const Text(
                          'Accuse the player who wrote the forgery you voted for:',
                          style: TextStyle(color: AppColors.ivory, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: candidates.map((cand) {
                            return OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.brass),
                                foregroundColor: AppColors.ivory,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await gs.submitUnmaskGuess(cand.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(e.toString())),
                                    );
                                  }
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PlayerAvatar(player: cand, size: 20, showName: false),
                                  const SizedBox(width: 6),
                                  Text(cand.name.toUpperCase()),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  } else {
                    return const Text(
                      'Time is up! You failed to submit a guess in time.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    );
                  }
                }
              }(),
            ] else ...[
              () {
                final fooledPlayers = gs.players.where((p) =>
                  card.votes[p.id] != null && card.votes[p.id] != 'TRUTH'
                ).toList();
                if (fooledPlayers.isEmpty) {
                  return const Text(
                    'Nobody was fooled! Skipping revenge phase.',
                    style: TextStyle(color: AppColors.ivory, fontStyle: FontStyle.italic),
                  );
                }
                return Column(
                  children: [
                    const Text(
                      'Fooled players are trying to unmask their forgers:',
                      style: TextStyle(color: AppColors.ivory, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: fooledPlayers.map((p) {
                        final hasGuessed = card.unmaskGuesses[p.id] != null;
                        return Chip(
                          avatar: PlayerAvatar(player: p, size: 18, showName: false),
                          label: Text(
                            '${p.name}: ${hasGuessed ? 'Accused!' : 'Thinking...'}',
                            style: TextStyle(
                              color: hasGuessed ? AppColors.verdigris : AppColors.brass,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: AppColors.ground,
                          side: BorderSide(
                            color: hasGuessed ? AppColors.verdigris.withOpacity(0.5) : AppColors.brass.withOpacity(0.3),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(String authorId, String text, CardModel card, GameService gs, ThemeData theme, int revealStage, {bool isTruth = false}) {
    final voters = revealStage >= 1
        ? gs.players.where((p) => card.votes[p.id] == authorId).toList()
        : <PlayerState>[];
    final cardColor = AppColors.groundRaised;
    final truthBorderColor = theme.colorScheme.tertiary;
    final forgeryBorderColor = theme.colorScheme.primary;
    
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
                      () {
                        final bool isRevealed = isTruth ? revealStage >= 2 : revealStage >= 4;

                        return FlippingRevealCard(
                          isRevealed: isRevealed,
                          back: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: AppColors.ground,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.brass.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock, color: AppColors.brass, size: 12),
                                const SizedBox(width: 4),
                                const Text(
                                  'SEALED ANSWER',
                                  style: TextStyle(
                                    fontFamily: 'CormorantGaramond',
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: AppColors.brass,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          front: isTruth
                              ? Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.ground,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.verdigris.withOpacity(0.8)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.verified, color: AppColors.verdigris, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'THE TRUTH',
                                        style: TextStyle(
                                          fontFamily: 'CormorantGaramond',
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: AppColors.verdigris,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : () {
                                  final author = gs.players.firstWhere(
                                    (p) => p.id == authorId,
                                    orElse: () => PlayerState(id: authorId, name: 'Unknown'),
                                  );
                                  return Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.ground,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.oxblood.withOpacity(0.6)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PlayerAvatar(player: author, size: 18, showName: false),
                                        const SizedBox(width: 6),
                                        Text(
                                          'FORGERY BY ${author.name.toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }(),
                        );
                      }(),
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

class FloatingEmojiWidget extends StatelessWidget {
  final String emoji;
  final String playerName;

  const FloatingEmojiWidget({
    super.key,
    required this.emoji,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 3),
      builder: (context, progress, child) {
        final opacity = progress < 0.7 ? 1.0 : (1.0 - progress) / 0.3;
        final yOffset = -300 * progress;
        
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Opacity(
            opacity: opacity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 40),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    playerName,
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FlippingRevealCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isRevealed;

  const FlippingRevealCard({
    super.key,
    required this.front,
    required this.back,
    required this.isRevealed,
  });

  @override
  State<FlippingRevealCard> createState() => _FlippingRevealCardState();
}

class _FlippingRevealCardState extends State<FlippingRevealCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isRevealed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FlippingRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefersReducedMotion = MediaQuery.of(context).accessibleNavigation;
    if (prefersReducedMotion) {
      return widget.isRevealed ? widget.front : widget.back;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isFront = angle >= pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront
              ? Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: widget.front,
                )
              : widget.back,
        );
      },
    );
  }
}
