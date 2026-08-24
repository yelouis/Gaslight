import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 Craft Screen Pre-check Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupAndPumpCraftScreen({
      required WidgetTester tester,
      required String localPlayerId,
      required GamePhase phase,
      required String truthAnswer,
      required Map<String, String> sabotageAnswers,
    }) async {
      final localPlayer = PlayerState(
        id: 'local_player_id',
        name: 'LocalPlayer',
        joinedAt: 100,
      );
      final guestPlayer = PlayerState(
        id: 'guest_id',
        name: 'GuestPlayer',
        joinedAt: 200,
      );

      final card = CardModel(
        targetPlayerId: 'guest_id',
        promptText: 'Is this real life?',
        truthAnswer: truthAnswer,
        sabotageAnswers: sabotageAnswers,
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: phase,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {
          'local_player_id': 'guest_id',
          'guest_id': 'local_player_id',
        },
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
        localPlayer.toMap()..['authUid'] = 'local_auth_uid',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(
        guestPlayer.toMap()..['authUid'] = 'guest_auth_uid',
      );

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', localPlayerId);
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

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
      await tester.pump(const Duration(milliseconds: 1000));
    }

    testWidgets('should block submission locally if answer is too similar to existing truth/sabotage answers', (WidgetTester tester) async {
      try {
        await setupAndPumpCraftScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          phase: GamePhase.forgery,
          truthAnswer: 'sleeping in my bed all day',
          sabotageAnswers: {
            'guest_id': 'playing video games',
          },
        );

        // Dismiss dealt card overlay first
        await tester.tap(find.text('INSPECT'));
        await tester.pump();

        // Find TextField and type a duplicate forgery
        final txtFinder = find.byType(TextField);
        expect(txtFinder, findsOneWidget);
        await tester.enterText(txtFinder, 'sleep all day in bed');
        await tester.pump();

        // Tap submit
        final submitFinder = find.text('SUBMIT DOSSIER');
        expect(submitFinder, findsOneWidget);
        await tester.tap(submitFinder);
        await tester.pump(const Duration(milliseconds: 500));

        // Verify SnackBar was displayed with correct message
        expect(find.text('Too similar to an existing answer! Be more creative.'), findsOneWidget);

        // Verify no write was executed on the db (cards remain unchanged)
        final doc = await mockDb.collection('rooms').doc('TEST').get();
        final state = GameState.fromMap(doc.data()!, 'TEST');
        expect(state.cards[0].sabotageAnswers['local_player_id'], isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('should allow submission if answer is unique', (WidgetTester tester) async {
      try {
        await setupAndPumpCraftScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          phase: GamePhase.forgery,
          truthAnswer: 'sleeping in my bed all day',
          sabotageAnswers: {
            'guest_id': 'playing video games',
          },
        );

        // Dismiss dealt card overlay first
        await tester.tap(find.text('INSPECT'));
        await tester.pump();

        // Find TextField and type a distinct forgery
        final txtFinder = find.byType(TextField);
        expect(txtFinder, findsOneWidget);
        await tester.enterText(txtFinder, 'cooking delicious pasta');
        await tester.pump();

        // Tap submit
        final submitFinder = find.text('SUBMIT DOSSIER');
        expect(submitFinder, findsOneWidget);
        await tester.tap(submitFinder);
        await tester.pump(const Duration(milliseconds: 500));

        // Verify SnackBar NOT displayed
        expect(find.text('Too similar to an existing answer! Be more creative.'), findsNothing);

        // Verify sabotage answer was successfully recorded
        final doc = await mockDb.collection('rooms').doc('TEST').get();
        final state = GameState.fromMap(doc.data()!, 'TEST');
        expect(state.cards[0].sabotageAnswers['local_player_id'], 'cooking delicious pasta');
      } finally {
        gameService.dispose();
      }
    });

    // The cap is checked at submit, not by capping the field: a player may
    // write as much as they like and is told plainly when it will not fit.
    // Falsified by removing the guard — submitAnswer was then invoked and no
    // SnackBar appeared.
    testWidgets('warns and blocks submission when the answer exceeds 100 characters', (WidgetTester tester) async {
      final fakeFunctions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: fakeFunctions);

      try {
      await setupAndPumpCraftScreen(
        tester: tester,
        localPlayerId: 'local_player_id',
        phase: GamePhase.forgery,
        truthAnswer: 'sleeping in my bed all day',
        sabotageAnswers: const {},
      );

      await tester.tap(find.text('INSPECT'));
      await tester.pump();

      final tooLong = 'z' * 120;
      await tester.enterText(find.byType(TextField), tooLong);
      await tester.pump();

      await tester.tap(find.text('SUBMIT DOSSIER'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.text('That is 120 characters. Trim it to 100 or fewer so it fits on the card.'),
        findsOneWidget,
        reason: 'the player must be told why the card will not submit',
      );
      expect(
        fakeFunctions.callableInvocations['submitAnswer'] ?? 0,
        0,
        reason: 'an over-length answer must never reach the server',
      );

      // Trimming to the bound lets it through.
      await tester.enterText(find.byType(TextField), 'z' * 100);
      await tester.pump();
      await tester.tap(find.text('SUBMIT DOSSIER'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(fakeFunctions.callableInvocations['submitAnswer'] ?? 0, 1);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('should render pinned target header and underline input fields correctly', (WidgetTester tester) async {
      try {
        await setupAndPumpCraftScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          phase: GamePhase.forgery,
          truthAnswer: 'sleeping in my bed all day',
          sabotageAnswers: {},
        );

        // Dismiss dealt card overlay first
        await tester.tap(find.text('INSPECT'));
        await tester.pump();

        // 1. Verify pinned target name is visible and styled in CormorantGaramond
        final targetText = find.text('GUESTPLAYER');
        expect(targetText, findsOneWidget);
        final textStyle = tester.widget<Text>(targetText).style;
        expect(textStyle?.fontFamily, 'CormorantGaramond');
        expect(textStyle?.fontSize, 22);

        // 2. Verify TextField is styled with Lora 18 and UnderlineInputBorder
        final txtFinder = find.byType(TextField);
        expect(txtFinder, findsOneWidget);
        final txtWidget = tester.widget<TextField>(txtFinder);
        expect(txtWidget.style?.fontFamily, 'Lora');
        expect(txtWidget.style?.fontSize, 18);
        expect(txtWidget.decoration?.enabledBorder, isA<UnderlineInputBorder>());
        expect(txtWidget.decoration?.hintText, 'Dip the quill…');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('shows error SnackBar with "No more prompts left in this deck." when reroll throws resource-exhausted (Issue 88.1)', (WidgetTester tester) async {
      try {
        final fakeFunctions = FakeFirebaseFunctions(mockDb);
        fakeFunctions.overrideCallable('rerollPrompt', (params) async {
          throw FirebaseFunctionsException(
            message: 'No more prompts left in this deck.',
            code: 'resource-exhausted',
          );
        });
        gameService = GameService(db: mockDb, functions: fakeFunctions);

        final localPlayer = PlayerState(
          id: 'local_player_id',
          name: 'LocalPlayer',
          joinedAt: 100,
        );
        final card = CardModel(
          targetPlayerId: 'local_player_id',
          promptText: 'Original Prompt',
          truthAnswer: '',
          sabotageAnswers: {},
        );

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.truth,
          totalPlayers: 1,
          cards: [card],
          currentCardAssignments: {
            'local_player_id': 'local_player_id',
          },
          readyPlayers: {},
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
          localPlayer.toMap()..['authUid'] = 'local_auth_uid',
        );

        gameService.listenToRoom('TEST');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'local_player_id');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;

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

        // Dismiss dealt overlay
        await tester.tap(find.text('DISMISS'));
        await tester.pump(const Duration(milliseconds: 300));

        // Tap RE-ROLL PROMPT
        expect(find.text('RE-ROLL PROMPT'), findsOneWidget);
        await tester.tap(find.text('RE-ROLL PROMPT'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify SnackBar with exact exhaustion message
        expect(find.text('No more prompts left in this deck.'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });
  });
}
