import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/widgets/dealt_card_overlay.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 68: Re-roll Deck Exhaustion Client SnackBar Tests', () {
    late FakeFirestore db;
    late FakeFirebaseFunctions fakeFunctions;

    setUp(() {
      db = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(db);
    });

    testWidgets('shows "No more prompts left in this deck." on resource-exhausted error', (WidgetTester tester) async {
      final me = PlayerState(
        id: 'p_host',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_host',
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
        currentCardAssignments: {'p_host': 'p_host'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_host'],
      );

      final gameService = GameService(
        db: db,
        functions: fakeFunctions,
      );
      gameService.debugSetState(gameState, [me], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 640), accessibleNavigation: true),
              child: const Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      if (find.byType(DealtCardOverlay).evaluate().isNotEmpty) {
        await tester.tap(find.byType(DealtCardOverlay));
        await tester.pump(const Duration(milliseconds: 500));
      }

      final rerollBtn = find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton));
      expect(rerollBtn, findsOneWidget);

      // Inject mock callable behavior in fakeFunctions that throws resource-exhausted
      fakeFunctions.overrideCallable('rerollPrompt', (params) async {
        throw FirebaseFunctionsException(
          message: 'No more prompts left in this deck.',
          code: 'resource-exhausted',
        );
      });

      final buttonWidget = tester.widget<ElevatedButton>(rerollBtn);
      expect(buttonWidget.onPressed, isNotNull);
      buttonWidget.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(fakeFunctions.callableInvocations['rerollPrompt'], 1);

      // Assert specific copy is present
      expect(find.text('No more prompts left in this deck.'), findsOneWidget);
      // Assert generic fallback copy is NOT present
      expect(find.text('Something went wrong. Try again.'), findsNothing);
      // Assert no raw exception string is displayed
      expect(find.textContaining('FirebaseFunctionsException'), findsNothing);
      expect(find.textContaining('package:'), findsNothing);
    });

    testWidgets('shows "Something went wrong. Try again." on generic error', (WidgetTester tester) async {
      final me = PlayerState(
        id: 'p_host',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_host',
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
        currentCardAssignments: {'p_host': 'p_host'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_host'],
      );

      final gameService = GameService(
        db: db,
        functions: fakeFunctions,
      );
      gameService.debugSetState(gameState, [me], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 640), accessibleNavigation: true),
              child: const Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      if (find.byType(DealtCardOverlay).evaluate().isNotEmpty) {
        await tester.tap(find.byType(DealtCardOverlay), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 1500));
      }

      final rerollBtn = find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton));
      expect(rerollBtn, findsOneWidget);

      fakeFunctions.overrideCallable('rerollPrompt', (params) async {
        throw FirebaseFunctionsException(
          message: 'Internal server error occurred',
          code: 'internal',
        );
      });

      final buttonWidget2 = tester.widget<ElevatedButton>(rerollBtn);
      expect(buttonWidget2.onPressed, isNotNull);
      buttonWidget2.onPressed!();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Assert generic fallback copy is present
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      // Assert specific copy is NOT present
      expect(find.text('No more prompts left in this deck.'), findsNothing);
      // Assert no raw exception string is displayed
      expect(find.textContaining('Internal server error'), findsNothing);
      expect(find.textContaining('FirebaseFunctionsException'), findsNothing);
    });

    testWidgets('Issue 127 (P6): successive re-rolls clear previous snackbars and show exactly one SnackBar', (WidgetTester tester) async {
      final me = PlayerState(
        id: 'p_host',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_host',
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
        currentCardAssignments: {'p_host': 'p_host'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_host'],
      );

      final gameService = GameService(
        db: db,
        functions: fakeFunctions,
      );
      gameService.debugSetState(gameState, [me], me.id);

      fakeFunctions.overrideCallable('rerollPrompt', (params) async {
        return {'prompt': 'New Prompt ${DateTime.now().millisecondsSinceEpoch}'};
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(360, 640), accessibleNavigation: true),
              child: const Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      if (find.byType(DealtCardOverlay).evaluate().isNotEmpty) {
        await tester.tap(find.byType(DealtCardOverlay), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
      }

      final rerollBtn = find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton));
      expect(rerollBtn, findsOneWidget);

      // Tap re-roll 5 times in succession
      for (int i = 0; i < 5; i++) {
        final buttonWidget = tester.widget<ElevatedButton>(rerollBtn);
        expect(buttonWidget.onPressed, isNotNull);
        buttonWidget.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Assert exactly ONE SnackBar is in the tree
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Issue 127 (P6): cross-screen navigation clears snackbar queue after re-rolls', (WidgetTester tester) async {
      final me = PlayerState(
        id: 'p_host',
        name: 'Alice',
        totalScore: 0,
        role: PlayerRole.target,
        isHost: true,
        colorValue: 0,
        avatarIndex: 0,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );

      final card = CardModel(
        targetPlayerId: 'p_host',
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
        currentCardAssignments: {'p_host': 'p_host'},
        currentReaderId: null,
        rotationPlan: {},
        readyPlayers: {},
        endTime: null,
        resolutionOrder: ['p_host'],
      );

      final gameService = GameService(
        db: db,
        functions: fakeFunctions,
      );
      gameService.debugSetState(gameState, [me], me.id);

      fakeFunctions.overrideCallable('rerollPrompt', (params) async {
        return {'prompt': 'New Prompt'};
      });

      final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            home: Builder(
              builder: (context) => ElevatedButton(
                key: const ValueKey('nav_btn'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const Phase2CraftScreen()),
                  );
                },
                child: const Text('Go To Craft'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Navigate to Craft
      await tester.tap(find.byKey(const ValueKey('nav_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      if (find.byType(DealtCardOverlay).evaluate().isNotEmpty) {
        await tester.tap(find.byType(DealtCardOverlay), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 500));
      }

      final rerollBtn = find.ancestor(of: find.text('RE-ROLL PROMPT'), matching: find.byType(ElevatedButton));
      expect(rerollBtn, findsOneWidget);

      // Tap 3 times
      for (int i = 0; i < 3; i++) {
        final buttonWidget = tester.widget<ElevatedButton>(rerollBtn);
        buttonWidget.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(SnackBar), findsOneWidget);

      // Advance frames past the 1200ms duration and dismiss animation
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Assert zero SnackBars remain in tree
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
