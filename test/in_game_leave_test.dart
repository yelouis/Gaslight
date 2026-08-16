import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/widgets/auto_advance_timer.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('In-Game Leave Control Widget Tests (Issue 85)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(
      id: 'p_host',
      name: 'Alice',
      isHost: true,
      joinedAt: 100,
      lobbyReady: true,
    );

    final p2 = PlayerState(
      id: 'p_g1',
      name: 'Bob',
      isHost: false,
      joinedAt: 200,
      lobbyReady: true,
    );

    final p3 = PlayerState(
      id: 'p_g2',
      name: 'Charlie',
      isHost: false,
      joinedAt: 300,
      lobbyReady: true,
    );

    final card1 = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'What is your secret?',
      truthAnswer: 'I love cats',
    );

    final card2 = CardModel(
      targetPlayerId: 'p_g1',
      promptText: 'What is your hobby?',
      truthAnswer: 'Chess',
    );

    final card3 = CardModel(
      targetPlayerId: 'p_g2',
      promptText: 'What is your fear?',
      truthAnswer: 'Spiders',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('Phase2CraftScreen renders leave button and confirms leave on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final craftState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentCardAssignments: {'p_host': 'p_host', 'p_g1': 'p_g1', 'p_g2': 'p_g2'},
      );

      gameService.debugSetState(craftState, [p1, p2, p3], 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(
        find.text('Your card and answers will be removed from this round. You cannot rejoin a game in progress.'),
        findsOneWidget,
      );
      expect(find.text('STAY'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);

      await tester.tap(find.text('LEAVE GAME'));
      await tester.pump(const Duration(milliseconds: 300));

      // State is cleared on leave
      expect(gameService.gameState, isNull);
    });

    testWidgets('Phase3VoteScreen renders leave button and confirms leave on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final voteState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );

      gameService.debugSetState(voteState, [p1, p2, p3], 'p_g1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase3VoteScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);

      await tester.tap(find.text('LEAVE GAME'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(gameService.gameState, isNull);
    });

    testWidgets('Phase4RevealScreen renders leave button and confirms leave on tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final revealState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );

      gameService.debugSetState(revealState, [p1, p2, p3], 'p_g2');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase4RevealScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);

      await tester.tap(find.text('LEAVE GAME'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(gameService.gameState, isNull);
    });

    testWidgets('Phase2CraftScreen renders leave button when isTimerDisabled is true (Issue 88.2)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final craftState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        isTimerDisabled: true,
        cards: [card1, card2, card3],
        currentCardAssignments: {'p_host': 'p_host', 'p_g1': 'p_g1', 'p_g2': 'p_g2'},
      );

      gameService.debugSetState(craftState, [p1, p2, p3], 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);
      expect(find.byType(AutoAdvanceTimer), findsNothing);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);
    });

    testWidgets('Phase3VoteScreen renders leave button when isTimerDisabled is true (Issue 88.2)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final voteState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        isTimerDisabled: true,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );

      gameService.debugSetState(voteState, [p1, p2, p3], 'p_g1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase3VoteScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);
      expect(find.byType(AutoAdvanceTimer), findsNothing);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);
    });

    testWidgets('Phase4RevealScreen renders leave button when isTimerDisabled is true (Issue 88.2)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      final revealState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        isTimerDisabled: true,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );

      gameService.debugSetState(revealState, [p1, p2, p3], 'p_g2');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase4RevealScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final leaveButton = find.byTooltip('Leave game');
      expect(leaveButton, findsOneWidget);
      expect(find.byType(AutoAdvanceTimer), findsNothing);

      await tester.tap(leaveButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Leave this game?'), findsOneWidget);
      expect(find.text('LEAVE GAME'), findsOneWidget);
    });
  });
}
