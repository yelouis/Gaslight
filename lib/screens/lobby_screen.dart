import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/game_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';
import '../widgets/lobby_logo.dart';
import '../models/game_state.dart';
import '../models/player_state.dart';
import '../widgets/shared_ui.dart';
import '../utils/prompt_decks.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  bool _nameError = false;
  int _selectedRounds = 1;
  int _selectedAvatarIndex = 0;
  bool _isNavigating = false;
  String _selectedDeck = PromptDecks.availableDecks.first;
  bool _isTimerDisabled = false;
  Set<String> _knownPlayerIds = {};
  bool _familyFriendlyOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gs = context.read<GameService>();
      final prefs = await SharedPreferences.getInstance();
      final hasSavedSession = prefs.getString('room_code') != null;
      final rejoining = await gs.tryRejoinSession();
      if (rejoining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejoined active game session!')),
        );
      } else if (!rejoining && hasSavedSession && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your session expired — please rejoin.')),
        );
      }
    });
  }

  String _getPlayerId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid ?? const Uuid().v4();
    } catch (_) {
      return const Uuid().v4();
    }
  }

  void _createRoom() async {
    final name = _nameController.text.trim();
    setState(() => _nameError = name.isEmpty);
    if (name.isEmpty) return;

    final gameService = context.read<GameService>();
    final playerId = _getPlayerId();

    try {
      await gameService.createRoom(
        name,
        playerId,
        sabotageAnswersCount: _selectedRounds,
        avatarIndex: _selectedAvatarIndex,
        isTimerDisabled: _isTimerDisabled,
      );
    } catch (e) {
      debugPrint('Error creating room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _joinRoom() async {
    final name = _nameController.text.trim();
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    setState(() => _nameError = name.isEmpty);
    if (name.isEmpty || roomCode.length != 4) return;

    final gameService = context.read<GameService>();
    final playerId = _getPlayerId();

    try {
      await gameService.joinRoom(roomCode, name, playerId, avatarIndex: _selectedAvatarIndex);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            child: ParchmentCard(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'HOW TO PLAY',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'serif',
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Divider(color: theme.colorScheme.primary.withOpacity(0.5), thickness: 2),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInstructionSection(
                            theme,
                            'THE OBJECTIVE',
                            [
                              _highlightItem('Mimicry: ', 'Every player receives a secret card with a prompt. You are the "Target" of your card.'),
                              _highlightItem('Forgery: ', 'Cards rotate. You will receive others\' cards to write believable lies (Forgeries) on their behalf.'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            'THE PHASES',
                            [
                              _highlightItem('Forgery: ', 'Write deceptive answers for the cards you hold. These will be mixed with the real Target\'s truth.'),
                              _highlightItem('Truth: ', 'You get your own card back. Write the cold, hard biological truth.'),
                              _highlightItem('The Vote: ', 'A Reader presents all answers (1 Truth + Several Forgeries). Voters must find the Truth.'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            '3. SCORING (Dynamic)',
                            [
                               _highlightItem('Finding Truth: ', 'Points scale based on difficulty. Formula: ceil((Players - 1) / (Forgeries + 1))'),
                               _highlightItem('Successful Forgery: ', 'Get +1 point for every player you successfully trick into voting for your lie.'),
                               _highlightItem('Believeable Target: ', 'Targets get +1 point for every player who correctly identifies their truth.'),
                               _highlightItem('Sharp Eye: ', 'Spot the truth on a card you also faked? Earn +1 bonus point.'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            '4. PROMPT INTEGRITY',
                            [
                              _highlightItem('AI Filter: ', 'The game uses semantic analysis to reject answers too similar to existing ones. Be original!'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: const Color(0xFFF5EEDB),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: theme.colorScheme.secondary, width: 2),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2.0)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextSpan _highlightItem(String boldPart, String normalPart) {
    return TextSpan(
      children: [
        TextSpan(text: boldPart, style: const TextStyle(fontWeight: FontWeight.w900)),
        TextSpan(text: normalPart, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildInstructionSection(ThemeData theme, String title, List<TextSpan> bulletPoints) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceTint.withOpacity(0.1),
              border: Border(left: BorderSide(color: theme.colorScheme.secondary, width: 4)),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'serif',
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...bulletPoints.map((span) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0, left: 8.0, right: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: theme.colorScheme.secondary, fontSize: 18, fontWeight: FontWeight.bold)),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [span],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gs = context.watch<GameService>();

    // If we're already in a room
    if (gs.gameState != null && gs.currentPlayer != null) {
      if (gs.gameState!.currentPhase != GamePhase.lobby) {
        if (!_isNavigating) {
          _isNavigating = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final targetRoute = GameState.getRouteForPhase(gs.gameState!.currentPhase);
            Navigator.pushReplacementNamed(context, targetRoute);
          });
        }
        return const SizedBox.shrink();
      } else {
        _isNavigating = false;
      }
      return AnimatedLobbyBackground(child: _buildWaitingRoom(theme, gs));
    }

    return AnimatedLobbyBackground(child: _buildEntryForm(theme));
  }

  Widget _buildWaitingRoom(ThemeData theme, GameService gs) {
    final isHost = gs.currentPlayer!.isHost;
    final players = gs.players;

    final currentIds = players.map((p) => p.id).toSet();
    final newPlayers = players.where((p) => !_knownPlayerIds.contains(p.id)).toList();
    if (newPlayers.isNotEmpty && _knownPlayerIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var p in newPlayers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${p.name} has joined the lobby.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    }
    if (_knownPlayerIds.length != currentIds.length) {
      _knownPlayerIds = currentIds;
    }

    final availableDecks = PromptDecks.availableDecks.where((d) {
      if (_familyFriendlyOnly) {
        return d != 'rated_r_nsfw' && d != 'cah_dark_humor';
      }
      return true;
    }).toList();
    
    if (!availableDecks.contains(_selectedDeck)) {
      _selectedDeck = availableDecks.first;
    }

    final activeCount = players.where((p) => p.role != PlayerRole.spectator).length;
    final rounds = gs.gameState?.sabotageAnswersCount ?? 2;
    final deckSize = PromptDecks.getDeckSize(_selectedDeck);
    
    String? startWarning;
    if (activeCount < 2) {
      startWarning = "Need at least 2 active players to start.";
    } else if (activeCount <= rounds) {
      startWarning = "Need more players than forgery rounds ($rounds).";
    } else if (deckSize < activeCount) {
      startWarning = "Deck too small: selected deck has $deckSize prompts but you have $activeCount active players.";
    }

    final playingPlayers = players.where((p) => p.role != PlayerRole.spectator).toList();
    final nonHostPlayers = playingPlayers.where((p) => !p.isHost).toList();
    final readyNonHostsCount = nonHostPlayers.where((p) => p.lobbyReady).length;
    final totalNonHostsCount = nonHostPlayers.length;
    final allNonHostsReady = totalNonHostsCount > 0 && readyNonHostsCount == totalNonHostsCount;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('ROOM: ${gs.gameState!.roomCode}', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 4)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'WAITING FOR CREW...',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.secondary, // Gold
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${players.length} Joined ($readyNonHostsCount/$totalNonHostsCount Ready)',
              style: const TextStyle(fontSize: 18, color: Colors.white70, fontFamily: 'Lora'),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 32,
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return TweenAnimationBuilder<double>(
                    key: ValueKey(player.id),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Opacity(opacity: scale.clamp(0.0, 1.0), child: child),
                      );
                    },
                    child: PlayerAvatar(player: player),
                  );
                },
              ),
            ),
            if (isHost) ...[
              const SizedBox(height: 16),
              CrimsonShadowCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOUSE RULES',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Forgery Rounds:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ivory),
                        ),
                        Row(
                          children: [1, 2, 3, 4].map((r) {
                            final isSelected = rounds == r;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text('$r'),
                                selected: isSelected,
                                selectedColor: AppColors.brass,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppColors.ink : AppColors.ivory,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    gs.updateLobbySettings(sabotageAnswersCount: r);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: const Text(
                          'Disable Game Timers',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ivory, fontSize: 14),
                        ),
                        value: gs.gameState?.isTimerDisabled ?? false,
                        activeColor: AppColors.brass,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          gs.updateLobbySettings(isTimerDisabled: val);
                        },
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        title: const Text(
                          'Family-Friendly Decks Only',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ivory, fontSize: 14),
                        ),
                        value: _familyFriendlyOnly,
                        activeColor: AppColors.brass,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() {
                            _familyFriendlyOnly = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Prompt Deck:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ivory),
                        ),
                        DropdownButton<String>(
                          value: _selectedDeck,
                          dropdownColor: AppColors.groundRaised,
                          style: const TextStyle(color: AppColors.brass, fontWeight: FontWeight.bold),
                          items: availableDecks.map((deckId) {
                            return DropdownMenuItem(
                              value: deckId,
                              child: Text(PromptDecks.getDeckName(deckId)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDeck = val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (players.length < 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextButton(
                    onPressed: () => gs.debugAddBots(),
                    child: const Text('DEBUG: ADD 9 BOTS', style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ),
                ),

              if (startWarning != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    startWarning,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              Container(
                decoration: allNonHostsReady && startWarning == null
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brass.withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: 1,
                          )
                        ],
                      )
                    : null,
                child: PrimaryButton(
                  text: 'START GAME',
                  onPressed: startWarning == null ? () async {
                    try {
                      await gs.startGame(_selectedDeck);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                        );
                      }
                    }
                  } : null,
                ),
              ),
            ],
            if (!isHost) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: PrimaryButton(
                  text: gs.currentPlayer?.lobbyReady == true ? 'NOT READY' : "I'M READY",
                  onPressed: () => gs.toggleLobbyReady(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for Host to start...',
                style: TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.secondary),
              ),
            ]
          ],
        ),
      ),
    );
  }  Widget _buildEntryForm(ThemeData theme) {
    final ivoryColor = const Color(0xFFF5EEDB);
    final crimsonColor = theme.colorScheme.primary; // Burgundy/Crimson accent
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AnimatedLobbyLogo(),
                      const SizedBox(height: 40),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: CrimsonShadowCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'CREW STATION',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: crimsonColor,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  fontFamily: 'serif',
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextField(
                                controller: _nameController,
                                style: TextStyle(color: ivoryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: 'Your Name *',
                                  errorText: _nameError ? 'Please enter a name first' : null,
                                  labelStyle: TextStyle(color: ivoryColor.withOpacity(0.7), fontWeight: FontWeight.bold),
                                  errorStyle: const TextStyle(fontWeight: FontWeight.bold),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor.withOpacity(0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.5),
                                  prefixIcon: Icon(Icons.person, color: crimsonColor.withOpacity(0.8)),
                                ),
                                onChanged: (_) {
                                  if (_nameError) setState(() => _nameError = false);
                                },
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<int>(
                                value: _selectedRounds,
                                style: TextStyle(color: ivoryColor, fontWeight: FontWeight.bold, fontFamily: 'serif', fontSize: 16),
                                decoration: InputDecoration(
                                  labelText: 'Number of Rounds',
                                  labelStyle: TextStyle(color: ivoryColor.withOpacity(0.7), fontWeight: FontWeight.bold),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor.withOpacity(0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.5),
                                  prefixIcon: Icon(Icons.loop, color: crimsonColor.withOpacity(0.8)),
                                ),
                                dropdownColor: const Color(0xFF161C19),
                                items: [1, 2, 3, 4, 5].map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value Round${value > 1 ? 's' : ''}', style: TextStyle(color: ivoryColor)),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedRounds = newValue;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: crimsonColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.timer_off, color: crimsonColor.withOpacity(0.8), size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Disable Game Timers',
                                              style: TextStyle(color: ivoryColor, fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isTimerDisabled,
                                      activeColor: crimsonColor,
                                      activeTrackColor: crimsonColor.withOpacity(0.4),
                                      inactiveThumbColor: Colors.grey,
                                      inactiveTrackColor: Colors.grey.withOpacity(0.3),
                                      onChanged: (val) {
                                        setState(() {
                                          _isTimerDisabled = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Select Character Token',
                                style: TextStyle(color: crimsonColor, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: List.generate(PlayerAvatar.thematicIcons.length, (index) {
                                  final isSelected = _selectedAvatarIndex == index;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedAvatarIndex = index),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      transform: Matrix4.identity()..scale(isSelected ? 1.15 : 1.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? crimsonColor : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: isSelected ? [
                                          BoxShadow(color: crimsonColor.withOpacity(0.5), blurRadius: 10, spreadRadius: 1.5)
                                        ] : null,
                                      ),
                                      child: Opacity(
                                        opacity: isSelected ? 1.0 : 0.4,
                                        child: PlayerAvatar.buildChip(
                                          colorValue: isSelected ? crimsonColor.value : Colors.grey.shade700.value,
                                          avatarIndex: index,
                                          size: 46,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 30),
                              PrimaryButton(
                                text: 'CREATE ROOM',
                                onPressed: _createRoom,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: Divider(color: crimsonColor.withOpacity(0.3), thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: ivoryColor.withOpacity(0.6), letterSpacing: 2),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: crimsonColor.withOpacity(0.3), thickness: 1)),
                                  ],
                                ),
                              ),
                              TextField(
                                controller: _roomCodeController,
                                style: TextStyle(color: ivoryColor, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 18),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Room Code (4 Letters)',
                                  labelStyle: TextStyle(color: ivoryColor.withOpacity(0.7), fontWeight: FontWeight.bold, letterSpacing: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor.withOpacity(0.4)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: crimsonColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.5),
                                  prefixIcon: Icon(Icons.vpn_key, color: crimsonColor.withOpacity(0.8)),
                                  counterText: '',
                                ),
                                textCapitalization: TextCapitalization.characters,
                                maxLength: 4,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.tertiary, // Emerald
                                  foregroundColor: ivoryColor, // Ivory Text
                                  minimumSize: const Size(double.infinity, 58),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: crimsonColor.withOpacity(0.4), width: 1.5), // Crimson Border
                                  ),
                                  elevation: 6,
                                ),
                                onPressed: _joinRoom,
                                child: const Text('JOIN ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2.0)),
                              ),
                              const SizedBox(height: 18),
                              TextButton.icon(
                                onPressed: _showInstructions,
                                icon: Icon(Icons.menu_book, color: crimsonColor),
                                label: Text(
                                  'READ MANUAL',
                                  style: TextStyle(
                                    color: ivoryColor,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    decoration: TextDecoration.underline,
                                    decorationColor: ivoryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }
}
