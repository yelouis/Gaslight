import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
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

  PlayerState makeHost() => PlayerState(
        id: 'p_host',
        name: 'Alice',
        isHost: true,
      );

  PlayerState makeTarget() => PlayerState(
        id: 'p_target',
        name: 'Bob',
        isHost: false,
      );

  group('AA5 (Issue 166): Sentence Stems Per Prompt Tests', () {
    testWidgets(
      'catalogue prompt renders stem in truth mode and forgery mode; answer controller remains empty',
      (WidgetTester tester) async {
        const promptText = "The first thing I'm stealing if looting becomes completely legal for one night.";
        final expectedStems = PromptDecks.getStemsForPrompt(promptText);
        expect(expectedStems, isNotNull);
        expect(expectedStems!.isNotEmpty, isTrue);
        final expectedStem = expectedStems.first;

        // 1. Truth round test
        final truthCard = CardModel(
          targetPlayerId: 'p_host',
          promptText: promptText,
        );
        final truthState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.truth,
          totalPlayers: 2,
          isTimerDisabled: true,
          cards: [truthCard],
          currentCardAssignments: {'p_host': 'p_host'},
          resolutionOrder: ['p_host'],
        );
        final me = makeHost();
        gameService.debugSetState(truthState, [me], me.id);

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

        final stemFinder = find.byKey(const ValueKey('sentence_stem_hint'));
        expect(stemFinder, findsOneWidget);
        expect(find.text('Starter: "$expectedStem…"'), findsOneWidget);

        // Assert answer field controller is never pre-filled
        final textField = tester.widget<TextField>(find.byKey(const ValueKey('answer_field')));
        expect(textField.controller?.text, isEmpty);

        // 2. Forgery round test
        final target = makeTarget();
        final forgeryCard = CardModel(
          targetPlayerId: 'p_target',
          promptText: promptText,
        );
        final forgeryState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.forgery,
          totalPlayers: 2,
          isTimerDisabled: true,
          cards: [forgeryCard],
          currentCardAssignments: {'p_host': 'p_target'},
          resolutionOrder: ['p_target'],
        );
        gameService.debugSetState(forgeryState, [me, target], me.id);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(stemFinder, findsOneWidget);
        expect(find.text('Writing as Bob: "$expectedStem…"'), findsOneWidget);

        final textFieldForgery = tester.widget<TextField>(find.byKey(const ValueKey('answer_field')));
        expect(textFieldForgery.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'prompt not in catalogue renders no stem hint and does not throw',
      (WidgetTester tester) async {
        const customPrompt = 'A completely non-catalogue custom prompt for testing';
        expect(PromptDecks.getStemsForPrompt(customPrompt), isNull);

        final card = CardModel(
          targetPlayerId: 'p_host',
          promptText: customPrompt,
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

        final stemFinder = find.byKey(const ValueKey('sentence_stem_hint'));
        expect(stemFinder, findsNothing);

        final textField = tester.widget<TextField>(find.byKey(const ValueKey('answer_field')));
        expect(textField.controller?.text, isEmpty);
      },
    );
  });
}
