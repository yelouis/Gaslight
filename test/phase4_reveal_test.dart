import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/services/game_service.dart';
import '../lib/services/audio_service.dart';
import '../lib/models/game_state.dart';
import '../lib/models/player_state.dart';
import '../lib/models/card_model.dart';
import '../lib/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart'; // Import FakeFirestore
import 'audio_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4 Reveal Screen Unmasking and Timing Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupAndPumpRevealScreen({
      required WidgetTester tester,
      required String localPlayerId,
      required int? unmaskDeadline,
      Map<String, String> votes = const {'local_player_id': 'guest_id', 'guest_id': 'TRUTH'},
      Map<String, String> unmaskGuesses = const {},
    }) async {
      // Setup players
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
        targetPlayerId: 'local_player_id',
        promptText: 'Is this the real life?',
        truthAnswer: 'It is just fantasy',
        sabotageAnswers: {'guest_id': 'Caught in a landslide'},
        votes: votes,
        unmaskGuesses: unmaskGuesses,
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 2,
        currentReaderId: 'local_player_id',
        cards: [card],
        readyPlayers: {'local_player_id': true, 'guest_id': true},
        resolutionOrder: ['local_player_id'],
        unmaskDeadline: unmaskDeadline,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
        localPlayer.toMap()..['authUid'] = 'local_auth_uid',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(
        guestPlayer.toMap()..['authUid'] = 'guest_auth_uid',
      );

      // Hydrate GameService
      // Set the mocked current player ID via shared prefs logic/auth simulation
      await mockDb.runTransaction((tx) async {}); // dummy to warm up
      
      // We overwrite gameService's internal currentPlayerId to simulate who we are
      gameService.listenToRoom('TEST');
      // Set current user details manually or via setting prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', localPlayerId);
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      // Resize virtual screen to prevent vertical layout overflows
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            initialRoute: '/reveal',
            routes: {
              '/reveal': (context) => const Phase4RevealScreen(),
              '/': (context) => const Scaffold(body: Text('Root')),
            },
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> settleReveal(WidgetTester tester, int ms) async {
      final steps = ms ~/ 200;
      for (int i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('Widget Test A: Fooled player, unmaskDeadline in future -> guess tray visible, authors sealed', (WidgetTester tester) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Local player voted 'guest_id' (forgery). Thus they are fooled!
        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          unmaskDeadline: now + 15000,
          votes: {'local_player_id': 'guest_id', 'guest_id': 'TRUTH'},
        );

        // Settle initial beats (stage 1 and 2 take 1.8s each, so 3.6s total)
        await settleReveal(tester, 4000);

        final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print("TEST A TEXT WIDGETS: $texts");

        // Assert guess tray is visible
        expect(find.text('REVENGE UNMASKING!'), findsOneWidget);
        expect(find.textContaining('Accuse the player'), findsOneWidget);

        // Every forgery row still shows SEALED ANSWER, no author name text anywhere
        expect(find.text('SEALED ANSWER'), findsNWidgets(1)); // Truth is flipped (stage 2), forgery stays sealed.
        expect(find.textContaining('FORGERY BY'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Widget Test B: unmaskDeadline in past -> authors flipped, REVENGE results row present, tray gone', (WidgetTester tester) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          unmaskDeadline: now - 5000, // already in the past
          votes: {'local_player_id': 'guest_id', 'guest_id': 'TRUTH'},
          unmaskGuesses: {'local_player_id': 'guest_id'}, // local player accused guest_id
        );

        // Settle intro beats
        await settleReveal(tester, 4000);

        final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print("TEST B TEXT WIDGETS: $texts");

        // Assert authors flipped
        expect(find.textContaining('FORGERY BY GUESTPLAYER'), findsOneWidget);

        // Assert REVENGE row present
        expect(find.text('REVENGE UNMASKING RESULTS'), findsOneWidget);
        expect(find.textContaining('accused GuestPlayer'), findsOneWidget);

        // Assert tray is gone
        expect(find.text('REVENGE UNMASKING!'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Widget Test C: unmaskDeadline is null -> no tray, authors flip promptly after intro', (WidgetTester tester) async {
      try {
        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          unmaskDeadline: null, // nobody was fooled
          votes: {'local_player_id': 'TRUTH', 'guest_id': 'TRUTH'},
        );

        // Settle intro beats
        await settleReveal(tester, 4000);

        final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print("TEST C TEXT WIDGETS: $texts");

        // Authors flipped promptly (stage 4)
        expect(find.textContaining('FORGERY BY GUESTPLAYER'), findsOneWidget);
        expect(find.text('THE TRUTH'), findsOneWidget);

        // No tray visible
        expect(find.text('REVENGE UNMASKING!'), findsNothing);
        expect(find.text('UNMASKING IN PROGRESS...'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Widget Test D: Local player not fooled but window active -> status line during window', (WidgetTester tester) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        // Local player voted TRUTH, guest_id voted guest_id (forgery - self-vote/dummy)
        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          unmaskDeadline: now + 15000,
          votes: {'local_player_id': 'TRUTH', 'guest_id': 'local_player_id'},
        );

        // Settle intro beats
        await settleReveal(tester, 4000);

        final texts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList();
        print("TEST D TEXT WIDGETS: $texts");

        // Assert status line is shown instead of input buttons
        expect(find.text('UNMASKING IN PROGRESS...'), findsOneWidget);
        expect(find.textContaining('Fooled players are trying'), findsOneWidget);
        expect(find.textContaining('Accuse the player'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Widget Test E: playReveal fires exactly once when truth is revealed and does not re-fire on timer ticks', (WidgetTester tester) async {
      try {
        final mockRevealPlayer = FakeAudioPlayer();
        final mockSubmitPlayer = FakeAudioPlayer();
        final mockVotePlayer = FakeAudioPlayer();
        final mockUnmaskPlayer = FakeAudioPlayer();

        AudioService.instance.setPlayers(
          submitPlayer: mockSubmitPlayer,
          votePlayer: mockVotePlayer,
          revealPlayer: mockRevealPlayer,
          unmaskPlayer: mockUnmaskPlayer,
        );

        final now = DateTime.now().millisecondsSinceEpoch;
        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'local_player_id',
          unmaskDeadline: now + 15000,
        );

        // Before beat 2, reveal player should have 0 play calls (stage 1)
        expect(mockRevealPlayer.playCallCount, 0);

        // Advance to 2000 ms (into stage 2)
        await tester.pump(const Duration(milliseconds: 2000));
        
        // playReveal should be called exactly once
        expect(mockRevealPlayer.playCallCount, 1);

        // Let the countdown timer trigger several times (200ms periodic ticks)
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // playReveal should still have been called exactly once (prevent double-play)
        expect(mockRevealPlayer.playCallCount, 1);
      } finally {
        gameService.dispose();
      }
    });
  });
}
