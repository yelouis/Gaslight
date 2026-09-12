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
import 'package:gaslight/utils/text_similarity.dart';
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

  group('AC2 (Issue 172): Sample Answers Per Prompt Tests', () {
    testWidgets(
      'catalogue prompt renders sample in truth mode and forgery mode; answer controller remains empty',
      (WidgetTester tester) async {
        const promptText = "The first thing I'm stealing if looting becomes completely legal for one night.";
        final expectedSamples = PromptDecks.getSamplesForPrompt(promptText);
        expect(expectedSamples, isNotNull);
        expect(expectedSamples!.isNotEmpty, isTrue);
        final expectedSample = expectedSamples.first;

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

        final sampleFinder = find.byKey(const ValueKey('sentence_sample_hint'));
        expect(sampleFinder, findsOneWidget);
        expect(find.text('For example: "$expectedSample"'), findsOneWidget);

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

        expect(sampleFinder, findsOneWidget);
        expect(find.text('For example: "$expectedSample"'), findsOneWidget);

        final textFieldForgery = tester.widget<TextField>(find.byKey(const ValueKey('answer_field')));
        expect(textFieldForgery.controller?.text, isEmpty);
      },
    );

    testWidgets(
      'prompt not in catalogue renders no sample hint and does not throw',
      (WidgetTester tester) async {
        const customPrompt = 'A completely non-catalogue custom prompt for testing';
        expect(PromptDecks.getSamplesForPrompt(customPrompt), isNull);

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

        final sampleFinder = find.byKey(const ValueKey('sentence_sample_hint'));
        expect(sampleFinder, findsNothing);

        final textField = tester.widget<TextField>(find.byKey(const ValueKey('answer_field')));
        expect(textField.controller?.text, isEmpty);
      },
    );

    test(
      'Option B known consequence: two answers derived from sample on one card are rejected by similarity check',
      () {
        const promptText = "The first thing I'm stealing if looting becomes completely legal for one night.";
        final sample = PromptDecks.getSamplesForPrompt(promptText)!.first;
        expect(sample, equals("A commercial wheel of aged parmesan and two espresso machines"));

        // Player 1 submits an answer derived from the sample
        final answer1 = sample;
        // Player 2 also leans on the sample and submits a closely derived variation
        const answer2 = "A commercial wheel of aged parmesan and espresso machines";

        // The text similarity heuristic flags this as too similar
        final isTooSimilar = TextSimilarity.isTooSimilar(answer2, [answer1]);
        expect(
          isTooSimilar,
          isTrue,
          reason: 'Duplicate check must reject closely derived sample answers without weakening heuristic',
        );
      },
    );
  });
}
