import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/main.dart' as app;
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gaslight/firebase_options.dart';
import 'package:gaslight/models/player_state.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Gaslight Real E2E Test (No Mocks)', () {
    testWidgets('Standard Happy Path E2E Journey', (WidgetTester tester) async {
      print('--- STARTING REAL E2E TEST (NO MOCKS) ---');

      // Initialize the real application setup
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Force anonymous authentication
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        print('Authenticated anonymously: ${userCredential.user?.uid}');
      } catch (e) {
        print('Auth Exception: $e');
        rethrow;
      }

      final gameService = GameService(); // Real game service hitting real Firestore

      // Resize virtual screen to fit all scrollable inputs
      tester.view.physicalSize = const Size(1600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        try {
          await gameService.leaveRoom();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (_) {}
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pump the real app
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const app.GaslightApp(),
        ),
      );

      // Helper to pump multiple intermediate frames (every 50ms) to drive animations and navigation transitions
      Future<void> tick([int ms = 200]) async {
        final steps = (ms / 50).round();
        for (int i = 0; i < steps; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump();
      }

      Future<void> waitForPhase(GamePhase phase) async {
        int elapsedMs = 0;
        while ((gameService.gameState == null || gameService.gameState!.currentPhase != phase) && elapsedMs < 25000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(gameService.gameState?.currentPhase, phase);
        print('Successfully transitioned to phase: $phase');
      }

      Future<void> tapContinue() async {
        int elapsedMs = 0;
        while (find.text('CONTINUE').evaluate().isEmpty && elapsedMs < 15000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(find.text('CONTINUE'), findsOneWidget);
        await tick(1000); // Allow route transition and animations to fully settle
        await tester.tap(find.text('CONTINUE'));
        await tick(500);
      }



      await tick(500);

      // Verify entry screen
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);

      // 1. Input Host name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);

      // 2. Create room
      await tester.tap(find.text('CREATE ROOM'));
      
      // Wait for room to be created in Firestore (up to 15 seconds)
      int elapsedMs = 0;
      while (gameService.gameState == null && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;
      expect(find.text('ROOM: $rCode'), findsOneWidget);
      print('Room created in real Firestore: $rCode.');

      // 3. Add bots and wait for Firestore sync
      await tester.tap(find.text('DEBUG: ADD 9 BOTS'));
      
      elapsedMs = 0;
      while (gameService.players.length < 10 && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.players.length, 10);
      print('Bots successfully joined the real Firestore room.');

      // 4. Start game
      await tester.tap(find.text('START GAME'));
      await waitForPhase(GamePhase.forgery);

      // 5. Submit forgery
      final inputField = find.byType(TextField).first;
      await tester.enterText(inputField, 'Alice\'s Real Forgery');
      await tick(100);
      await tester.tap(find.text('SUBMIT'));
      
      // Wait for holding screen to appear (reflecting host submission)
      elapsedMs = 0;
      while (find.text('HOLDING TIGHT...').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('HOLDING TIGHT...'), findsOneWidget);
      print('Host forgery submission registered.');

      // Bot forgery submissions
      await tester.tap(find.text('DEBUG: BOTS SUBMIT'));
      await waitForPhase(GamePhase.truth);

      // 6. Submit truth
      await tester.enterText(find.byType(TextField).first, 'Alice\'s Real Truth');
      await tick(100);
      await tester.tap(find.text('SUBMIT'));
      
      // Wait for holding screen to appear (reflecting host truth submission)
      elapsedMs = 0;
      while (find.text('HOLDING TIGHT...').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('HOLDING TIGHT...'), findsOneWidget);
      print('Host truth submission registered.');

      // Bot truth submissions
      await tester.tap(find.text('DEBUG: BOTS SUBMIT'));
      await waitForPhase(GamePhase.vote);

      // 7. Verify target lockout screen or cast vote based on active reader
      final isHostTargetInitial = gameService.currentPlayerId == gameService.gameState!.currentReaderId;
      if (isHostTargetInitial) {
        elapsedMs = 0;
        while (find.text('THEY ARE VOTING ON YOUR CARD...').evaluate().isEmpty && elapsedMs < 10000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(find.text('THEY ARE VOTING ON YOUR CARD...'), findsOneWidget);
        await tick(1000); // Allow transition to settle
        await tester.tap(find.text('I\'M READY'));
        await tick(500);
      } else {
        elapsedMs = 0;
        while (find.text('WHICH ONE IS THE TRUTH?').evaluate().isEmpty && elapsedMs < 10000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(find.text('WHICH ONE IS THE TRUTH?'), findsOneWidget);
        
        final currentTargetId = gameService.gameState!.currentReaderId!;
        await gameService.castVote(currentTargetId, gameService.currentPlayerId!, 'TRUTH');
        await tick(500);
      }

      await tester.tap(find.text('DEBUG: BOTS SUBMIT'));
      await waitForPhase(GamePhase.reveal);

      // 8. Loop through all remaining cards
      for (int i = 0; i < 9; i++) {
        await tapContinue();
        await waitForPhase(GamePhase.vote);

        // Cast vote or tap ready based on who is the active reader
        final isHostTarget = gameService.currentPlayerId == gameService.gameState!.currentReaderId;
        if (isHostTarget) {
          elapsedMs = 0;
          while (find.text('THEY ARE VOTING ON YOUR CARD...').evaluate().isEmpty && elapsedMs < 10000) {
            await tick(500);
            elapsedMs += 500;
          }
          expect(find.text('THEY ARE VOTING ON YOUR CARD...'), findsOneWidget);
          await tick(1000); // Allow transition to settle
          await tester.tap(find.text('I\'M READY'));
          await tick(500);
        } else {
          elapsedMs = 0;
          while (find.text('WHICH ONE IS THE TRUTH?').evaluate().isEmpty && elapsedMs < 10000) {
            await tick(500);
            elapsedMs += 500;
          }
          expect(find.text('WHICH ONE IS THE TRUTH?'), findsOneWidget);

          final currentTargetId = gameService.gameState!.currentReaderId!;
          await gameService.castVote(currentTargetId, gameService.currentPlayerId!, 'TRUTH');
          await tick(500);
        }

        await tester.tap(find.text('DEBUG: BOTS SUBMIT'));
        await waitForPhase(GamePhase.reveal);
      }

      // Continue to Game Over
      await tapContinue();
      await waitForPhase(GamePhase.gameOver);
      // Return to Lobby
      elapsedMs = 0;
      while (find.text('RETURN TO LOBBY').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('RETURN TO LOBBY'), findsOneWidget);
      await tick(1000); // Allow transition to settle
      await tester.tap(find.text('RETURN TO LOBBY'));
      
      // Wait for back to home screen
      elapsedMs = 0;
      while (gameService.gameState != null && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('CREATE ROOM'), findsOneWidget);
      print('--- REAL E2E TEST PASSED SUCCESSFULLY ---');
    });

    testWidgets('Mid-Game Spectator Join E2E Journey', (WidgetTester tester) async {
      print('--- STARTING SPECTATOR JOIN E2E TEST ---');

      // Initialize the real application setup
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Force anonymous authentication
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        print('Auth Exception: $e');
        rethrow;
      }

      final gameService = GameService(); // Real game service hitting real Firestore

      // Resize virtual screen to fit all scrollable inputs
      tester.view.physicalSize = const Size(1600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        try {
          await gameService.leaveRoom();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (_) {}
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

      Future<void> waitForPhase(GamePhase phase) async {
        int elapsedMs = 0;
        while ((gameService.gameState == null || gameService.gameState!.currentPhase != phase) && elapsedMs < 25000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(gameService.gameState?.currentPhase, phase);
        print('Successfully transitioned to phase: $phase');
      }

      // Pump the real app
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const app.GaslightApp(),
        ),
      );
      await tick(500);

      // 1. Create room as Host (Alice)
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);
      await tester.tap(find.text('CREATE ROOM'));
      
      int elapsedMs = 0;
      while (gameService.gameState == null && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;
      
      // Wait for UI to render lobby with the room code
      elapsedMs = 0;
      while (find.text('ROOM: $rCode').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('ROOM: $rCode'), findsOneWidget);
      print('Alice created room: $rCode');

      // 2. Add bots so we have active players
      await tester.tap(find.text('DEBUG: ADD 9 BOTS'));
      elapsedMs = 0;
      while (gameService.players.length < 10 && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      print('Active players joined: ${gameService.players.length}');

      // Start the game
      await tester.tap(find.text('START GAME'));
      await waitForPhase(GamePhase.forgery);
      print('Game transitioned to FORGERY phase');

      // 3. Late joiner (Steve) joins programmatically
      final steveService = GameService();
      await steveService.joinRoom(rCode, 'Steve', 'steve_id');
      
      // Wait for Alice to sync Steve's join
      elapsedMs = 0;
      while (!gameService.players.any((p) => p.id == 'steve_id') && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      
      // Verify Steve is a spectator
      final steve = gameService.players.firstWhere((p) => p.id == 'steve_id');
      expect(steve.role, PlayerRole.spectator);
      print('Steve successfully joined mid-game as spectator.');

      // 4. Submit Host (Alice) Forgery
      final inputField = find.byType(TextField).first;
      await tester.enterText(inputField, 'Alice\'s Spectator Test Forgery');
      await tick(100);
      await tester.tap(find.text('SUBMIT'));

      // Wait for Alice to be registered as ready
      elapsedMs = 0;
      while (find.text('HOLDING TIGHT...').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('HOLDING TIGHT...'), findsOneWidget);

      // 5. Bot forgery submissions
      await tester.tap(find.text('DEBUG: BOTS SUBMIT'));
      
      // Verify game transitions to TRUTH phase without waiting for Steve's readiness
      await waitForPhase(GamePhase.truth);
      print('Successfully transitioned to TRUTH phase. Steve was ignored for readiness.');

      // Cleanup: Steve must leave room first before Alice (Host) leaves,
      // so Alice's credentials still have host authorization to delete Steve's player document.
      await steveService.leaveRoom();
      await gameService.leaveRoom();
      await tick(500);
    });

    testWidgets('Mid-Game Player Disconnect & Re-indexing E2E Journey', (WidgetTester tester) async {
      print('--- STARTING PLAYER DISCONNECT E2E TEST ---');

      // Initialize the real application setup
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Force anonymous authentication
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        print('Auth Exception: $e');
        rethrow;
      }

      final gameService = GameService(); // Real game service hitting real Firestore

      // Resize virtual screen to fit all scrollable inputs
      tester.view.physicalSize = const Size(1600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        try {
          await gameService.leaveRoom();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (_) {}
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

      Future<void> waitForPhase(GamePhase phase) async {
        int elapsedMs = 0;
        while ((gameService.gameState == null || gameService.gameState!.currentPhase != phase) && elapsedMs < 25000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(gameService.gameState?.currentPhase, phase);
        print('Successfully transitioned to phase: $phase');
      }

      // Pump the real app
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const app.GaslightApp(),
        ),
      );
      await tick(500);

      // 1. Create room as Host (Alice)
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);
      await tester.tap(find.text('CREATE ROOM'));
      
      int elapsedMs = 0;
      while (gameService.gameState == null && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;

      // Wait for UI to render lobby with the room code
      elapsedMs = 0;
      while (find.text('ROOM: $rCode').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('ROOM: $rCode'), findsOneWidget);

      // 2. Add 9 Bots (10 total players)
      await tester.tap(find.text('DEBUG: ADD 9 BOTS'));
      elapsedMs = 0;
      while (gameService.players.length < 10 && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.players.length, 10);

      // Start the game
      await tester.tap(find.text('START GAME'));
      await waitForPhase(GamePhase.forgery);

      // 3. Simulate player disconnect: delete bot_1
      print('Simulating disconnect of bot_1...');
      final db = FirebaseFirestore.instance;
      await db.collection('rooms').doc(rCode).collection('players').doc('bot_1').delete();

      // Wait for Alice (Host heartbeat & listener) to prune bot_1
      elapsedMs = 0;
      while (gameService.players.any((p) => p.id == 'bot_1') && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }

      // Verify bot_1 is pruned
      expect(gameService.players.any((p) => p.id == 'bot_1'), isFalse);
      expect(gameService.players.length, 9);
      
      // Verify card assignments are recalculated and bot_1 target card is removed
      final cardTargets = gameService.gameState!.cards.map((c) => c.targetPlayerId).toSet();
      expect(cardTargets.contains('bot_1'), isFalse);
      print('bot_1 successfully pruned from active game.');

      // Cleanup
      await gameService.leaveRoom();
      await tick(500);
    });

    testWidgets('Semantic Similarity Integrity Check E2E Journey', (WidgetTester tester) async {
      print('--- STARTING SEMANTIC FILTER E2E TEST ---');

      // Initialize the real application setup
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Force anonymous authentication
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (e) {
        print('Auth Exception: $e');
        rethrow;
      }

      final gameService = GameService(); // Real game service hitting real Firestore

      // Resize virtual screen to fit all scrollable inputs
      tester.view.physicalSize = const Size(1600, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() async {
        try {
          await gameService.leaveRoom();
        } catch (_) {}
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
        } catch (_) {}
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

      Future<void> waitForPhase(GamePhase phase) async {
        int elapsedMs = 0;
        while ((gameService.gameState == null || gameService.gameState!.currentPhase != phase) && elapsedMs < 25000) {
          await tick(500);
          elapsedMs += 500;
        }
        expect(gameService.gameState?.currentPhase, phase);
        print('Successfully transitioned to phase: $phase');
      }

      // Pump the real app
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const app.GaslightApp(),
        ),
      );
      await tick(500);

      // 1. Create room as Host (Alice)
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);
      await tester.tap(find.text('CREATE ROOM'));
      
      int elapsedMs = 0;
      while (gameService.gameState == null && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;

      // Wait for UI to render lobby with the room code
      elapsedMs = 0;
      while (find.text('ROOM: $rCode').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(find.text('ROOM: $rCode'), findsOneWidget);

      // 2. Add 9 Bots
      await tester.tap(find.text('DEBUG: ADD 9 BOTS'));
      elapsedMs = 0;
      while (gameService.players.length < 10 && elapsedMs < 15000) {
        await tick(500);
        elapsedMs += 500;
      }
      expect(gameService.players.length, 10);

      // Start the game
      await tester.tap(find.text('START GAME'));
      await waitForPhase(GamePhase.forgery);

      // 3. Pre-populate embeddings to trigger similarity match
      final targetId = gameService.gameState!.currentCardAssignments[gameService.currentPlayerId!];
      expect(targetId, isNotNull);
      
      final existingText = 'sleeping in my bed all day';
      final duplicateText = 'sleep all day in bed';

      // Manually simulate another player already having submitted 'existingText' by calling the gameService transaction
      await gameService.submitCardAnswer(targetId!, 'some_other_player_id', existingText, false);
      await tick(500);



      // 4. Try to submit duplicateText
      final inputField = find.byType(TextField).first;
      await tester.enterText(inputField, duplicateText);
      await tick(100);
      await tester.tap(find.text('SUBMIT'));

      // Wait for SnackBar similarity warning
      elapsedMs = 0;
      while (find.text('Too similar to an existing answer! Be more creative.').evaluate().isEmpty && elapsedMs < 10000) {
        await tick(500);
        elapsedMs += 500;
      }

      // Verify the warning SnackBar is visible and submission is blocked
      expect(find.text('Too similar to an existing answer! Be more creative.'), findsOneWidget);
      expect(gameService.gameState!.readyPlayers[gameService.currentPlayerId!], isNot(isTrue));
      print('Semantic similarity successfully blocked duplicate answer submission!');

      // Cleanup
      await gameService.leaveRoom();
      await tick(500);
    });
  });
}
