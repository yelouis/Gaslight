import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'simulation_test.dart';
import 'fake_functions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gaslight UI E2E Widget Test', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('Standard Happy Path E2E Journey', (WidgetTester tester) async {
      print('--- STARTING UI E2E WIDGET TEST ---');

      // Resize virtual screen to fit all scrollable inputs
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Helper to pump multiple intermediate frames (every 50ms) to drive animations and navigation transitions
      Future<void> tick([int ms = 200]) async {
        final steps = (ms / 50).round();
        for (int i = 0; i < steps; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump();
      }



      // 1. Pump GaslightApp hydrated with mock game service
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const GaslightApp(),
        ),
      );
      await tick(200);

      // Verify entry screen
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);

      // 2. Input Host name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);

      // 3. Create room (creates with default 1 forgery round)
      await tester.tap(find.text('CREATE ROOM'));
      await tick(500); // Allow navigation to Lobby Wait room

      // Verify lobby screen
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;
      expect(find.text(rCode), findsOneWidget);
      expect(find.text('ASSEMBLING THE SUSPECTS…'), findsOneWidget);
      print('Room created: $rCode. Displaying Lobby Wait Screen.');

      // 4. Add bots and Start game
      await gameService.debugAddBots();
      await tick(300);
      expect(gameService.players.length, 10);

      // Start game
      await gameService.startGame('the_daily_grind');
      await tick(600); // Allow navigation transition animation to finish

      // 5. Verify transition to FORGERY phase
      expect(find.text('FORGERY'), findsOneWidget);
      expect(find.text('WRITE YOUR TRUTH'), findsNothing);
      print('Successfully transitioned to FORGERY phase.');

      // Submit forgery
      final inputField = find.byType(TextField).first;
      await tester.enterText(inputField, 'Alice\'s Simulated Forgery');
      await tick(100);
      await tester.tap(find.text('SUBMIT'));
      await tick(400); // Allow host submit to completely finish and write to readyPlayers!

      print('DEBUG: currentPlayerId: ${gameService.currentPlayer?.id}');
      print('DEBUG: readyPlayers: ${gameService.gameState?.readyPlayers}');
      print('DEBUG: currentPhase: ${gameService.gameState?.currentPhase}');
      print('DEBUG: cards status: ${gameService.gameState?.cards.map((c) => 'target:${c.targetPlayerId}, truth:${c.truthAnswer.isNotEmpty}, sabs:${c.sabotageAnswers.keys}')}');
      
      // Verify waiting screen
      expect(find.text('THE INK DRIES…'), findsOneWidget);
      print('Host submission locked. Waiting screen displayed.');

      // Complete forgery round 1
      await gameService.debugSimulateBotResponses();
      await tick(200);
      if (gameService.gameState!.currentPhase == GamePhase.forgery) {
        await gameService.evaluateReadyState();
      }
      await tick(600);

      // 6. Verify transition directly to TRUTH phase (as 1 round was configured)
      expect(find.text('TRUTH'), findsOneWidget);
      expect(find.text('WRITE YOUR TRUTH'), findsOneWidget);
      print('Successfully transitioned to TRUTH phase.');

      // Submit truth
      await tester.enterText(find.byType(TextField).first, 'Alice\'s Real Truth');
      await tick(100);
      await tester.tap(find.text('SUBMIT'));
      await tick(400);

      // Complete Truth round
      await gameService.debugSimulateBotResponses();
      await tick(200);
      if (gameService.gameState!.currentPhase == GamePhase.truth) {
        await gameService.evaluateReadyState();
      }
      await tick(600);

      // 7. Verify transition to VOTE phase and resolve all 10 cards
      for (int i = 0; i < 10; i++) {
        if (i > 0) {
          await tester.tap(find.text('CONTINUE'));
          await tick(600);
        }

        expect(find.text('THE VOTE'), findsOneWidget);
        final isHostTarget = gameService.currentPlayerId == gameService.gameState!.currentReaderId;

        if (isHostTarget) {
          expect(find.text('THE PARLOR DELIBERATES…'), findsOneWidget);
          await tester.tap(find.text('I\'M READY'));
          await tick(400);
        } else {
          final currentTargetId = gameService.gameState!.currentReaderId!;
          await gameService.castVote(currentTargetId, gameService.currentPlayerId!, 'TRUTH');
          await tick(100);
        }

        await gameService.debugSimulateBotResponses();
        await tick(200);
        if (gameService.gameState!.currentPhase == GamePhase.vote) {
          await gameService.evaluateReadyState();
        }
        await tick(600);

        // Verify transition to REVEAL phase
        expect(find.text('THE REVEAL'), findsOneWidget);
        await tick(6000); // Wait for the beats sequence to reveal points and unmask tray
        final currentTargetName = gameService.players.firstWhere((p) => p.id == gameService.gameState!.currentReaderId).name.toUpperCase();
        expect(find.text("RESOLVING ${currentTargetName}'S CARD"), findsOneWidget);
        expect(find.text('POINTS AWARDED THIS CARD'), findsOneWidget);
      }

      // Final continue to Game Over
      await tester.tap(find.text('CONTINUE'));
      await tick(600);

      // 8. Verify transition to GAME OVER phase
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('THE NIGHT\'S HONORS'), findsOneWidget);
      print('Successfully transitioned to GAME OVER phase.');

      // Return to Lobby
      await tester.tap(find.text('RETURN TO LOBBY'));
      await tick(600);

      // Verify reset back to starting screen
      expect(find.text('CREATE ROOM'), findsOneWidget);
      print('--- UI E2E WIDGET TEST PASSED SUCCESSFULLY ---');
    });

    testWidgets('Callable Error Handling & Spinner Recovery', (WidgetTester tester) async {
      print('--- STARTING UI ERROR HANDLER WIDGET TEST ---');
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> tick([int ms = 200]) async {
        final steps = (ms / 50).round();
        for (int i = 0; i < steps; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump();
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const GaslightApp(),
        ),
      );
      await tick(200);

      // Create room
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.tap(find.text('CREATE ROOM'));
      await tick(500);

      // Lobby: start game
      await gameService.debugAddBots();
      await tick(200);
      await gameService.startGame('the_daily_grind');
      await tick(600);

      // Verify forgery phase
      expect(find.text('FORGERY'), findsOneWidget);

      // Try submitting a similarity failure text (contains "trigger_error")
      final craftField = find.byType(TextField).first;
      await tester.enterText(craftField, 'This is a trigger_error answer');
      await tick(100);

      await tester.tap(find.text('SUBMIT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // Verify SnackBar shown and spinner reset
      expect(find.byType(SnackBar), findsOneWidget);
      final SnackBar snackBar = tester.widget(find.byType(SnackBar));
      final Text textWidget = snackBar.content as Text;
      expect(textWidget.data, contains('Too similar'));
      
      // Text field should not be cleared upon failure
      final textAfterError = (tester.widget(find.byType(TextField).first) as TextField).controller?.text;
      expect(textAfterError, 'This is a trigger_error answer');

      // Clean up game room session to stop the periodic heartbeat timer
      await gameService.leaveRoom();
      await tick(100);

      print('--- UI ERROR HANDLER WIDGET TEST PASSED SUCCESSFULLY ---');
    });
  });
}
