import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/game_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';
import '../widgets/lobby_logo.dart';
import '../models/game_state.dart';
import '../widgets/shared_ui.dart';
import '../utils/prompt_decks.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gs = context.read<GameService>();
      final rejoining = await gs.tryRejoinSession();
      if (rejoining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejoined active game session!')),
        );
      }
    });
  }

  void _createRoom() async {
    final name = _nameController.text.trim();
    setState(() => _nameError = name.isEmpty);
    if (name.isEmpty) return;

    final gameService = context.read<GameService>();
    final playerId = const Uuid().v4();

    try {
      await gameService.createRoom(
        name,
        playerId,
        sabotageAnswersCount: _selectedRounds,
        avatarIndex: _selectedAvatarIndex,
        isTimerDisabled: _isTimerDisabled,
      );
    } catch (e) {
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
    final playerId = const Uuid().v4();

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
            Text('${players.length} Joined (4-8 Ideal)', style: const TextStyle(fontSize: 18, color: Colors.white70)),
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
                  return PlayerAvatar(player: players[index]);
                },
              ),
            ),
            if (isHost) ...[
              const SizedBox(height: 20),
              DropdownButton<String>(
                value: _selectedDeck,
                dropdownColor: theme.colorScheme.surface,
                style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                items: PromptDecks.availableDecks.map((deckId) {
                  return DropdownMenuItem(
                    value: deckId,
                    child: Text(PromptDecks.getDeckName(deckId)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDeck = val);
                },
              ),
              if (players.length < 10)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                  child: TextButton(
                    onPressed: () => gs.debugAddBots(),
                    child: const Text('DEBUG: ADD 9 BOTS', style: TextStyle(color: Colors.white24, fontSize: 10)),
                  ),
                ),
              PrimaryButton(
                text: 'START GAME',
                onPressed: players.isNotEmpty ? () {
                  gs.startGame(_selectedDeck);
                } : null,
              ),
            ],
            if (!isHost)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Waiting for Host to start...', style: TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.secondary)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildEntryForm(ThemeData theme) {
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
                      const SizedBox(height: 60),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: ParchmentCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Your Name * (Required)',
                        errorText: _nameError ? 'Please enter a name first' : null,
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5), // Semi-transparent over parchment
                      ),
                      onChanged: (_) {
                        if (_nameError) setState(() => _nameError = false);
                      },
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<int>(
                      value: _selectedRounds,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                      decoration: InputDecoration(
                        labelText: 'Number of Rounds',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                      ),
                      dropdownColor: theme.colorScheme.surface,
                      items: [1, 2, 3, 4, 5].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value Round${value > 1 ? 's' : ''}'),
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
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Disable Game Timers',
                          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isTimerDisabled,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (val) {
                            setState(() {
                              _isTimerDisabled = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Choose Your Token', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
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
                              boxShadow: isSelected ? [
                                BoxShadow(color: theme.colorScheme.primary.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                              ] : null,
                            ),
                            child: Opacity(
                              opacity: isSelected ? 1.0 : 0.5,
                              child: PlayerAvatar.buildChip(
                                colorValue: isSelected ? theme.colorScheme.primary.value : Colors.grey.shade600.value,
                                avatarIndex: index,
                                size: 50,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary, // Burgundy
                        foregroundColor: const Color(0xFFF5EEDB), // Ivory Text
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.colorScheme.secondary, width: 2), // Gold Border
                        ),
                        elevation: 8,
                      ),
                      onPressed: _createRoom,
                      child: const Text('CREATE ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text('OR', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    ),
                    TextField(
                      controller: _roomCodeController,
                      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, letterSpacing: 4),
                      decoration: InputDecoration(
                        labelText: 'Room Code (4 Letters)',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7), fontWeight: FontWeight.bold, letterSpacing: 0),
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.secondary.withOpacity(0.5))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 4,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.tertiary, // Emerald
                        foregroundColor: const Color(0xFFF5EEDB), // Ivory Text
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: theme.colorScheme.secondary, width: 2), // Gold Border
                        ),
                        elevation: 8,
                      ),
                      onPressed: _joinRoom,
                      child: const Text('JOIN ROOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 15),
                    TextButton.icon(
                      onPressed: _showInstructions,
                      icon: Icon(Icons.menu_book, color: theme.colorScheme.onSurface),
                      label: Text(
                        'Read Instructions',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ), // Close ConstrainedBox
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
