import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/main.dart';
import '../lib/services/game_service.dart';
import '../lib/models/game_state.dart';
import '../lib/utils/semantic_filter.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gaslight UI E2E Widget Test', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb);
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

      // Pre-populate embedding cache to avoid network blocks or async delays in similarity checks
      SemanticFilter.clearCache();
      SemanticFilter.debugSetEmbedding('Alice\'s Simulated Forgery', [1.0, 0.0, 0.0]);
      SemanticFilter.debugSetEmbedding('Alice\'s Real Truth', [1.0, 0.0, 0.0]);

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
      expect(find.text('ROOM: $rCode'), findsOneWidget);
      expect(find.text('WAITING FOR CREW...'), findsOneWidget);
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

      // Verify waiting screen
      expect(find.text('HOLDING TIGHT...'), findsOneWidget);
      print('Host submission locked. Waiting screen displayed.');

      // Complete forgery round 1
      await gameService.debugSimulateBotResponses();
      await tick(200);
      await gameService.evaluateReadyState();
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
      await gameService.evaluateReadyState();
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
          expect(find.text('THEY ARE VOTING ON YOUR CARD...'), findsOneWidget);
          await tester.tap(find.text('I\'M READY'));
          await tick(400);
        } else {
          final currentTargetId = gameService.gameState!.currentReaderId!;
          await gameService.castVote(currentTargetId, gameService.currentPlayerId!, 'TRUTH');
          await tick(100);
        }

        await gameService.debugSimulateBotResponses();
        await tick(200);
        await gameService.evaluateReadyState();
        await tick(600);

        // Verify transition to REVEAL phase
        expect(find.text('THE REVEAL'), findsOneWidget);
        final currentTargetName = gameService.players.firstWhere((p) => p.id == gameService.gameState!.currentReaderId).name.toUpperCase();
        expect(find.text("RESOLVING ${currentTargetName}'S CARD"), findsOneWidget);
        expect(find.text('POINTS AWARDED THIS CARD'), findsOneWidget);
      }

      // Final continue to Game Over
      await tester.tap(find.text('CONTINUE'));
      await tick(600);

      // 8. Verify transition to GAME OVER phase
      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('THE CREW\'S HONORS'), findsOneWidget);
      print('Successfully transitioned to GAME OVER phase.');

      // Return to Lobby
      await tester.tap(find.text('RETURN TO LOBBY'));
      await tick(600);

      // Verify reset back to starting screen
      expect(find.text('CREATE ROOM'), findsOneWidget);
      print('--- UI E2E WIDGET TEST PASSED SUCCESSFULLY ---');
    });
  });
}
