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

    final activePlayers = players.where((p) => p.role != PlayerRole.spectator).toList();

    if (activePlayers.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine Superlatives by Metric Honors
    final sortedByScore = List<PlayerState>.from(activePlayers)..sort((a, b) => b.totalScore.compareTo(a.totalScore));
    final mastermind = sortedByScore.first;
    final Set<String> assignedIds = {mastermind.id};

    PlayerState? trickster;
    final remainingForTrickster = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForTrickster.isNotEmpty) {
      remainingForTrickster.sort((a, b) {
        final cmp = b.playersDeceived.compareTo(a.playersDeceived);
        if (cmp != 0) return cmp;
        return b.totalScore.compareTo(a.totalScore);
      });
      trickster = remainingForTrickster.first;
      assignedIds.add(trickster.id);
    }

    PlayerState? gullible;
    final remainingForGullible = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForGullible.isNotEmpty) {
      remainingForGullible.sort((a, b) {
        final cmp = b.timesFooled.compareTo(a.timesFooled);
        if (cmp != 0) return cmp;
        return a.totalScore.compareTo(b.totalScore); // Tie broken by lowest score
      });
      gullible = remainingForGullible.first;
      assignedIds.add(gullible.id);
    }

    PlayerState? runnerUp;
    final remainingForRunnerUp = activePlayers.where((p) => !assignedIds.contains(p.id)).toList();
    if (remainingForRunnerUp.isNotEmpty) {
      runnerUp = sortedByScore.firstWhere((p) => remainingForRunnerUp.any((rp) => rp.id == p.id));
      assignedIds.add(runnerUp.id);
    }

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
              _buildHonorCards(theme, mastermind, trickster, runnerUp, gullible),
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
                  final navigator = Navigator.of(context);
                  await gs.leaveRoom();
                  navigator.pushNamedAndRemoveUntil('/', (route) => false);
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

  Widget _buildHonorCards(
    ThemeData theme, 
    PlayerState mastermind, 
    PlayerState? trickster, 
    PlayerState? runnerUp, 
    PlayerState? gullible
  ) {
    List<Widget> cards = [];
    cards.add(_honorCard(theme, '🏆 The Mastermind', mastermind, theme.colorScheme.secondary));
    if (trickster != null) {
      cards.add(_honorCard(theme, '🃏 The Trickster', trickster, theme.colorScheme.tertiary));
    }
    if (runnerUp != null) {
      cards.add(_honorCard(theme, '🥈 Runner Up', runnerUp, Colors.grey.shade400));
    }
    if (gullible != null) {
      cards.add(_honorCard(theme, '🤡 Most Gullible', gullible, Colors.orange));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _honorCard(ThemeData theme, String title, PlayerState player, Color accentColor) {
    final ivoryColor = const Color(0xFFF5EEDB);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1C), // Deep charcoal background
        border: Border.all(color: accentColor, width: 2.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 12, spreadRadius: 1),
        ]
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerAvatar(player: player, size: 50, showName: false),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(player.name, style: TextStyle(color: ivoryColor, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'serif'), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('${player.totalScore} Pts', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
