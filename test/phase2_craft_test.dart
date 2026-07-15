import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
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

        // Find TextField and type a duplicate forgery
        final txtFinder = find.byType(TextField);
        expect(txtFinder, findsOneWidget);
        await tester.enterText(txtFinder, 'sleep all day in bed');
        await tester.pump();

        // Tap submit
        final submitFinder = find.text('SUBMIT');
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

        // Find TextField and type a distinct forgery
        final txtFinder = find.byType(TextField);
        expect(txtFinder, findsOneWidget);
        await tester.enterText(txtFinder, 'cooking delicious pasta');
        await tester.pump();

        // Tap submit
        final submitFinder = find.text('SUBMIT');
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
  });
}
