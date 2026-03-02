import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/swipeable_card.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';

class Phase3VoteScreen extends StatefulWidget {
  const Phase3VoteScreen({super.key});

  @override
  State<Phase3VoteScreen> createState() => _Phase3VoteScreenState();
}

class _Phase3VoteScreenState extends State<Phase3VoteScreen> {
  String? _selectedOption;
  double _sliderValue = 1;
  bool _submitted = false;
  bool _isNavigating = false;

  void _submitVote(GameService gs) {
    if (_selectedOption == null) return;
    
    setState(() => _submitted = true);
    
    final player = gs.currentPlayer!;
    final updatedPlayer = player.copyWith(
      selectedOption: _selectedOption,
      guessedTarget: _sliderValue.toInt(),
    );
    
    gs.updatePlayerState(gs.gameState!.roomCode, updatedPlayer);
    
    _checkPhaseTransition(gs);
  }

  void _checkPhaseTransition(GameService gs) {
    if (!gs.currentPlayer!.isHost) return;
    
    // Check if everyone EXCEPT the trickster has voted
    final voters = gs.players.where((p) => p.id != gs.gameState!.currentTricksterId);
    final allVoted = voters.every((p) => p.selectedOption != null);
    
    if (allVoted) {
      final newGameState = gs.gameState!.copyWith(currentPhase: GamePhase.reveal);
      gs.updateGameState(newGameState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final state = gs.gameState;
    final current = gs.currentPlayer;
    final theme = Theme.of(context);

    if (state == null || current == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.currentPhase == GamePhase.reveal && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/reveal');
      });
      return const SizedBox.shrink();
    }

    final isTrickster = current.id == state.currentTricksterId;

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
            child: isTrickster ? _buildTricksterWaiting(theme) : _buildVoterUI(state, gs, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildVoterUI(GameState state, GameService gs, ThemeData theme) {
    if (_submitted) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Waiting for other Voters...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          if (gs.currentPlayer!.isHost)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: SecondaryButton(
                text: 'PROCEED TO REVEAL (HOST)',
                onPressed: () { // Manual override wrapper
                  gs.updateGameState(state.copyWith(currentPhase: GamePhase.reveal));
                },
              ),
            ),
        ],
      );
    }

    int maxVoters = gs.players.length > 1 ? gs.players.length - 1 : 1;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && _selectedOption == null) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() => _selectedOption = 'A');
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            setState(() => _selectedOption = 'B');
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
          PlayerAvatar(player: gs.currentPlayer!, size: 50),
          const SizedBox(height: 16),
          if (_selectedOption == null) ...[
            Text(
              'MAKE YOUR CHOICE',
              style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            Center(
              child: Builder(
                builder: (context) {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final cardWidth = screenWidth < 392 ? screenWidth - 32 : 360.0;
                  final idealCardHeight = cardWidth * 1.4;

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SwipeableCard(
                      onSwiped: (isRight) {
                        setState(() {
                          _selectedOption = isRight ? 'A' : 'B';
                        });
                      },
                      child: Stack(
                        children: [
                          ParchmentCard(
                            padding: const EdgeInsets.only(top: 40, bottom: 40, left: 24, right: 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: idealCardHeight),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        (state.activeTemplate ?? "").split('%A').first.trim(),
                                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        state.activePromptFirstHalf ?? "Prompt missing",
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 20),
                                      const Text('... OR ...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 2)),
                                      const SizedBox(height: 20),
                                      Text(
                                        state.activePromptSecondHalf ?? "Option missing",
                                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('👈 OPTION 2', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                                      const Text('OPTION 1 👉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: _buildCardIndex(theme),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Transform.rotate(
                              angle: pi,
                              child: _buildCardIndex(theme),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            ParchmentCard(
              child: Column(
                children: [
                  Text(
                    'You voted for Option $_selectedOption',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'What was the Trickster aiming for?',
                    style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: _sliderValue,
                    min: 1,
                    max: maxVoters.toDouble(),
                    divisions: maxVoters > 1 ? maxVoters - 1 : null,
                    label: _sliderValue.toInt().toString(),
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      setState(() => _sliderValue = val);
                    },
                  ),
                  Text(
                    '${_sliderValue.toInt()} Votes',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 30),
                  PrimaryButton(
                    text: 'LOCK IN BET',
                    onPressed: () => _submitVote(gs),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildCardIndex(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Q', // Queen
          style: TextStyle(
            color: theme.colorScheme.primary, // Burgundy
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            height: 1.0,
          ),
        ),
        Icon(
          Icons.remove_red_eye,
          color: theme.colorScheme.primary,
          size: 18,
        ),
      ],
    );
  }

  Widget _buildTricksterWaiting(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: theme.colorScheme.secondary),
        const SizedBox(height: 30),
        Text(
          'THE TRAP IS SET',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 10),
        const Text('Waiting for the Voters to fall for it...', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}
