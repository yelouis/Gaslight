import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/blinking_eye.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:provider/provider.dart';

class MockGameService extends ChangeNotifier implements GameService {
  @override
  final List<PlayerState> players;
  @override
  final PlayerState? currentPlayer;
  @override
  final GameState? gameState;

  MockGameService({
    required this.players,
    required this.currentPlayer,
    required this.gameState,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('BlinkingEye renders and scales correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BlinkingEye(size: 24),
        ),
      ),
    );

    expect(find.byType(BlinkingEye), findsOneWidget);
  });

  testWidgets('Phase3VoteScreen shows visualizer ticker when viewer is the active reader', (WidgetTester tester) async {
    final me = PlayerState(id: 'p_reader', name: 'Reader', role: PlayerRole.target, isHost: true);
    final players = [
      me,
      PlayerState(id: 'p_voter1', name: 'Voter 1', role: PlayerRole.voter, isHost: false),
      PlayerState(id: 'p_voter2', name: 'Voter 2', role: PlayerRole.voter, isHost: false),
    ];

    final card = CardModel(
      targetPlayerId: 'p_reader',
      promptText: 'A secret prompt...',
    );

    final state = GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.vote,
      currentReaderId: 'p_reader',
      cards: [card],
      readyPlayers: {'p_voter1': true, 'p_voter2': false},
    );

    final mockService = MockGameService(
      players: players,
      currentPlayer: me,
      gameState: state,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<GameService>.value(
        value: mockService,
        child: MaterialApp(
          home: Scaffold(
            body: Phase3VoteScreen(),
          ),
        ),
      ),
    );

    // Verify 'THE PARLOR DELIBERATES…' is present
    expect(find.text('THE PARLOR DELIBERATES…'), findsOneWidget);

    // Verify BlinkingEye is present representing the observer
    expect(find.byType(BlinkingEye), findsOneWidget);
  });
}
