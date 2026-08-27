import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('O5: Room code visibility across in-game phases', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('Phase 2 Craft screen displays ROOM: ABCD in AppBar', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final card = CardModel(promptText: 'A prompt', targetPlayerId: 'p1');
      final gameState = GameState(
        roomCode: 'ABCD',
        currentPhase: GamePhase.truth,
        totalPlayers: 1,
        cards: [card],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('ABCD').set(gameState.toMap());
      await mockDb.collection('rooms').doc('ABCD').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');

      gameService.listenToRoom('ABCD');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'ABCD');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(home: Phase2CraftScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('ROOM: ABCD'), findsOneWidget);
      await gameService.leaveRoom();
    });

    testWidgets('Phase 3 Vote screen displays ROOM: ABCD in AppBar', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final card = CardModel(promptText: 'A prompt', targetPlayerId: 'p1');
      final gameState = GameState(
        roomCode: 'ABCD',
        currentPhase: GamePhase.vote,
        totalPlayers: 1,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('ABCD').set(gameState.toMap());
      await mockDb.collection('rooms').doc('ABCD').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');

      gameService.listenToRoom('ABCD');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'ABCD');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(home: Phase3VoteScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('ROOM: ABCD'), findsOneWidget);
      await gameService.leaveRoom();
    });

    testWidgets('Phase 4 Reveal screen displays ROOM: ABCD in AppBar', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final card = CardModel(promptText: 'A prompt', targetPlayerId: 'p1', scoreDeltas: {'p1': 3});
      final gameState = GameState(
        roomCode: 'ABCD',
        currentPhase: GamePhase.reveal,
        totalPlayers: 1,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('ABCD').set(gameState.toMap());
      await mockDb.collection('rooms').doc('ABCD').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');

      gameService.listenToRoom('ABCD');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'ABCD');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(home: Phase4RevealScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('ROOM: ABCD'), findsOneWidget);
      await gameService.leaveRoom();
    });
  });
}
