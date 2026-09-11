import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    gameService = GameService(db: mockDb, functions: fakeFns);
    fakeFns.overrideCallable('submitAnswer', (params) async {
      return {'success': true};
    });
  });

  tearDown(() {
    gameService.dispose();
  });

  PlayerState makeHost() => PlayerState(
        id: 'p_host',
        name: 'Alice',
        isHost: true,
      );

  PlayerState makeTarget1() => PlayerState(
        id: 'p_target1',
        name: 'Bob',
        isHost: false,
      );

  PlayerState makeTarget2() => PlayerState(
        id: 'p_target2',
        name: 'Charlie',
        isHost: false,
      );

  group('AA6 (Issue 158): Waiting Screen Submitted Answer Recap Tests', () {
    testWidgets('submit an answer, assert the waiting screen shows that exact text and prompt', (WidgetTester tester) async {
      const prompt = 'The dumbest reason I would end up getting kicked out of a cult.';
      final card = CardModel(
        targetPlayerId: 'p_host',
        promptText: prompt,
      );
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p_host': 'p_host'},
        resolutionOrder: ['p_host'],
      );
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      expect(fieldFinder, findsOneWidget);

      await tester.enterText(fieldFinder, 'I kept questioning the supreme leader snack choices');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate player becoming ready on server
      final waitingState = state.copyWith(readyPlayers: {'p_host': true});
      gameService.debugSetState(waitingState, [me], me.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('submitted_answer_recap')), findsOneWidget);
      expect(find.text('“I kept questioning the supreme leader snack choices”'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
    });

    testWidgets('submit on rotation 1, advance to rotation 2 without re-pumping, submit again, assert recap shows rotation 2 answer and not rotation 1', (WidgetTester tester) async {
      const prompt1 = 'Prompt for Bob card';
      const prompt2 = 'Prompt for Charlie card';
      final me = makeHost();
      final target1 = makeTarget1();
      final target2 = makeTarget2();

      final card1 = CardModel(targetPlayerId: 'p_target1', promptText: prompt1);
      final card2 = CardModel(targetPlayerId: 'p_target2', promptText: prompt2);

      // Rotation 1 setup
      final rot1State = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        currentRotationIndex: 1,
        totalPlayers: 3,
        isTimerDisabled: true,
        cards: [card1, card2],
        currentCardAssignments: {'p_host': 'p_target1'},
        resolutionOrder: ['p_target1', 'p_target2'],
        readyPlayers: {'p_host': false},
      );

      gameService.debugSetState(rot1State, [me, target1, target2], me.id);

      // Mount widget ONCE for the entire test
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Submit on rotation 1
      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      expect(fieldFinder, findsOneWidget);
      await tester.enterText(fieldFinder, 'Bob forgery answer 1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Set ready on rotation 1 -> waiting screen
      final rot1WaitingState = rot1State.copyWith(readyPlayers: {'p_host': true});
      gameService.debugSetState(rot1WaitingState, [me, target1, target2], me.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('“Bob forgery answer 1”'), findsOneWidget);

      // Advance to rotation 2 WITHOUT re-pumping (only tester.pump()).
      // First, simulate entering rotation 2 in ready state (e.g. spectator or waiting on next card)
      final rot2InitialState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        currentRotationIndex: 2,
        totalPlayers: 3,
        isTimerDisabled: true,
        cards: [card1, card2],
        currentCardAssignments: {'p_host': 'p_target2'},
        resolutionOrder: ['p_target1', 'p_target2'],
        readyPlayers: {'p_host': true},
      );
      gameService.debugSetState(rot2InitialState, [me, target1, target2], me.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Without the reset in phase2_craft.dart, this would still show rotation 1's answer!
      expect(find.text('“Bob forgery answer 1”'), findsNothing, reason: 'Rotation 2 must not retain rotation 1 submitted answer');

      // Now unready to display write UI for rotation 2
      final rot2WriteState = rot2InitialState.copyWith(readyPlayers: {'p_host': false});
      gameService.debugSetState(rot2WriteState, [me, target1, target2], me.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('answer_field')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('answer_field')), 'Charlie forgery answer 2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Set ready on rotation 2 -> waiting screen
      final rot2WaitingState = rot2InitialState.copyWith(readyPlayers: {'p_host': true});
      gameService.debugSetState(rot2WaitingState, [me, target1, target2], me.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('“Charlie forgery answer 2”'), findsOneWidget);
      expect(find.text('“Bob forgery answer 1”'), findsNothing);
      expect(find.text(prompt2), findsOneWidget);
    });
  });
}
