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
  });

  tearDown(() {
    gameService.dispose();
  });

  GameState makeState({required GamePhase phase, int rotation = 0}) {
    final card = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'A deep dark secret',
    );
    return GameState(
      roomCode: 'TEST',
      currentPhase: phase,
      totalPlayers: 2,
      isTimerDisabled: true,
      cards: [card],
      currentCardAssignments: {'p_host': 'p_host'},
      currentRotationIndex: rotation,
      resolutionOrder: ['p_host'],
    );
  }

  PlayerState makeHost() => PlayerState(
        id: 'p_host',
        name: 'Alice',
        isHost: true,
      );

  group('AA1 (Issue 155): DealtCardOverlay Removal Tests', () {
    testWidgets(
      'entering craft screen on phase change: answer_field is present and hit-testable, and RE-ROLL PROMPT is findable on first pump with zero gestures',
      (WidgetTester tester) async {
        final state = makeState(phase: GamePhase.truth);
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
        // First pump, zero gestures
        await tester.pump();

        // 1. answer_field is present
        final answerFieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(answerFieldFinder, findsOneWidget);

        // 2. answer_field is hit-testable directly (zero gestures prior to this tap)
        await tester.tap(answerFieldFinder);
        await tester.pump();
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
          isTrue,
          reason: 'Tapping answer_field must directly focus it with no modal barrier intercepting',
        );

        // 3. RE-ROLL PROMPT is findable on truth round without dismissing any overlay
        expect(find.text('RE-ROLL PROMPT'), findsOneWidget);
      },
    );

    testWidgets(
      'over-reach guard: "Nobody answered last round. Dealing a new one." SnackBar still appears on forgery->truth transition',
      (WidgetTester tester) async {
        final forgeryState = makeState(phase: GamePhase.forgery);
        final me = makeHost();
        gameService.debugSetState(forgeryState, [me], me.id);

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Phase2CraftScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Now advance from forgery to truth
        final truthState = makeState(phase: GamePhase.truth);
        gameService.debugSetState(truthState, [me], me.id);

        // Pump to let the state change trigger postFrameCallback
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.text('Nobody answered last round. Dealing a new one.'),
          findsOneWidget,
          reason: 'Phase-change block at :180 must preserve the nobody-answered SnackBar on forgery->truth',
        );
      },
    );
  });
}
