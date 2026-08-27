import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/widgets/table_departure_listener.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 128 (P7): Table Departure Notification Tests', () {
    late FakeFirestore db;
    late FakeFirebaseFunctions fakeFunctions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(db);
      gameService = GameService(db: db, functions: fakeFunctions);
    });

    tearDown(() {
      gameService.dispose();
    });

    test('Unit test: initial snapshot produces no departure messages regardless of player count', () {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', isHost: false);

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 3,
      );
      gameService.debugSetState(state, [], 'p1');

      // First snapshot after attaching
      gameService.processPlayersSnapshotForTesting([p1, p2, p3]);
      expect(gameService.consumeDepartureMessages(), isEmpty);
    });

    test('Unit test: diff detects departure (one id removed) and generates exact copy', () {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', isHost: false);

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 3,
      );
      gameService.debugSetState(state, [p1, p2, p3], 'p1');

      // First snapshot establishes initial list
      gameService.processPlayersSnapshotForTesting([p1, p2, p3]);
      expect(gameService.consumeDepartureMessages(), isEmpty);

      // Second snapshot: Bob (p2) is gone
      gameService.processPlayersSnapshotForTesting([p1, p3]);
      final messages = gameService.consumeDepartureMessages();
      expect(messages, equals(['Bob has left the parlour.']));

      // Consuming again clears messages
      expect(gameService.consumeDepartureMessages(), isEmpty);
    });

    test('Unit test: feeding the same list twice generates zero messages', () {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
      );
      gameService.debugSetState(state, [p1, p2], 'p1');

      gameService.processPlayersSnapshotForTesting([p1, p2]);
      expect(gameService.consumeDepartureMessages(), isEmpty);

      // Same list again
      gameService.processPlayersSnapshotForTesting([p1, p2]);
      expect(gameService.consumeDepartureMessages(), isEmpty);
    });

    test('Unit test: growing list (player joins) generates zero messages', () {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', isHost: false);

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
      );
      gameService.debugSetState(state, [p1, p2], 'p1');

      gameService.processPlayersSnapshotForTesting([p1, p2]);
      expect(gameService.consumeDepartureMessages(), isEmpty);

      // Growing list: Charlie joins
      gameService.processPlayersSnapshotForTesting([p1, p2, p3]);
      expect(gameService.consumeDepartureMessages(), isEmpty);
    });

    test('Unit test: departures are suppressed during lobby and gameOver phases', () {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);

      // Lobby phase
      final lobbyState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        totalPlayers: 2,
      );
      gameService.debugSetState(lobbyState, [p1, p2], 'p1');
      gameService.processPlayersSnapshotForTesting([p1, p2]);
      gameService.processPlayersSnapshotForTesting([p1]);
      expect(gameService.consumeDepartureMessages(), isEmpty);

      // GameOver phase
      final gameOverState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 2,
      );
      gameService.debugSetState(gameOverState, [p1, p2], 'p1');
      gameService.processPlayersSnapshotForTesting([p1, p2]);
      gameService.processPlayersSnapshotForTesting([p1]);
      expect(gameService.consumeDepartureMessages(), isEmpty);
    });

    testWidgets('Widget test: TableDepartureListener displays SnackBar with departed player name', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', isHost: false);

      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'A prompt about secrets',
      );

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
      );

      gameService.debugSetState(state, [p1, p2], 'p1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: TableDepartureListener(
              child: const Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Establish initial snapshot
      gameService.processPlayersSnapshotForTesting([p1, p2]);
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);

      // Bob leaves
      gameService.processPlayersSnapshotForTesting([p1]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Bob has left the parlour.'), findsOneWidget);
    });
  });
}
