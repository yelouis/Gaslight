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

  group('AA4 (Issue 154): Live Character Counter Tests', () {
    testWidgets(
      'counter displays 50/100 in normal ink color, and 101/100 in error color when exceeding 100 characters',
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
        await tester.pump(const Duration(milliseconds: 500));

        final fieldFinder = find.byKey(const ValueKey('answer_field'));
        final counterFinder = find.byKey(const ValueKey('answer_character_counter'));
        expect(fieldFinder, findsOneWidget);
        expect(counterFinder, findsOneWidget);

        final BuildContext context = tester.element(counterFinder);
        final Color errorColor = Theme.of(context).colorScheme.error;

        // Enter 50 characters
        final String text50 = 'a' * 50;
        await tester.enterText(fieldFinder, text50);
        await tester.pump();

        Text counterWidget = tester.widget<Text>(counterFinder);
        expect(counterWidget.data, equals('50/100'));
        expect(counterWidget.style?.color, isNot(equals(errorColor)),
            reason: 'Counter must display normal ink color at <= 100 characters');

        // Enter 101 characters (over limit)
        final String text101 = 'a' * 101;
        await tester.enterText(fieldFinder, text101);
        await tester.pump();

        counterWidget = tester.widget<Text>(counterFinder);
        expect(counterWidget.data, equals('101/100'));
        expect(counterWidget.style?.color, equals(errorColor),
            reason: 'Counter must display error color when character count exceeds 100');
      },
    );

    testWidgets(
      'counter trims leading and trailing whitespace to match trimmed submit guard ("  abc  " -> 3/100)',
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
        await tester.pump(const Duration(milliseconds: 500));

        final fieldFinder = find.byKey(const ValueKey('answer_field'));
        final counterFinder = find.byKey(const ValueKey('answer_character_counter'));
        expect(counterFinder, findsOneWidget);

        await tester.enterText(fieldFinder, '  abc  ');
        await tester.pump();

        final Text counterWidget = tester.widget<Text>(counterFinder);
        expect(counterWidget.data, equals('3/100'),
            reason: 'Counter must reflect trimmed string length matching submit guard');
      },
    );
  });
}
