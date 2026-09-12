import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/screens/game_over_screen.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Running Rivalries (Issue 165 / AB2)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> settleReveal(WidgetTester tester, int ms) async {
      final steps = ms ~/ 200;
      for (int i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('reveal timing: renders nothing before flip and rivalries after it', (WidgetTester tester) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final localPlayer = PlayerState(id: 'p1', name: 'Alice', joinedAt: 100);
        final p2 = PlayerState(id: 'p2', name: 'Bob', joinedAt: 200);
        final p3 = PlayerState(id: 'p3', name: 'Charlie', joinedAt: 300);

        final card = CardModel(
          targetPlayerId: 'p1',
          promptText: 'What is the secret?',
          truthAnswer: 'The real secret',
          sabotageAnswers: {'p2': 'A fake secret'},
          votes: {'p1': 'p2', 'p2': 'p1', 'p3': 'p2'},
        );

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'count': 2},
          ],
          'reads': [
            {'readerId': 'p1', 'readerName': 'Alice', 'forgerId': 'p2', 'forgerName': 'Bob', 'count': 1},
          ],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1'],
          unmaskDeadline: now + 15000,
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(localPlayer.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: MaterialApp(
              initialRoute: '/reveal',
              routes: {
                '/reveal': (context) => const Phase4RevealScreen(),
                '/': (context) => const Scaffold(body: Text('Root')),
              },
            ),
          ),
        );
        await tester.pump();

        // At stage 3 (unmask active, before flip): rivalries MUST NOT be rendered
        await settleReveal(tester, 4000);
        expect(find.text('THE PARLOUR REMEMBERS'), findsNothing);
        expect(find.text('Bob has fooled Alice ×2'), findsNothing);
        expect(find.text('Alice has read Bob ×1'), findsNothing);
        expect(find.text('CLOSEST READ'), findsNothing);

        // Advance past unmask deadline to stage 4 (after author flip)
        await settleReveal(tester, 14000);
        expect(find.text('THE PARLOUR REMEMBERS'), findsOneWidget);
        expect(find.text('Bob has fooled Alice ×2'), findsOneWidget);
        expect(find.text('Alice has read Bob ×1'), findsWidgets); // Appears in CLOSEST READ and list
        expect(find.text('CLOSEST READ'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('320 pt responsiveness: 3 fools and 3 reads render without overflow', (WidgetTester tester) async {
      try {
        final localPlayer = PlayerState(id: 'p1', name: 'Archibald Constantine', joinedAt: 100);
        final p2 = PlayerState(id: 'p2', name: 'Bartholomew Montgomery', joinedAt: 200);
        final p3 = PlayerState(id: 'p3', name: 'Cordelia Ravenscroft', joinedAt: 300);

        final card = CardModel(
          targetPlayerId: 'p1',
          promptText: 'What is the grand secret?',
          truthAnswer: 'The truth revealed',
          sabotageAnswers: {'p2': 'A grand deception'},
          votes: {'p1': 'p2', 'p2': 'p1'},
        );

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bartholomew Montgomery', 'victimId': 'p1', 'victimName': 'Archibald Constantine', 'count': 3},
            {'deceiverId': 'p3', 'deceiverName': 'Cordelia Ravenscroft', 'victimId': 'p2', 'victimName': 'Bartholomew Montgomery', 'count': 2},
            {'deceiverId': 'p1', 'deceiverName': 'Archibald Constantine', 'victimId': 'p3', 'victimName': 'Cordelia Ravenscroft', 'count': 1},
          ],
          'reads': [
            {'readerId': 'p1', 'readerName': 'Archibald Constantine', 'forgerId': 'p2', 'forgerName': 'Bartholomew Montgomery', 'count': 3},
            {'readerId': 'p2', 'readerName': 'Bartholomew Montgomery', 'forgerId': 'p3', 'forgerName': 'Cordelia Ravenscroft', 'count': 2},
            {'readerId': 'p3', 'readerName': 'Cordelia Ravenscroft', 'forgerId': 'p1', 'forgerName': 'Archibald Constantine', 'count': 1},
          ],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1'],
          unmaskDeadline: 0, // already flipped
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(localPlayer.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        // Strict 320 pt width
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: MaterialApp(
              initialRoute: '/reveal',
              routes: {
                '/reveal': (context) => const Phase4RevealScreen(),
                '/': (context) => const Scaffold(body: Text('Root')),
              },
            ),
          ),
        );
        await settleReveal(tester, 5000);

        expect(tester.takeException(), isNull);
        expect(find.text('THE PARLOUR REMEMBERS'), findsOneWidget);
        expect(find.text('CLOSEST READ'), findsOneWidget);
        expect(find.text('Bartholomew Montgomery has fooled Archibald Constantine ×3'), findsOneWidget);
        expect(find.text('Cordelia Ravenscroft has fooled Bartholomew Montgomery ×2'), findsOneWidget);
        expect(find.text('Archibald Constantine has fooled Cordelia Ravenscroft ×1'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('empty reads: CLOSEST READ is omitted when nobody has attributed anything', (WidgetTester tester) async {
      try {
        final localPlayer = PlayerState(id: 'p1', name: 'Alice', joinedAt: 100);
        final p2 = PlayerState(id: 'p2', name: 'Bob', joinedAt: 200);

        final card = CardModel(
          targetPlayerId: 'p1',
          promptText: 'What is the secret?',
          truthAnswer: 'The real secret',
          sabotageAnswers: {'p2': 'A fake secret'},
          votes: {'p1': 'p2', 'p2': 'p1'},
        );

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'count': 1},
          ],
          'reads': <Map<String, dynamic>>[],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 2,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true},
          resolutionOrder: ['p1'],
          unmaskDeadline: 0,
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(localPlayer.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: MaterialApp(
              initialRoute: '/reveal',
              routes: {
                '/reveal': (context) => const Phase4RevealScreen(),
                '/': (context) => const Scaffold(body: Text('Root')),
              },
            ),
          ),
        );
        await settleReveal(tester, 5000);

        expect(find.text('THE PARLOUR REMEMBERS'), findsOneWidget);
        expect(find.text('Bob has fooled Alice ×1'), findsOneWidget);
        expect(find.text('CLOSEST READ'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('game over screen: displays reads alongside headToHead in RIVALRIES container', (WidgetTester tester) async {
      try {
        final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 10, playersDeceived: 2, timesFooled: 1, role: PlayerRole.voter);
        final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 8, playersDeceived: 1, timesFooled: 2, role: PlayerRole.voter);

        final summaryPayload = <String, dynamic>{
          'bestLie': null,
          'cleanestTruth': null,
          'theSting': null,
          'headToHead': [
            {'deceiverName': 'Alice', 'victimName': 'Bob', 'count': 2},
          ],
        };

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p1', 'deceiverName': 'Alice', 'victimId': 'p2', 'victimName': 'Bob', 'count': 2},
          ],
          'reads': [
            {'readerId': 'p2', 'readerName': 'Bob', 'forgerId': 'p1', 'forgerName': 'Alice', 'count': 2},
          ],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.gameOver,
          totalPlayers: 2,
          cards: [],
          currentCardAssignments: {},
          readyPlayers: {},
          matchSummary: summaryPayload,
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: GameOverScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));

        expect(find.text('RIVALRIES'), findsOneWidget);
        expect(find.text('Alice fooled Bob 2 times'), findsOneWidget);
        expect(find.text('Bob has read Alice ×2'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });
  });
}
