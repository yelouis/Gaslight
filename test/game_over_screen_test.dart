import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/game_over_screen.dart';
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
      expect(find.text('TricksterBob'), findsOneWidget);

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
  });
}
