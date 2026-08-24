import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/game_over_screen.dart';
import 'package:gaslight/utils/case_file_saver.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameOverScreen Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupAndPumpGameOverScreen({
      required WidgetTester tester,
      bool reduceMotion = false,
    }) async {
      final mastermind = PlayerState(
        id: 'p1',
        name: 'MastermindAlice',
        totalScore: 40,
        playersDeceived: 5,
        timesFooled: 1,
        role: PlayerRole.voter,
      );
      final trickster = PlayerState(
        id: 'p2',
        name: 'TricksterBob',
        totalScore: 30,
        playersDeceived: 8,
        timesFooled: 2,
        role: PlayerRole.voter,
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 2,
        cards: [],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(
        mastermind.toMap()..['authUid'] = 'uid1',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(
        trickster.toMap()..['authUid'] = 'uid2',
      );

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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQueryData(accessibleNavigation: reduceMotion),
                child: child!,
              );
            },
            home: const GameOverScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
    }

    testWidgets('GameOverScreen renders EmberBackdrop and plaques correctly under normal motion', (WidgetTester tester) async {
      await setupAndPumpGameOverScreen(tester: tester, reduceMotion: false);

      // Verify page titles and layout elements
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('THE NIGHT\'S HONORS'), findsOneWidget);

      // Verify plaques are rendered
      expect(find.text('THE MASTERMIND'), findsOneWidget);
      expect(find.text('THE DUPLICITOUS'), findsOneWidget);
      expect(find.text('MastermindAlice'), findsOneWidget);
      expect(find.text('TricksterBob'), findsWidgets);

      // Verify EmberBackdrop exists
      expect(find.byType(EmberBackdrop), findsOneWidget);

      // Clean up heartbeat timer
      await gameService.leaveRoom();
    });

    testWidgets('GameOverScreen renders correctly in reduce motion mode', (WidgetTester tester) async {
      await setupAndPumpGameOverScreen(tester: tester, reduceMotion: true);

      expect(find.text('THE MASTERMIND'), findsOneWidget);
      expect(find.text('THE DUPLICITOUS'), findsOneWidget);
      expect(find.byType(EmberBackdrop), findsOneWidget);

      // Clean up heartbeat timer
      await gameService.leaveRoom();
    });

    testWidgets('GameOverScreen ceremony gates share button and handles staggers stepwise', (WidgetTester tester) async {
      final mastermind = PlayerState(
        id: 'p1',
        name: 'MastermindAlice',
        totalScore: 40,
        playersDeceived: 5,
        timesFooled: 1,
        role: PlayerRole.voter,
      );
      final trickster = PlayerState(
        id: 'p2',
        name: 'TricksterBob',
        totalScore: 30,
        playersDeceived: 8,
        timesFooled: 2,
        role: PlayerRole.voter,
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 2,
        cards: [],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(
        mastermind.toMap()..['authUid'] = 'uid1',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(
        trickster.toMap()..['authUid'] = 'uid2',
      );

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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: const MediaQueryData(accessibleNavigation: false),
                child: child!,
              );
            },
            home: const GameOverScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Engraving…'), findsOneWidget);
      expect(find.text('Share Case File'), findsNothing);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Engraving…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('Share Case File'), findsOneWidget);
      expect(find.text('Engraving…'), findsNothing);

      await gameService.leaveRoom();
    });

    testWidgets('GameOverScreen MF1: pins actions in bottom bar and is visible at 360x640 portrait without scrolling', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await setupAndPumpGameOverScreen(tester: tester, reduceMotion: true);

      // Verify Scaffold has a bottomNavigationBar containing the actions
      final Scaffold scaffold = tester.widget(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNotNull);

      // Verify buttons are visible and located inside the bottomNavigationBar
      final bottomBarFinder = find.byKey(const Key('game_over_bottom_bar'));
      expect(find.descendant(of: bottomBarFinder, matching: find.text('Share Case File')), findsOneWidget);
      expect(find.descendant(of: bottomBarFinder, matching: find.text('RETURN TO LOBBY')), findsOneWidget);

      // Ensure no layout exceptions or overflows
      expect(tester.takeException(), isNull);

      await gameService.leaveRoom();
    });

    testWidgets('Issue 111: GameOverScreen renders full standings for all active players with scores and stat lines', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 50, playersDeceived: 6, timesFooled: 1, role: PlayerRole.voter);
      final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 35, playersDeceived: 4, timesFooled: 3, role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', totalScore: 20, playersDeceived: 2, timesFooled: 4, role: PlayerRole.voter);
      final p4 = PlayerState(id: 'p4', name: 'Diana', totalScore: 10, playersDeceived: 1, timesFooled: 5, role: PlayerRole.voter);

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 4,
        cards: [],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p4').set(p4.toMap()..['authUid'] = 'uid4');

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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: const MediaQueryData(accessibleNavigation: true),
                child: child!,
              );
            },
            home: const GameOverScreen(),
          ),
        ),
      );
      await tester.pump();

      // Assert Standings header is present
      expect(find.text('FINAL STANDINGS'), findsOneWidget);

      // Assert all 4 players are rendered with their score and stats
      expect(find.text('Alice'), findsWidgets);
      expect(find.text('Bob'), findsWidgets);
      expect(find.text('Charlie'), findsWidgets);
      expect(find.text('Diana'), findsWidgets);

      expect(find.text('50 PTS'), findsWidgets);
      expect(find.text('35 PTS'), findsWidgets);
      expect(find.text('20 PTS'), findsWidgets);
      expect(find.text('10 PTS'), findsWidgets);

      expect(find.text('Fooled 6 · Fooled by 1'), findsOneWidget);
      expect(find.text('Fooled 4 · Fooled by 3'), findsOneWidget);
      expect(find.text('Fooled 2 · Fooled by 4'), findsOneWidget);
      expect(find.text('Fooled 1 · Fooled by 5'), findsOneWidget);

      await gameService.leaveRoom();
    });

    testWidgets('Issue 111: GameOverScreen renders match highlights when matchSummary is provided', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 50, playersDeceived: 6, timesFooled: 1, role: PlayerRole.voter);
      final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 35, playersDeceived: 4, timesFooled: 3, role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', totalScore: 20, playersDeceived: 2, timesFooled: 4, role: PlayerRole.voter);

      final summaryPayload = {
        'bestLie': {
          'authorId': 'p1',
          'authorName': 'Alice',
          'text': 'I saw the cat fly away',
          'promptText': 'What did you see?',
          'fooled': 2,
        },
        'cleanestTruth': {
          'targetPlayerId': 'p2',
          'targetPlayerName': 'Bob',
          'text': 'I ate cereal in the dark',
          'promptText': 'What was your secret dinner?',
          'foundCount': 0,
        },
        'theSting': {
          'targetPlayerId': 'p3',
          'promptText': 'Where did the jewels go?',
          'wrongVoteCount': 3,
        },
        'headToHead': [
          {
            'deceiverId': 'p1',
            'deceiverName': 'Alice',
            'victimId': 'p2',
            'victimName': 'Bob',
            'count': 3,
          }
        ],
      };

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.gameOver,
        totalPlayers: 3,
        cards: [],
        currentCardAssignments: {},
        readyPlayers: {},
        matchSummary: summaryPayload,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');

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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: const MediaQueryData(accessibleNavigation: true),
                child: child!,
              );
            },
            home: const GameOverScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify Match Highlights header and sections
      expect(find.text('MATCH HIGHLIGHTS'), findsOneWidget);
      expect(find.text('BEST LIE OF THE NIGHT'), findsOneWidget);
      expect(find.text('"I saw the cat fly away"'), findsOneWidget);
      expect(find.text('Fooled 2 players'), findsOneWidget);

      expect(find.text('CLEANEST TRUTH'), findsOneWidget);
      expect(find.text('"I ate cereal in the dark"'), findsOneWidget);
      expect(find.text('Found by only 0 players'), findsOneWidget);

      expect(find.text('THE STING'), findsOneWidget);
      expect(find.text('"Where did the jewels go?"'), findsOneWidget);
      expect(find.text('3 wrong votes'), findsOneWidget);

      expect(find.text('RIVALRIES'), findsOneWidget);
      expect(find.text('Alice fooled Bob 3 times'), findsOneWidget);

      await gameService.leaveRoom();
    });

    testWidgets('Issue 111: GameOverScreen degrades gracefully when matchSummary has all null awards', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 0, playersDeceived: 0, timesFooled: 0, role: PlayerRole.voter);
      final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 0, playersDeceived: 0, timesFooled: 0, role: PlayerRole.voter);

      final summaryPayload = <String, dynamic>{
        'bestLie': null,
        'cleanestTruth': null,
        'theSting': null,
        'headToHead': [],
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
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: const MediaQueryData(accessibleNavigation: true),
                child: child!,
              );
            },
            home: const GameOverScreen(),
          ),
        ),
      );
      await tester.pump();

      // Standings should render fine
      expect(find.text('FINAL STANDINGS'), findsOneWidget);
      // Highlights header should not appear if all awards are null
      expect(find.text('MATCH HIGHLIGHTS'), findsNothing);

      await gameService.leaveRoom();
    });

    test('case_file_saver_io throws UnsupportedError on non-web platforms', () {
      expect(
        () => saveCaseFilePng(Uint8List.fromList([1, 2, 3]), 'test.png'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    testWidgets('renders Share Case File action button after ceremony', (WidgetTester tester) async {
      await setupAndPumpGameOverScreen(tester: tester, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Share Case File'), findsOneWidget);
      await gameService.leaveRoom();
    });
  });
}
