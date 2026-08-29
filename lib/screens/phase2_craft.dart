import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../widgets/card_grid.dart' show kMaxAnswerLength;
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../services/audio_service.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../models/card_model.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';
import '../widgets/auto_advance_timer.dart';
import '../utils/text_similarity.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gaslight_route.dart';
import '../widgets/waiting_indicator.dart';
import '../widgets/dealt_card_overlay.dart';
import '../widgets/lamp_loading.dart';
import '../widgets/raven_mascot.dart';
import '../widgets/in_game_app_bar.dart';
import '../theme/app_icons.dart';

class Phase2CraftScreen extends StatefulWidget {
  const Phase2CraftScreen({super.key});

  @override
  State<Phase2CraftScreen> createState() => _Phase2CraftScreenState();
}

class _Phase2CraftScreenState extends State<Phase2CraftScreen> {
  final TextEditingController _answerController = TextEditingController();
  bool _isSubmitting = false;
  bool _isNavigating = false;
  bool _showDealtOverlay = false;
  GamePhase? _lastPhase;
  int? _lastRotation;

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

  void _submitAnswer(GameService gs) async {
    if (_isSubmitting) return;
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    // Length is checked here, at submit, rather than by capping the field:
    // silently refusing keystrokes gives the player no idea why the words
    // stopped appearing. They may write as much as they like and are told
    // plainly when it will not fit on the card. `submitAnswer` enforces the
    // same bound server-side, because a client-side limit is a suggestion.
    if (text.length > kMaxAnswerLength) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That is ${text.length} characters. Trim it to $kMaxAnswerLength or fewer so it fits on the card.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final state = gs.gameState!;
    final me = gs.currentPlayer!;
    
    final targetId = state.currentPhase == GamePhase.truth ? me.id : state.currentCardAssignments[me.id];
    if (targetId == null) {
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      bool isTruth = state.currentPhase == GamePhase.truth;

      // Local pre-check similarity
      CardModel? card;
      try {
        card = state.cards.firstWhere((c) => c.targetPlayerId == targetId);
      } catch (_) {}

      if (card != null) {
        final existing = <String>[];
        if (card.truthAnswer.isNotEmpty && !isTruth) {
          existing.add(card.truthAnswer);
        }
        card.sabotageAnswers.forEach((sabId, sabotageText) {
          if (sabId != me.id && sabotageText.isNotEmpty) {
            existing.add(sabotageText);
          }
        });

        if (TextSimilarity.isTooSimilar(text, existing)) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Too similar to an existing answer! Be more creative.'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
          setState(() => _isSubmitting = false);
          return;
        }
      }

      await gs.submitCardAnswer(targetId, me.id, text, isTruth);
      if (mounted) {
        _answerController.clear();
        AudioService.instance.playSubmit();
      }
    } catch (e) {
      debugPrint('EXCEPTION CAUGHT ON SUBMIT: $e, mounted=$mounted');
      if (mounted) {
        final String errStr = e.toString();
        String msg = 'Something went wrong. Try again.';
        if (errStr.contains('similar') || errStr.contains('Similarity')) {
          msg = 'Too similar to an existing answer! Be more creative.';
        }
        debugPrint('SHOWING SNACKBAR WITH MSG: $msg');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

    if (me.role != PlayerRole.spectator) {
      if (state.currentPhase != _lastPhase || state.currentRotationIndex != _lastRotation) {
        if (_lastPhase == GamePhase.forgery && state.currentPhase == GamePhase.truth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nobody answered last round. Dealing a new one.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          });
        }
        _lastPhase = state.currentPhase;
        _lastRotation = state.currentRotationIndex;
        if (!(state.readyPlayers[me.id] ?? false)) {
          _showDealtOverlay = true;
        }
      }
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

    final titleStyle = AppTextStyles.phaseTitle.copyWith(fontSize: 26);
    final roomCodeStyle = AppTextStyles.sectionLabel.copyWith(
      letterSpacing: 1.5,
      fontSize: 11,
      color: theme.colorScheme.secondary.withOpacity(0.8),
    );
    final rotationStyle = AppTextStyles.sectionLabel;

    final List<TextSpan> appBarLines = [
      TextSpan(
        text: state.currentPhase == GamePhase.truth ? 'TRUTH' : 'FORGERY',
        style: titleStyle.copyWith(
          letterSpacing: (titleStyle.letterSpacing ?? 3.0) + 6.0,
        ),
      ),
      TextSpan(
        text: 'ROOM: ${state.roomCode}',
        style: roomCodeStyle,
      ),
      if (state.currentPhase == GamePhase.forgery)
        TextSpan(
          text: 'Rotation ${state.currentRotationIndex} of ${state.sabotageAnswersCount}',
          style: rotationStyle,
        ),
    ];
    final double computedAppBarHeight = inGameAppBarHeight(context, lines: appBarLines);

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: computedAppBarHeight,
          leading: IconButton(
            icon: ThematicIcon(
              type: ThematicIconType.depart,
              color: theme.colorScheme.secondary,
            ),
            onPressed: () => _confirmLeaveGame(context, gs),
            tooltip: 'Leave game',
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TitleSettle(
                text: state.currentPhase == GamePhase.truth ? 'TRUTH' : 'FORGERY',
                style: titleStyle,
              ),
              const SizedBox(height: 2),
              Text(
                'ROOM: ${state.roomCode}',
                style: roomCodeStyle,
              ),
              if (state.currentPhase == GamePhase.forgery)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Rotation ${state.currentRotationIndex} of ${state.sabotageAnswersCount}',
                    style: rotationStyle,
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
        body: Stack(
          children: [
            SafeArea(
              child: Center(
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
            if (_showDealtOverlay && me.role != PlayerRole.spectator) ...[
              () {
                final bool isTruthRound = state.currentPhase == GamePhase.truth;
                final String? targetId = isTruthRound ? me.id : state.currentCardAssignments[me.id];
                final String promptText = targetId != null
                    ? state.cards.firstWhere((c) => c.targetPlayerId == targetId, orElse: () => state.cards.first).promptText
                    : '';
                final String readerName = targetId != null
                    ? gs.players.firstWhere((p) => p.id == targetId, orElse: () => me).name
                    : me.name;

                return DealtCardOverlay(
                  phase: state.currentPhase,
                  readerName: readerName,
                  promptText: promptText,
                  onDismiss: () {
                    setState(() {
                      _showDealtOverlay = false;
                    });
                  },
                );
              }(),
            ],
          ],
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
        ThematicIcon(type: ThematicIconType.observe, size: 64, color: theme.colorScheme.secondary),
        const SizedBox(height: 24),
        Text(
          'THE GALLERY',
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
        if (kDebugMode && gs.currentPlayer!.isHost) ...[
          const SizedBox(height: 20),
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
    final activeNonSpectators = gs.players.where((p) => p.role != PlayerRole.spectator).toList();
    final activeCount = activeNonSpectators.length;
    int unready = (activeCount - readyCount).clamp(0, activeCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const RavenMascot(state: RavenState.idle, size: 64),
        const SizedBox(height: 12),
        const CandleFlameIndicator(),
        const SizedBox(height: 24),
        Text(
          'THE INK DRIES…',
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
        
        if (kDebugMode && gs.currentPlayer!.isHost) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => gs.debugSimulateBotResponses(),
            child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        ]
      ],
    );
  }

  Widget _buildWriteUI(GameState state, dynamic me, ThemeData theme, GameService gs) {
    bool isTruthRound = state.currentPhase == GamePhase.truth;
    String? targetId = isTruthRound ? me.id : state.currentCardAssignments[me.id];
    if (targetId == null) return const Text('Error: No target assigned');

    final CardModel targetCard = state.cards.firstWhere(
      (c) => c.targetPlayerId == targetId,
      orElse: () => state.cards.isNotEmpty ? state.cards.first : CardModel(targetPlayerId: '', promptText: ''),
    );
    final targetPlayer = gs.players.firstWhere((p) => p.id == targetId, orElse: () => me);

    final String targetName;
    if (isTruthRound) {
      targetName = me.name;
    } else {
      final assignedPlayer = gs.players.where((p) => p.id == targetId).firstOrNull;
      targetName = (assignedPlayer != null && assignedPlayer.name.trim().isNotEmpty)
          ? assignedPlayer.name
          : 'them';
    }

    final String instructionText = isTruthRound
        ? 'Write something true about you — the more surprising, the better. Others must be able to believe it.'
        : 'You are writing as $targetName. Make it sound like something they would say, so people pick yours.';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.parchment,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brass, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlayerAvatar(
                player: isTruthRound ? me : targetPlayer,
                size: 40,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isTruthRound ? 'YOUR TRUTH' : targetPlayer.name.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    decoration: BoxDecoration(
                      color: AppColors.parchment,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brass, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "CASE DOSSIER",
                          style: TextStyle(
                            color: Color(0xCCB3A369), // brass @ 0.8
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            letterSpacing: 3.5,
                            fontFamily: 'Lora',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          targetCard.promptText,
                          style: const TextStyle(
                            fontFamily: 'CormorantGaramond',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                            color: AppColors.oxblood,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          instructionText,
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontStyle: FontStyle.italic,
                            color: AppColors.ink.withOpacity(0.7),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          key: const ValueKey('answer_field'),
                          controller: _answerController,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitAnswer(gs),
                          // Capped so the vote screen can render the whole
                          // answer without an ellipsis (see card_grid.dart).
                          // The server enforces the same bound - a client
                          // limit alone is not a limit.
                          enabled: !_isSubmitting,
                          style: const TextStyle(
                            fontFamily: 'Lora',
                            color: AppColors.ink,
                            fontSize: 18,
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0x992C1E16), width: 1.5), // ink @ 0.6
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: AppColors.ink, width: 2.0),
                            ),
                            disabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Color(0x4D2C1E16), width: 1.0),
                            ),
                            hintText: 'Dip the quill…',
                            hintStyle: TextStyle(
                              color: Color(0x662C1E16), // ink @ 0.4
                              fontFamily: 'Lora',
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isTruthRound) ...[
                    const SizedBox(height: 16),
                    () {
                      final bool isTimerLast5Sec = state.endTime != null && 
                          (state.endTime! - DateTime.now().millisecondsSinceEpoch) < 5000;
                      final bool isTruthPhase = state.currentPhase == GamePhase.truth;
                      final bool canReroll = isTruthPhase && !isTimerLast5Sec && !_isSubmitting;

                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const ThematicIcon(type: ThematicIconType.redraw, size: 18),
                          label: const Text('RE-ROLL PROMPT'),
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
                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Prompt re-rolled successfully!'),
                                          duration: Duration(milliseconds: 1200),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('rerollMyPrompt error: $e');
                                    if (mounted) {
                                       final String msg = (e is FirebaseFunctionsException && e.code == 'resource-exhausted')
                                           ? 'No more prompts left in this deck.'
                                           : 'Something went wrong. Try again.';
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(msg),
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                        ),
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
                      );
                    }(),
                  ],
                  if (kDebugMode && gs.currentPlayer!.isHost)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextButton(
                        onPressed: () => gs.debugSimulateBotResponses(),
                        child: const Text('DEBUG: BOTS SUBMIT', style: TextStyle(color: Colors.white24, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'SUBMIT DOSSIER',
              loading: _isSubmitting,
              onPressed: () => _submitAnswer(gs),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }
}
