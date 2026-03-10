import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';

class Phase2CraftScreen extends StatefulWidget {
  const Phase2CraftScreen({super.key});

  @override
  State<Phase2CraftScreen> createState() => _Phase2CraftScreenState();
}

class _Phase2CraftScreenState extends State<Phase2CraftScreen> with TickerProviderStateMixin {
  final _optionBController = TextEditingController();
  bool _isInit = false;
  bool _isNavigating = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final gs = context.read<GameService>();
      if (gs.gameState != null && gs.players.isNotEmpty && gs.currentPlayer != null) {
        _initPhaseLogic(gs);
        _isInit = true;
      }
    }
  }

  void _initPhaseLogic(GameService gs) {
    final state = gs.gameState!;
    final players = gs.players;
    final current = gs.currentPlayer!;

    if (current.isHost && state.currentTricksterId == null) {
      // Assign roles and setup the prompt
      final rng = Random();
      final trickster = players[rng.nextInt(players.length)];
      
      // Select random prompt half from the bank
      List<Map<String, String>> allPrompts = [];
      for (var p in players) {
        for (int i = 0; i < p.draftedPromptHalves.length; i++) {
          allPrompts.add({
            'half': p.draftedPromptHalves[i],
            'template': p.draftedTemplates.length > i ? p.draftedTemplates[i] : "Would you rather %A or %B?",
          });
        }
      }
      
      final chosen = allPrompts.isNotEmpty ? allPrompts[rng.nextInt(allPrompts.length)] : null;
      final chosenPrompt = chosen?['half'] ?? "eating a giant spider";
      final chosenTemplate = chosen?['template'] ?? "Would you rather %A or %B?";

      // Target number between 2 and max voters (players - 1)
      int maxTarget = players.length > 2 ? players.length - 1 : 1;
      int target = rng.nextInt(maxTarget) + 1; // 1 to maxTarget

      final newState = state.copyWith(
        currentTricksterId: trickster.id,
        activeTemplate: chosenTemplate,
        activePromptFirstHalf: chosenPrompt,
        secretTarget: target,
      );
      gs.updateGameState(newState);
    }
  }

  void _submitTrick(GameService gs) {
    if (_optionBController.text.isEmpty) return;
    
    final newState = gs.gameState!.copyWith(
      activePromptSecondHalf: _optionBController.text.trim(),
      currentPhase: GamePhase.vote,
    );
    gs.updateGameState(newState);
  }

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final state = gs.gameState;
    final current = gs.currentPlayer;
    final theme = Theme.of(context);

    if (state == null || current == null || state.currentTricksterId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.currentPhase == GamePhase.vote && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/vote');
      });
      return const SizedBox.shrink();
    }

    final isTrickster = current.id == state.currentTricksterId;

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('PHASE 2: THE CRAFT', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 2)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  minWidth: constraints.maxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 32.0, vertical: 12.0),
                  child: isTrickster ? _buildTricksterUI(state, gs, theme) : _buildVoterUI(theme),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTricksterUI(GameState state, GameService gs, ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - val)),
          child: Opacity(opacity: val, child: child),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
        PlayerAvatar(player: gs.currentPlayer!, size: 50),
        const SizedBox(height: 8),
        Text(
          'YOU ARE THE TRICKSTER',
          style: TextStyle(
            color: theme.colorScheme.secondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary, // Burgundy
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.secondary, width: 3), // Gold
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
              BoxShadow(color: theme.colorScheme.primary.withOpacity(0.4), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          child: Column(
            children: [
              Text('YOUR TARGET', style: TextStyle(color: theme.colorScheme.secondary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 2),
              Text(
                '${state.secretTarget} Votes',
                style: TextStyle(
                  color: theme.colorScheme.secondary, // Gold
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final cardWidth = screenWidth < 392 ? screenWidth - 32 : 360.0;
            final idealCardHeight = cardWidth * 1.4; // Poker card ratio

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
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
                                'Complete the sentence:',
                                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif'),
                                  children: _buildTemplateSpans(
                                    state.activeTemplate ?? "Would you rather %A or %B?",
                                    state.activePromptFirstHalf ?? "Unknown",
                                    theme,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _optionBController,
                                maxLines: 2,
                                style: TextStyle(color: theme.colorScheme.primary, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                                decoration: InputDecoration(
                                  hintText: 'Type Option 2...',
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                                  border: const OutlineInputBorder(),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.5),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          PrimaryButton(
                            text: 'SET THE TRAP',
                            onPressed: () => _submitTrick(gs),
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
            );
          },
        ),
      ],
    ),
    );
  }

  Widget _buildCardIndex(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'J', // Joker
          style: TextStyle(
            color: theme.colorScheme.primary, // Burgundy
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            height: 1.0,
          ),
        ),
        Icon(
          Icons.nightlight_round,
          color: theme.colorScheme.primary,
          size: 18,
        ),
      ],
    );
  }

  List<TextSpan> _buildTemplateSpans(String template, String firstHalf, ThemeData theme) {
    List<TextSpan> spans = [];
    final parts = template.split('%A');
    if (parts.isNotEmpty) {
      spans.add(TextSpan(text: parts[0]));
      spans.add(TextSpan(text: firstHalf, style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)));
      if (parts.length > 1) {
        final bParts = parts[1].split('%B');
        if (bParts.isNotEmpty) {
          spans.add(TextSpan(text: bParts[0]));
          spans.add(const TextSpan(text: "_______", style: TextStyle(color: Colors.grey)));
          if (bParts.length > 1) spans.add(TextSpan(text: bParts[1]));
        }
      }
    }
    return spans;
  }

  Widget _buildVoterUI(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ScaleTransition(
          scale: _pulseController,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.secondary.withOpacity(0.1)),
            child: Icon(Icons.visibility, size: 80, color: theme.colorScheme.secondary.withOpacity(0.8), shadows: [Shadow(color: theme.colorScheme.primary, blurRadius: 20)]),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          'THE TRICKSTER IS CRAFTING...',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.secondary, // Gold
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Text(
          'Prepare to vote and deduce their true target.',
          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _optionBController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}
