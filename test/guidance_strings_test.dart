import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:gaslight/widgets/card_grid.dart';
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
  });

  tearDown(() {
    gameService.dispose();
  });

  group('Issue 129 (P11): One Line Guidance Per Screen', () {
    testWidgets('Truth phase displays exact guidance string', (WidgetTester tester) async {
      final me = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final card = CardModel(targetPlayerId: 'p1', promptText: 'Truth prompt');
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        resolutionOrder: ['p1'],
      );
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
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      const expectedTruthString =
          'Write something true about you — the more surprising, the better. Others must be able to believe it.';
      expect(find.text(expectedTruthString), findsOneWidget);
    });

    testWidgets('Forgery phase displays exact guidance string with target player display name', (WidgetTester tester) async {
      final me = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final target = PlayerState(id: 'p2', name: 'Bob');
      final card = CardModel(targetPlayerId: 'p2', promptText: 'Forgery prompt');
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'p2'},
        resolutionOrder: ['p2'],
      );
      gameService.debugSetState(state, [me, target], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('INSPECT').evaluate().isNotEmpty) {
        await tester.tap(find.text('INSPECT'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      const expectedForgeryString =
          'You are writing as Bob. Make it sound like something they would say, so people pick yours.';
      expect(find.text(expectedForgeryString), findsOneWidget);
      // Assert against display name, NEVER against raw player id
      expect(find.textContaining('p2'), findsNothing);
    });

    testWidgets('Forgery phase falls back to "them" when target name is unresolvable', (WidgetTester tester) async {
      final me = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final card = CardModel(targetPlayerId: 'unknown_player', promptText: 'Forgery prompt');
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'unknown_player'},
        resolutionOrder: ['unknown_player'],
      );
      // gs.players only contains 'me', so target 'unknown_player' is unresolvable
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
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('INSPECT').evaluate().isNotEmpty) {
        await tester.tap(find.text('INSPECT'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      const expectedFallbackString =
          'You are writing as them. Make it sound like something they would say, so people pick yours.';
      expect(find.text(expectedFallbackString), findsOneWidget);
      expect(find.textContaining('unknown_player'), findsNothing);
    });

    testWidgets('Vote phase displays exact discussion guidance string', (WidgetTester tester) async {
      final me = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final target = PlayerState(id: 'p2', name: 'Bob');
      final card = CardModel(
        targetPlayerId: 'p2',
        promptText: 'Vote prompt',
        truthAnswer: 'True answer',
      );
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'p2'},
        resolutionOrder: ['p2'],
        currentReaderId: 'p2',
      );
      gameService.debugSetState(state, [me, target], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      const expectedVoteString = 'Talk it out — discussion is part of the game.';
      expect(find.text(expectedVoteString), findsOneWidget);
    });

    testWidgets('320pt width test: Truth, Forgery, and Vote screens have no overflow and primary action is visible', (WidgetTester tester) async {
      const surfaceSize = Size(320, 640);
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Truth screen at 320pt
      final me = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final target = PlayerState(id: 'p2', name: 'Bob');
      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'A fairly long truth prompt text that exercises multi-line layout on narrow screens',
      );
      final truthState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        resolutionOrder: ['p1'],
      );
      gameService.debugSetState(truthState, [me, target], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // No overflow & submit button visible
      expect(tester.takeException(), isNull);
      final submitBtnTruth = find.widgetWithText(PrimaryButton, 'SUBMIT DOSSIER');
      expect(submitBtnTruth, findsOneWidget);
      final truthBox = tester.renderObject<RenderBox>(submitBtnTruth);
      expect(truthBox.size.height, greaterThan(0));

      // 2. Forgery screen at 320pt
      final forgeryCard = CardModel(
        targetPlayerId: 'p2',
        promptText: 'A fairly long forgery prompt text that exercises multi-line layout on narrow screens',
        options: [
          CardAnswerOption(id: 'o1', text: 'Option 1 text'),
          CardAnswerOption(id: 'o2', text: 'Option 2 text'),
        ],
      );
      final forgeryState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [forgeryCard],
        currentCardAssignments: {'p1': 'p2'},
        resolutionOrder: ['p2'],
      );
      gameService.debugSetState(forgeryState, [me, target], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('INSPECT').evaluate().isNotEmpty) {
        await tester.tap(find.text('INSPECT'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
      final submitBtnForgery = find.widgetWithText(PrimaryButton, 'SUBMIT DOSSIER');
      expect(submitBtnForgery, findsOneWidget);
      final forgeryBox = tester.renderObject<RenderBox>(submitBtnForgery);
      expect(forgeryBox.size.height, greaterThan(0));

      // 3. Vote screen at 320pt
      final voteState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [forgeryCard],
        currentCardAssignments: {'p1': 'p2'},
        resolutionOrder: ['p2'],
        currentReaderId: 'p2',
      );
      gameService.debugSetState(voteState, [me, target], me.id);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(CardGrid), findsOneWidget);
      final gridBox = tester.renderObject<RenderBox>(find.byType(CardGrid));
      expect(gridBox.size.height, greaterThan(0));
    });
  });
}
