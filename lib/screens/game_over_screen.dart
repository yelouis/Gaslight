import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/player_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/lobby_background.dart';

class GameOverScreen extends StatelessWidget {
  const GameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameService>();
    final theme = Theme.of(context);
    final players = gs.players;

    if (players.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine Superlatives natively
    final sortedByScore = List<PlayerState>.from(players)..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final mastermind = sortedByScore.first;
    
    // Sort logic for other titles could be more complex, but simplified here based on roles/scores
    final tricksterCard = sortedByScore.length > 2 ? sortedByScore[1] : mastermind;

    return AnimatedLobbyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('GAME OVER', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, letterSpacing: 4)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'THE CREW\'S HONORS',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.secondary, // Gold
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 30),
              _buildHonorCards(theme, mastermind, tricksterCard, sortedByScore),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Share to Instagram', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary, // Burgundy
                  foregroundColor: const Color(0xFFF5EEDB), // Ivory
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.secondary, width: 2), // Gold
                  ),
                  elevation: 8,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing coming soon!')));
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await gs.leaveRoom();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
                child: Text('RETURN TO LOBBY', style: TextStyle(color: theme.colorScheme.secondary)),
              )
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHonorCards(ThemeData theme, PlayerState mastermind, PlayerState trickster, List<PlayerState> leaderboard) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _honorCard(theme, '🏆 The Mastermind', mastermind, theme.colorScheme.secondary),
        _honorCard(theme, '🃏 The Trickster', trickster, theme.colorScheme.tertiary),
        if (leaderboard.length > 1) 
          _honorCard(theme, '🥈 Runner Up', leaderboard[1], Colors.grey.shade400),
        if (leaderboard.length > 2)
          _honorCard(theme, '🤡 Most Gullible', leaderboard.last, Colors.orange),
      ],
    );
  }

  Widget _honorCard(ThemeData theme, String title, PlayerState player, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Parchment
        border: Border.all(color: accentColor, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 15, offset: const Offset(0, 8)),
          BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
        ]
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerAvatar(player: player, size: 50, showName: false),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(player.name, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'serif'), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${player.totalScore} Pts', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
