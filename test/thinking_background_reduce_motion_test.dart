import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/widgets/thinking_background.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const settleDuration = Duration(milliseconds: 100);
  const settleTimeout = Duration(seconds: 5);

  group('Issue 138: AnimatedThinkingBackground Reduce Motion (R0)', () {
    testWidgets('1. Falsifying test: AnimatedThinkingBackground settles under Reduce Motion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: const AnimatedThinkingBackground(
              child: Text('Content', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(
        settleDuration,
        EnginePhase.sendSemanticsUpdate,
        settleTimeout,
      );

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('2a. Phase2CraftScreen settles under accessibleNavigation: true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockDb = FakeFirestore();
      final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));

      final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100, isHost: true);
      final card = CardModel(targetPlayerId: 'local_player_id', promptText: 'Test prompt', truthAnswer: 'Truth', sabotageAnswers: {'p2': 'Lie 1'});
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {'local_player_id': 'local_player_id'},
        currentRotationIndex: 1,
        sabotageAnswersCount: 1,
        currentReaderId: 'local_player_id',
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
      await tester.runAsync(() async {
        await gameService.tryRejoinSession();
      });

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
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);
      expect(find.byType(Phase2CraftScreen), findsOneWidget);
      gameService.dispose();
    });

    testWidgets('2b. Phase3VoteScreen settles under accessibleNavigation: true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockDb = FakeFirestore();
      final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));

      final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100, isHost: true);
      final card = CardModel(targetPlayerId: 'local_player_id', promptText: 'Test prompt', truthAnswer: 'Truth', sabotageAnswers: {'p2': 'Lie 1'});
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {'local_player_id': 'local_player_id'},
        currentRotationIndex: 1,
        sabotageAnswersCount: 1,
        currentReaderId: 'local_player_id',
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
      await tester.runAsync(() async {
        await gameService.tryRejoinSession();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase3VoteScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);
      expect(find.byType(Phase3VoteScreen), findsOneWidget);
      gameService.dispose();
    });

    testWidgets('2c. Phase4RevealScreen settles under accessibleNavigation: true', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockDb = FakeFirestore();
      final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));

      final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100, isHost: true);
      final card = CardModel(targetPlayerId: 'local_player_id', promptText: 'Test prompt', truthAnswer: 'Truth', sabotageAnswers: {'p2': 'Lie 1'});
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {'local_player_id': 'local_player_id'},
        currentRotationIndex: 1,
        sabotageAnswersCount: 1,
        currentReaderId: 'local_player_id',
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
      await tester.runAsync(() async {
        await gameService.tryRejoinSession();
      });

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
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);
      expect(find.byType(Phase4RevealScreen), findsOneWidget);
      gameService.dispose();
    });

    testWidgets('3. Over-reach guard: particle layer is present under accessibleNavigation: false and absent under true', (tester) async {
      // AccessibleNavigation: false -> particle layer present
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: false),
            child: const AnimatedThinkingBackground(
              child: Text('Content', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final particleLayerFinder = find.descendant(
        of: find.byType(AnimatedThinkingBackground),
        matching: find.byType(AnimatedBuilder),
      );
      expect(particleLayerFinder, findsOneWidget);

      // AccessibleNavigation: true -> particle layer absent
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: const AnimatedThinkingBackground(
              child: Text('Content', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(particleLayerFinder, findsNothing);
    });

    testWidgets('4. Live toggle works dynamically mid-match', (tester) async {
      final key = GlobalKey();
      bool reduce = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              key: key,
              home: MediaQuery(
                data: MediaQueryData(accessibleNavigation: reduce),
                child: const AnimatedThinkingBackground(
                  child: Text('Toggle Content', textDirection: TextDirection.ltr),
                ),
              ),
            );
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final particleFinder = find.descendant(
        of: find.byType(AnimatedThinkingBackground),
        matching: find.byType(AnimatedBuilder),
      );
      expect(particleFinder, findsOneWidget);

      // Switch reduce on
      reduce = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: reduce),
            child: const AnimatedThinkingBackground(
              child: Text('Toggle Content', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(settleDuration, EnginePhase.sendSemanticsUpdate, settleTimeout);
      expect(particleFinder, findsNothing);

      // Switch reduce off
      reduce = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: reduce),
            child: const AnimatedThinkingBackground(
              child: Text('Toggle Content', textDirection: TextDirection.ltr),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(particleFinder, findsOneWidget);
    });

    testWidgets('5. Screen content always renders in both modes', (tester) async {
      for (final reduce in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: reduce),
              child: const AnimatedThinkingBackground(
                child: Center(child: Text('Vital Screen Content', textDirection: TextDirection.ltr)),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Vital Screen Content'), findsOneWidget);
      }
    });
  });
}
