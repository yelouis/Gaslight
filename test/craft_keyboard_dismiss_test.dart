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

  GameState makeTruthState() {
    final card = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'A deep dark secret',
    );
    return GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.truth,
      totalPlayers: 2,
      isTimerDisabled: true,
      cards: [card],
      currentCardAssignments: {'p_host': 'p_host'},
      resolutionOrder: ['p_host'],
    );
  }

  PlayerState makeHost() => PlayerState(
        id: 'p_host',
        name: 'Alice',
        isHost: true,
      );

  group('AA2 (Issue 156): Craft Screen Tap-Away Keyboard Dismissal Tests', () {
    testWidgets(
      'focusing the answer field and tapping empty background releases focus',
      (WidgetTester tester) async {
        final state = makeTruthState();
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

        // Focus the answer field
        final answerFieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(answerFieldFinder, findsOneWidget);
        await tester.tap(answerFieldFinder);
        await tester.pump();

        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        expect(editableText.focusNode.hasFocus, isTrue, reason: 'Field must be focused after tapping');

        // Tap empty background area (e.g. top-left corner of body, outside any button or text)
        await tester.tapAt(const Offset(10, 80));
        await tester.pump();

        // Assert focus is released
        expect(
          editableText.focusNode.hasFocus,
          isFalse,
          reason: 'Tapping empty background must release focus via FocusScope.unfocus',
        );
      },
    );
  });
}
