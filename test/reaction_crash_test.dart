import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/game_service.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player_state.dart';
import '../lib/models/card_model.dart';
import '../lib/screens/phase4_reveal.dart';
import 'simulation_test.dart';
import 'fake_functions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Reveal Screen Reaction Test', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('New reaction triggers float without build-phase setState exception', (WidgetTester tester) async {
      // 1. Setup a minimal active game state in the Reveal phase
      final host = PlayerState(
        id: 'host_id',
        name: 'HostUser',
        isHost: true,
        joinedAt: 100,
      );
      final guest = PlayerState(
        id: 'guest_id',
        name: 'GuestUser',
        joinedAt: 200,
      );

      final card = CardModel(
        targetPlayerId: 'host_id',
        promptText: 'Simulated prompt?',
        truthAnswer: 'The real truth',
        sabotageAnswers: {'guest_id': 'Simulated lie'},
        votes: {'guest_id': 'TRUTH'},
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 2,
        currentReaderId: 'host_id',
        cards: [card],
        readyPlayers: {'host_id': true, 'guest_id': true},
        resolutionOrder: ['host_id'],
      );

      // Seed mock DB
      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('host_id').set(host.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(guest.toMap());

      // Let GameService hydrate state
      await gameService.tryRejoinSession();
      gameService.listenToRoom('TEST');
      
      // Wait for stream emissions to populate gameService fields
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      expect(gameService.gameState, isNotNull);
      expect(gameService.players.length, 2);

      // Resize virtual screen to prevent vertical layout overflows
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 2. Pump the Phase4RevealScreen widget
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            initialRoute: '/reveal',
            routes: {
              '/reveal': (context) => const Phase4RevealScreen(),
              '/': (context) => const Scaffold(body: Text('Root')),
              '/craft': (context) => const Scaffold(body: Text('Craft')),
              '/vote': (context) => const Scaffold(body: Text('Vote')),
              '/game-over': (context) => const Scaffold(body: Text('GameOver')),
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Ensure Reveal Screen renders
      expect(find.text('THE REVEAL'), findsOneWidget);

      // 3. Simulate guest player sending a reaction
      final updatedGuest = guest.copyWith(
        lastReaction: '🔥',
        lastReactionAt: DateTime.now().millisecondsSinceEpoch + 1000,
      );

      // Update mock DB to trigger gameService notifier update
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(updatedGuest.toMap());
      
      // Allow streams and listener notifications to propagate
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      
      // Pump frame to trigger floating animation
      await tester.pump();

      // No assertion errors should be thrown!
      // Verify floating reaction exists in the widget tree
      expect(find.byType(FloatingEmojiWidget), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingEmojiWidget),
          matching: find.text('GuestUser'),
        ),
        findsOneWidget,
      );

      // Drain the 3-second floating reaction removal timer and the recursive reveal sequence timers
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
