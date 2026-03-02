import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/game_service.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/prompt_deck.dart';
import '../widgets/thinking_background.dart';
import '../widgets/shared_ui.dart';

class Phase1DraftScreen extends StatefulWidget {
  const Phase1DraftScreen({super.key});

  @override
  State<Phase1DraftScreen> createState() => _Phase1DraftScreenState();
}

class _Phase1DraftScreenState extends State<Phase1DraftScreen> {
  final _promptController = TextEditingController();
  final List<String> _templates = [
    "Would you rather %A or %B?",
    "What's a worse way to die: %A or %B?",
    "Who would win in a fight: %A or %B?",
    "What's a minor superpower you'd rather have: %A or %B?",
    "What's a mildly inconvenient curse: %A or %B?",
    "If you could only eat one forever: %A or %B?",
    "If you had to be trapped in a room with %A or %B?",
  ];
  List<String> _assignedTemplates = [];
  int _currentPromptIndex = 0;
  bool _submitted = false;
  bool _isCustom = false;
  bool _isNavigating = false;
  final _customPartAController = TextEditingController();
  final _customPartBController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assignedTemplates.isEmpty) {
      final gs = context.read<GameService>();
      final rounds = gs.gameState?.totalRounds ?? 1;
      // Provide enough random templates
      _assignedTemplates = (_templates.toList()..shuffle()).take(rounds).toList();
      // Failsafe in case totalRounds > templates length (wrap around or repeat)
      while (_assignedTemplates.length < rounds) {
        _assignedTemplates.add(_templates[Random().nextInt(_templates.length)]);
      }
    }
  }

  void _submitDraft(GameService gs, PlayerState player) {
    String template = _isCustom ? "%A or %B?" : _assignedTemplates[_currentPromptIndex];
    String text = "";
    
    if (_isCustom) {
      if (_customPartAController.text.trim().isEmpty || _customPartBController.text.trim().isEmpty) return;
      template = "${_customPartAController.text.trim()} %A or %B?";
      text = _customPartBController.text.trim();
    } else {
      text = _promptController.text.trim();
      if (text.isEmpty) return;
    }

    final updatedTemplates = List<String>.from(player.draftedTemplates)..add(template);
    final updatedHalves = List<String>.from(player.draftedPromptHalves)..add(text);
    
    final updatedPlayer = player.copyWith(
      draftedTemplates: updatedTemplates,
      draftedPromptHalves: updatedHalves
    );
    gs.updatePlayerState(gs.gameState!.roomCode, updatedPlayer);
    
    _promptController.clear();
    _customPartAController.clear();
    _customPartBController.clear();
    _isCustom = false;
    
    setState(() {
      _currentPromptIndex++;
      if (_currentPromptIndex >= _assignedTemplates.length) {
        _submitted = true;
      }
    });
    
    // Check if everyone submitted all prompts to move to Phase 2
    _checkPhaseTransition(gs);
  }

  void _checkPhaseTransition(GameService gs) {
    if (!gs.currentPlayer!.isHost) return;
    
    final totalRounds = gs.gameState!.totalRounds;
    final allSubmitted = gs.players.every((p) => p.draftedPromptHalves.length >= totalRounds);
    if (allSubmitted && gs.players.isNotEmpty) {
      final newGameState = gs.gameState!.copyWith(currentPhase: GamePhase.craft);
      gs.updateGameState(newGameState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameService = context.watch<GameService>();
    final gameState = gameService.gameState;
    final currentPlayer = gameService.currentPlayer;

    if (gameState == null || currentPlayer == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.currentPhase == GamePhase.craft && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/craft');
      });
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return AnimatedThinkingBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        title: Text('ROOM: ${gameState.roomCode}'),
        centerTitle: true,
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
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16.0 : 32.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: gameService.players.map((p) {
                    final isDone = p.draftedPromptHalves.length >= gameState.totalRounds;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              PlayerAvatar(player: p, size: 48, showName: false),
                              if (isDone)
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  ),
                                )
                              else
                                Positioned(
                                  bottom: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                                    child: const Icon(Icons.more_horiz, color: Colors.grey, size: 14),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'PHASE 1: THE DRAFT',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              if (!_submitted) ...[
                Builder(
                  builder: (context) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final cardWidth = screenWidth < 392 ? screenWidth - 32 : 360.0;
                    final idealCardHeight = cardWidth * 1.4; // Poker card ratio (2.5 x 3.5)
                    
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Prompt ${_currentPromptIndex + 1} of ${gameState.totalRounds}',
                                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_note),
                                            tooltip: 'Write Custom Prompt',
                                            color: _isCustom ? theme.colorScheme.primary : Colors.grey,
                                            onPressed: () => setState(() => _isCustom = !_isCustom),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 8),
                                          if (!_isCustom)
                                            IconButton(
                                              icon: const Icon(Icons.refresh),
                                              tooltip: 'New Template',
                                              color: Colors.blueGrey,
                                              onPressed: () {
                                                setState(() {
                                                  _assignedTemplates[_currentPromptIndex] = _templates[Random().nextInt(_templates.length)];
                                                  _promptController.clear();
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  if (_isCustom)
                                    _buildCustomPromptUI(theme)
                                  else
                                    _buildInlinePromptUI(theme),
                                ],
                              ),
                              const SizedBox(height: 30),
                              PrimaryButton(
                                text: 'SUBMIT TO BANK',
                                onPressed: () => _submitDraft(gameService, currentPlayer),
                                fontSize: 16,
                              ),
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
              }),
              ] else ...[
                PromptDeck(
                  submittedCount: gameService.players.fold<int>(0, (sum, p) => sum + p.draftedPromptHalves.length),
                  totalCount: gameService.players.length * gameState.totalRounds,
                ),
                const SizedBox(height: 30),
                const Text('Waiting for other players...', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
              if (currentPlayer.isHost)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: SecondaryButton(
                    text: 'START CRAFTING PHASE (HOST)',
                    onPressed: () { // Force start for testing
                      gameService.updateGameState(gameState.copyWith(currentPhase: GamePhase.craft));
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    },
    ),
    ),
    );
  }

  Widget _buildCardIndex(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'A',
          style: TextStyle(
            color: theme.colorScheme.primary, // Burgundy
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            height: 1.0,
          ),
        ),
        Icon(
          Icons.local_fire_department,
          color: theme.colorScheme.primary,
          size: 18,
        ),
      ],
    );
  }

  Widget _buildInlinePromptUI(ThemeData theme) {
    final template = _assignedTemplates[_currentPromptIndex];
    final parts = template.split('%A');
    
    // Helper to pad regular text down so its baseline matches the textfield
    Widget paddedText(String t) => Padding(
      padding: const EdgeInsets.only(top: 14.0),
      child: Text(t, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontFamily: 'serif')),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 12,
      children: [
        if (parts.isNotEmpty) paddedText(parts[0]),
        IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 300),
            child: TextField(
              controller: _promptController,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontFamily: 'serif'),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'type here',
                hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontWeight: FontWeight.normal),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 3)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.4), width: 2)),
              ),
            ),
          ),
        ),
        if (parts.length > 1) ...[
          // Split by %B to handle the rest
          ...parts[1].split('%B').map((str) {
            if (str.isEmpty) return const SizedBox.shrink();
            return paddedText(str);
          }).expand((w) => [w, paddedText('_______')]).toList()..removeLast()
        ]
      ],
    );
  }

  Widget _buildCustomPromptUI(ThemeData theme) {
    return Column(
      children: [
        Text('Write a prompt ending in two options:', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _customPartAController,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'e.g. Would you rather date',
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text('Option 1 (To be filled now) or Option 2?', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold)),
        ),
        TextField(
          controller: _customPartBController,
          style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
          decoration: InputDecoration(
            hintText: 'Option 1 (e.g. a literal clown)',
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.5),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _customPartAController.dispose();
    _customPartBController.dispose();
    super.dispose();
  }
}
