import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 159 (AA9): Best Forgery Banner Suppression and Tie Handling', () {
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
      required List<PlayerState> players,
      required CardModel card,
    }) async {
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: players.length,
        currentReaderId: card.targetPlayerId,
        cards: [card],
        readyPlayers: {for (var p in players) p.id: true},
        resolutionOrder: [card.targetPlayerId],
        unmaskDeadline: 0,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in players) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'auth_${p.id}',
        );
      }

      await mockDb.runTransaction((tx) async {});

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', localPlayerId);
      await gameService.tryRejoinSession();
      gameService.listenToRoom('TEST');

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase4RevealScreen(),
            ),
          ),
        ),
      );

      // Settle reveal beats into stage >= 4
      for (int i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('1. 3 players, best forgery has 1 vote -> no banner', (WidgetTester tester) async {
      try {
        final alice = PlayerState(id: 'alice', name: 'Alice', joinedAt: 100);
        final bob = PlayerState(id: 'bob', name: 'Bob', joinedAt: 200);
        final charlie = PlayerState(id: 'charlie', name: 'Charlie', joinedAt: 300);

        final card = CardModel(
          targetPlayerId: 'alice',
          promptText: 'A prompt',
          truthAnswer: 'Alice Truth',
          sabotageAnswers: {'bob': 'Bob Lie', 'charlie': 'Charlie Lie'},
          votes: {
            'bob': 'alice', // Bob votes truth
            'charlie': 'bob', // Charlie votes Bob's lie (1 vote)
          },
        );

        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'alice',
          players: [alice, bob, charlie],
          card: card,
        );

        expect(find.text('🏆 BEST FORGERY OF THE ROUND'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('2. 1-1 tie -> no banner', (WidgetTester tester) async {
      try {
        final alice = PlayerState(id: 'alice', name: 'Alice', joinedAt: 100);
        final bob = PlayerState(id: 'bob', name: 'Bob', joinedAt: 200);
        final charlie = PlayerState(id: 'charlie', name: 'Charlie', joinedAt: 300);
        final david = PlayerState(id: 'david', name: 'David', joinedAt: 400);

        final card = CardModel(
          targetPlayerId: 'alice',
          promptText: 'A prompt',
          truthAnswer: 'Alice Truth',
          sabotageAnswers: {'bob': 'Bob Lie', 'charlie': 'Charlie Lie', 'david': 'David Lie'},
          votes: {
            'bob': 'charlie', // 1 vote for Charlie
            'charlie': 'bob', // 1 vote for Bob (1-1 tie)
            'david': 'alice', // Votes truth
          },
        );

        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'alice',
          players: [alice, bob, charlie, david],
          card: card,
        );

        expect(find.text('🏆 BEST FORGERY OF THE ROUND'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('3. clear winner with 2 votes -> banner renders and names them', (WidgetTester tester) async {
      try {
        final alice = PlayerState(id: 'alice', name: 'Alice', joinedAt: 100);
        final bob = PlayerState(id: 'bob', name: 'Bob', joinedAt: 200);
        final charlie = PlayerState(id: 'charlie', name: 'Charlie', joinedAt: 300);
        final david = PlayerState(id: 'david', name: 'David', joinedAt: 400);

        final card = CardModel(
          targetPlayerId: 'alice',
          promptText: 'A prompt',
          truthAnswer: 'Alice Truth',
          sabotageAnswers: {'bob': 'Bob Lie', 'charlie': 'Charlie Lie', 'david': 'David Lie'},
          votes: {
            'bob': 'alice', // Votes truth
            'charlie': 'bob', // Votes Bob
            'david': 'bob', // Votes Bob (Bob has 2 votes)
          },
        );

        await setupAndPumpRevealScreen(
          tester: tester,
          localPlayerId: 'alice',
          players: [alice, bob, charlie, david],
          card: card,
        );

        expect(find.text('🏆 BEST FORGERY OF THE ROUND'), findsOneWidget);
        expect(find.text("Bob's lie fooled 2 players!"), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });
  });
}
