import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';

class Phase1SabotageScreen extends StatelessWidget {
  const Phase1SabotageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameService = context.watch<GameService>();
    final gameState = gameService.gameState;

    return Scaffold(
      appBar: AppBar(title: Text('Sabotage Phase')),
      body: Center(
        child: Text('WIP: Phase 4 UI Overhaul Pending\nRoom: ${gameState?.roomCode}'),
      ),
    );
  }
}
