import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/main.dart' as app;
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/utils/semantic_filter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gaslight/firebase_options.dart';

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

      await tick(200);

      // Verify entry screen
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);

      // Input Host name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Alice');
      await tick(100);

      // Create room
      await tester.tap(find.text('CREATE ROOM'));
      await tick(1000); // Allow real network time to connect to Firestore and create a room document

      // Verify lobby screen
      expect(gameService.gameState, isNotNull);
      final rCode = gameService.gameState!.roomCode;
      expect(find.text('ROOM: $rCode'), findsOneWidget);
      print('Room created in real Firestore: $rCode.');
    });
  });
}
