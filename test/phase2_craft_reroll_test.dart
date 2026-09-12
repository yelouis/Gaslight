import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AC4: Re-roll Cap and Chooser Tests', () {
    late FakeFirestore db;
    late FakeFirebaseFunctions fakeFunctions;

    setUp(() {
      db = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(db);
    });

    Widget createTestApp(GameService gs) {
      return ChangeNotifierProvider<GameService>.value(
        value: gs,
        child: const MaterialApp(
          home: Scaffold(
            body: Phase2CraftScreen(),
          ),
        ),
      );
    }

    testWidgets('shows (3 LEFT), (2 LEFT), (1 LEFT) based on rerollsThisRound', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final me = PlayerState(
        id: 'p_me',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_me',
        promptText: 'Original Prompt',
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        sabotageAnswersCount: 1,
        isTimerDisabled: true,
        selectedDeckId: 'cah_dark_humor',
        currentRotationIndex: 0,
        cards: [card],
        currentCardAssignments: {'p_me': 'p_me'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_me'],
      );

      final gameService = GameService(db: db, functions: fakeFunctions);
      gameService.debugSetState(gameState, [me], me.id);

      // Initially 0 spent -> 3 LEFT
      await tester.pumpWidget(createTestApp(gameService));
      await tester.pump();

      expect(find.text('RE-ROLL PROMPT'), findsOneWidget);
      expect(find.text(' (3 LEFT)'), findsOneWidget);
      final btn3 = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton)),
      );
      expect(btn3.onPressed, isNotNull);

      // 1 spent -> 2 LEFT
      gameService.debugSetRerolls(count: 1, candidates: ['Candidate 1']);
      await tester.pump();
      expect(find.text(' (2 LEFT)'), findsOneWidget);

      // 2 spent -> 1 LEFT
      gameService.debugSetRerolls(count: 2, candidates: ['Candidate 1', 'Candidate 2']);
      await tester.pump();
      expect(find.text(' (1 LEFT)'), findsOneWidget);
    });

    testWidgets('at 0 LEFT, button disables and chooser appears with candidates', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final me = PlayerState(
        id: 'p_me',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_me',
        promptText: 'Candidate 3',
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        sabotageAnswersCount: 1,
        isTimerDisabled: true,
        selectedDeckId: 'cah_dark_humor',
        currentRotationIndex: 0,
        cards: [card],
        currentCardAssignments: {'p_me': 'p_me'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_me'],
      );

      final gameService = GameService(db: db, functions: fakeFunctions);
      gameService.debugSetState(gameState, [me], me.id);
      gameService.debugSetRerolls(
        count: 3,
        candidates: ['Candidate 1', 'Candidate 2', 'Candidate 3'],
      );

      await tester.pumpWidget(createTestApp(gameService));
      await tester.pump();

      expect(find.text('RE-ROLL PROMPT'), findsOneWidget);
      expect(find.text(' (0 LEFT)'), findsOneWidget);

      final btn0 = tester.widget<ElevatedButton>(
        find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton)),
      );
      expect(btn0.onPressed, isNull);

      // Chooser header appears
      expect(find.text('SELECT A PROMPT'), findsOneWidget);
      expect(find.text('Candidate 1'), findsOneWidget);
      expect(find.text('Candidate 2'), findsOneWidget);
      // Candidate 3 is in dossier and in chooser
      expect(find.text('Candidate 3'), findsNWidgets(2));

      // Active prompt Candidate 3 has check_circle
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));
    });

    testWidgets('choosing a candidate updates displayed prompt in case dossier', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final me = PlayerState(
        id: 'p_me',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_me',
        promptText: 'Candidate 3',
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        sabotageAnswersCount: 1,
        isTimerDisabled: true,
        selectedDeckId: 'cah_dark_humor',
        currentRotationIndex: 0,
        cards: [card],
        currentCardAssignments: {'p_me': 'p_me'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_me'],
      );

      // Populate Firestore room state so fakeFunctions selectRerolledPrompt can mutate it
      await db.collection('rooms').doc('TEST').set(gameState.toMap());
      await db.collection('rooms').doc('TEST').collection('players').doc('p_me').set(me.toMap());
      await db.collection('rooms').doc('TEST').collection('sealed').doc('p_me').set({
        'seenPrompts': ['Candidate 1', 'Candidate 2', 'Candidate 3'],
        'rerollsThisRound': 3,
        'rerollCandidates': ['Candidate 1', 'Candidate 2', 'Candidate 3'],
      });

      final gameService = GameService(db: db, functions: fakeFunctions);
      try {
        gameService.debugSetState(gameState, [me], me.id);
        gameService.debugSetRerolls(
          count: 3,
          candidates: ['Candidate 1', 'Candidate 2', 'Candidate 3'],
        );

        // Listen to room to receive live updates from db
        gameService.listenToRoom('TEST');

        await tester.pumpWidget(createTestApp(gameService));
        await tester.pump();

        // Currently dossier shows Candidate 3
        expect(find.text('Candidate 3'), findsNWidgets(2)); // in dossier and in chooser

        // Ensure Candidate 1 is visible and tap it
        await tester.ensureVisible(find.text('Candidate 1'));
        await tester.tap(find.text('Candidate 1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(fakeFunctions.callableInvocations['selectRerolledPrompt'], 1);
        // SnackBar feedback
        expect(find.text('Prompt selected!'), findsOneWidget);

        // Dossier now displays Candidate 1 as the prompt
        expect(gameService.gameState?.cards.firstWhere((c) => c.targetPlayerId == 'p_me').promptText, 'Candidate 1');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('collision error removes candidate from chooser and shows specific message', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final me = PlayerState(
        id: 'p_me',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_me',
        promptText: 'Candidate 3',
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        sabotageAnswersCount: 1,
        isTimerDisabled: true,
        selectedDeckId: 'cah_dark_humor',
        currentRotationIndex: 0,
        cards: [card],
        currentCardAssignments: {'p_me': 'p_me'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_me'],
      );

      final gameService = GameService(db: db, functions: fakeFunctions);
      gameService.debugSetState(gameState, [me], me.id);
      gameService.debugSetRerolls(
        count: 3,
        candidates: ['Candidate 1', 'Candidate 2', 'Candidate 3'],
      );

      // Mock selectRerolledPrompt to throw collision failed-precondition
      fakeFunctions.overrideCallable('selectRerolledPrompt', (params) async {
        throw FirebaseFunctionsException(
          message: 'This prompt was claimed by another player.',
          code: 'failed-precondition',
        );
      });

      await tester.pumpWidget(createTestApp(gameService));
      await tester.pump();

      expect(find.text('Candidate 1'), findsOneWidget);

      // Tap Candidate 1
      await tester.ensureVisible(find.text('Candidate 1'));
      await tester.tap(find.text('Candidate 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Prompt was chosen by another player.'), findsOneWidget);
      // Candidate 1 is removed from chooser candidates
      expect(gameService.rerollCandidates.contains('Candidate 1'), isFalse);
      expect(find.text('Candidate 1'), findsNothing);
    });

    testWidgets('generic error shows generic message and retains candidate', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final me = PlayerState(
        id: 'p_me',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_me',
        promptText: 'Candidate 3',
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        sabotageAnswersCount: 1,
        isTimerDisabled: true,
        selectedDeckId: 'cah_dark_humor',
        currentRotationIndex: 0,
        cards: [card],
        currentCardAssignments: {'p_me': 'p_me'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_me'],
      );

      final gameService = GameService(db: db, functions: fakeFunctions);
      gameService.debugSetState(gameState, [me], me.id);
      gameService.debugSetRerolls(
        count: 3,
        candidates: ['Candidate 1', 'Candidate 2', 'Candidate 3'],
      );

      // Mock selectRerolledPrompt to throw generic error
      fakeFunctions.overrideCallable('selectRerolledPrompt', (params) async {
        throw FirebaseFunctionsException(
          message: 'Internal server error.',
          code: 'internal',
        );
      });

      await tester.pumpWidget(createTestApp(gameService));
      await tester.pump();

      // Tap Candidate 1
      await tester.ensureVisible(find.text('Candidate 1'));
      await tester.tap(find.text('Candidate 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(gameService.rerollCandidates.contains('Candidate 1'), isTrue);
      expect(find.text('Candidate 1'), findsOneWidget);
    });
  });
}
