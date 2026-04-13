import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/game_service.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';
import '../widgets/lobby_logo.dart';
import '../models/game_state.dart';
import '../widgets/shared_ui.dart';

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

  void _createRoom() async {
    final name = _nameController.text.trim();
    setState(() => _nameError = name.isEmpty);
    if (name.isEmpty) return;

    final gameService = context.read<GameService>();
    final playerId = const Uuid().v4();

    try {
      await gameService.createRoom(name, playerId, sabotageAnswersCount: _selectedRounds, avatarIndex: _selectedAvatarIndex);
      if (mounted) Navigator.pushReplacementNamed(context, '/draft');
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
      if (mounted) Navigator.pushReplacementNamed(context, '/draft');
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
                            '1. THE OBJECTIVE',
                            [
                              _highlightItem('The Asker: ', 'Secretly assigned a Target Number. Write a prompt that manipulates the Voters so EXACTLY that number of people choose their specified option.'),
                              _highlightItem('The Voters: ', 'Vote honestly on the prompt AND guess the Asker\'s Target Number.'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            '2. SETTING UP',
                            [
                              _highlightItem('Players: ', 'Best with 4–8 players.'),
                              _highlightItem('Phase 1 (The Bank): ', 'While waiting in the lobby, players write the first half of a binary question (e.g., "You get \$10 million, BUT...").'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            '3. ROUND-BY-ROUND',
                            [
                              _highlightItem('Step 1: The Craft ', '(Asker\'s Turn)\nOne player is chosen as the Asker and given a secret Target Number. They type the second half of a random prompt, trying to design it so exactly their Target Number of people will choose it.'),
                              _highlightItem('Step 2: The Choice ', '(Voters\' Turn)\nThe other players see the completed prompt. They must vote honestly. Immediately after voting, they guess what the Asker’s Target Number was.'),
                              _highlightItem('Step 3: The Reveal ', '\nThe votes are tallied, the Asker’s secret Target Number is revealed, and we see who successfully read their mind.'),
                            ],
                          ),
                          _buildInstructionSection(
                            theme,
                            '4. SCORING',
                            [
                              _highlightItem('Bullseye (+10 pts): ', 'Asker exactly hits their Target Number.'),
                              _highlightItem('Near Miss (+2 pts): ', 'Asker is off by exactly 1 vote.'),
                              _highlightItem('Exposed Penalty (-5 pts): ', 'If more than half of the Voters correctly guess the Target Number, the Asker loses points.'),
                              _highlightItem('Mind Reader (+5 pts): ', 'Voters who correctly guess the Asker\'s Target Number get points.'),
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
      if (gs.gameState!.currentPhase != GamePhase.lobby && !_isNavigating) {
        _isNavigating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/draft');
        });
        return const SizedBox.shrink();
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
            if (isHost)
              PrimaryButton(
                text: 'START GAME',
                onPressed: players.isNotEmpty ? () {
                  // Ready to start! Update state.
                  gs.updateGameState(gs.gameState!.copyWith(currentPhase: GamePhase.draft));
                } : null,
              ),
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
