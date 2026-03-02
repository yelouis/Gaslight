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
      await gameService.createRoom(name, playerId, totalRounds: _selectedRounds, avatarIndex: _selectedAvatarIndex);
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
