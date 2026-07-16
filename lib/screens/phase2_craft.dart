import 'package:flutter/material.dart';
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
import '../utils/prompt_decks.dart';
import '../utils/text_similarity.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gaslight_route.dart';
import '../widgets/waiting_indicator.dart';
import '../widgets/dealt_card_overlay.dart';


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

  void _submitAnswer(GameService gs) async {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    final state = gs.gameState!;
    final me = gs.currentPlayer!;
    
    final targetId = state.currentCardAssignments[me.id];
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
        String msg = e.toString();
        if (msg.contains('similar') || msg.contains('Similarity')) {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (me.role != PlayerRole.spectator) {
      if (state.currentPhase != _lastPhase || state.currentRotationIndex != _lastRotation) {
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

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            children: [
              TitleSettle(
                text: state.currentPhase == GamePhase.truth ? 'TRUTH' : 'FORGERY',
                style: AppTextStyles.phaseTitle.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 4),

              if (state.currentPhase == GamePhase.forgery)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Rotation ${state.currentRotationIndex} of ${state.sabotageAnswersCount}',
                    style: AppTextStyles.sectionLabel,
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
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: me.role == PlayerRole.spectator
                    ? _buildSpectatorUI(state, gs, theme)
                    : (state.readyPlayers[me.id] ?? false)
                        ? _buildWaitingUI(state, gs, theme)
                        : _buildWriteUI(state, me, theme, gs),
              ),
            ),
            if (_showDealtOverlay && me.role != PlayerRole.spectator)
              DealtCardOverlay(
                phase: state.currentPhase,
                readerName: state.currentCardAssignments[me.id] != null
                    ? gs.players.firstWhere((p) => p.id == state.currentCardAssignments[me.id], orElse: () => me).name
                    : me.name,
                promptText: state.currentCardAssignments[me.id] != null
                    ? state.cards.firstWhere((c) => c.targetPlayerId == state.currentCardAssignments[me.id], orElse: () => state.cards.first).promptText
                    : '',
                onDismiss: () {
                  setState(() {
                    _showDealtOverlay = false;
                  });
                },
              ),
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
    final activeNonSpectators = gs.players.where((p) => p.role != PlayerRole.spectator).toList();
    final activeCount = activeNonSpectators.length;
    int unready = (activeCount - readyCount).clamp(0, activeCount);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
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
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFC8BCA6), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _answerController,
                      maxLines: 3,
                      enabled: !_isSubmitting,
                      style: const TextStyle(
                        fontFamily: 'Lora',
                        color: AppColors.ink,
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                        hintText: 'Pen your response here...',
                        hintStyle: TextStyle(
                          color: Color(0x662C1E16), // ink @ 0.4
                          fontFamily: 'Lora',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isSubmitting)
                    const CircularProgressIndicator(color: AppColors.brass)
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brass,
                          foregroundColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () => _submitAnswer(gs),
                        child: const Text(
                          'SUBMIT DOSSIER',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  if (isTruthRound) ...[
                    const SizedBox(height: 16),
                    () {
                      final bool isTimerLast5Sec = state.endTime != null && 
                          (state.endTime! - DateTime.now().millisecondsSinceEpoch) < 5000;
                      final bool canReroll = !me.hasRerolled && !isTimerLast5Sec && !_isSubmitting;

                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const ThematicIcon(type: ThematicIconType.redraw, size: 18),
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
                                        SnackBar(
                                          content: Text(e.toString().replaceAll('Exception: ', '')),
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
                  if (gs.currentPlayer!.isHost)
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
