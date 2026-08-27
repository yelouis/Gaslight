import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/game_over_screen.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('O6: Badge pills flex and ellipsis on narrow devices (Issue 114)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('MATCH HIGHLIGHTS badges keep intrinsic size and do not overflow at 320px width', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 20);
      final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 10);

      final summaryPayload = {
        'bestLie': {
          'authorId': 'p1',
          'authorName': 'Alice',
          'text': 'A deceptive lie',
          'promptText': 'The prompt',
          'fooled': 2,
        },
        'cleanestTruth': {
          'targetPlayerId': 'p2',
          'targetPlayerName': 'Bob',
          'text': 'The truth',
          'promptText': 'The prompt',
          'foundCount': 0,
        },
        'theSting': {
          'targetPlayerId': 'p1',
          'promptText': 'The prompt',
          'wrongVoteCount': 4,
        },
      };

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 2,
        cards: [],
        currentCardAssignments: {},
        readyPlayers: {},
        matchSummary: summaryPayload,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: GameOverScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify badges are present and fully visible
      expect(find.text('Fooled 2 players'), findsOneWidget);
      expect(find.text('Found by only 0 players'), findsOneWidget);
      expect(find.text('4 wrong votes'), findsOneWidget);

      // Verify no RenderFlex overflow exceptions occurred
      expect(tester.takeException(), isNull);

      await gameService.leaveRoom();
    });

    testWidgets('Lobby custom prompts header keeps intrinsic pill width and does not overflow at 320px width', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true, customPrompts: ['Prompt 1']);
      final p2 = PlayerState(id: 'p2', name: 'Bob', customPrompts: ['Prompt 2']);

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        totalPlayers: 2,
        selectedDeckId: 'custom',
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: LobbyScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify lobby total pill is rendered
      expect(find.text('Lobby Total: 2/2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await gameService.leaveRoom();
    });
  });
}
