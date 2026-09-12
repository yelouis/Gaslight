import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AC3 (Issue 173): Tap To Choose Instruction & Cue Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie');

    final voteCard = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      truthAnswer: 'Alice Real Truth',
      sabotageAnswers: {
        'p2': 'Bob Own Forgery Answer',
        'p3': 'Charlie Forgery Answer',
      },
      options: [
        CardAnswerOption(id: 'opt1', text: 'Charlie Forgery Answer'),
        CardAnswerOption(id: 'opt2', text: 'Bob Own Forgery Answer'),
        CardAnswerOption(id: 'opt3', text: 'THE SOUL IS SILENT'),
      ],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    Future<void> pumpVoteScreen(
      WidgetTester tester, {
      required String localPlayerId,
    }) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        isTimerDisabled: true,
        cards: [voteCard],
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      gameService.debugSetState(gameState, [p1, p2, p3], localPlayerId);

      // Record Bob's submitted answer so isMySubmittedAnswer recognizes opt2 as Bob's forgery
      if (localPlayerId == 'p2') {
        await gameService.submitCardAnswer('p1', 'p2', 'Bob Own Forgery Answer', false);
      }

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: const MediaQueryData(accessibleNavigation: true),
                child: child!,
              );
            },
            home: const Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      '1. On arrival with nothing selected: button reads TAP A CARD TO CHOOSE and is disabled, active card shows Tap to choose this one',
      (tester) async {
        await pumpVoteScreen(tester, localPlayerId: 'p2');

        // Button shows instruction and is disabled
        final buttonFinder = find.byType(PrimaryButton);
        expect(buttonFinder, findsOneWidget);
        final primaryButton = tester.widget<PrimaryButton>(buttonFinder);
        expect(primaryButton.text, equals('TAP A CARD TO CHOOSE'));
        expect(primaryButton.onPressed, isNull);

        // Active card is opt1 (Charlie Forgery Answer: votable, unselected) -> shows tap cue
        expect(find.text('Tap to choose this one'), findsOneWidget);
        expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsNothing);
      },
    );

    testWidgets(
      '2. Tap the active card: tap cue disappears, wax seal appears, button reads CONFIRM VOTE and is enabled',
      (tester) async {
        await pumpVoteScreen(tester, localPlayerId: 'p2');

        // Tap the active card
        await tester.tap(find.text('Charlie Forgery Answer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Cue disappears, wax seal appears
        expect(find.text('Tap to choose this one'), findsNothing);
        expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsOneWidget);

        // Button reverts to CONFIRM VOTE and is enabled
        final primaryButton = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(primaryButton.text, equals('CONFIRM VOTE'));
        expect(primaryButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      '3. Navigate to own answer: Tap to choose this one is suppressed, SEALED ribbon is present, button reads TAP A CARD TO CHOOSE',
      (tester) async {
        await pumpVoteScreen(tester, localPlayerId: 'p2');

        // Navigate to next card (opt2: Bob Own Forgery Answer)
        await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Own answer is now active
        expect(find.text('Bob Own Forgery Answer'), findsOneWidget);
        expect(find.text('(Your Forgery)'), findsOneWidget);
        expect(find.text('SEALED'), findsWidgets);

        // Over-reach guard: tap cue MUST be absent on unvotable card
        expect(find.text('Tap to choose this one'), findsNothing);

        // Button continues to say TAP A CARD TO CHOOSE (and remains disabled)
        final primaryButton = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(primaryButton.text, equals('TAP A CARD TO CHOOSE'));
        expect(primaryButton.onPressed, isNull);
      },
    );

    testWidgets(
      '4. Navigate to placeholder option: Tap to choose this one is suppressed, SEALED ribbon is present',
      (tester) async {
        await pumpVoteScreen(tester, localPlayerId: 'p2');

        // Navigate to card 3 (opt3: THE SOUL IS SILENT)
        await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('THE SOUL IS SILENT'), findsOneWidget);
        expect(find.text('SEALED'), findsWidgets);

        // Over-reach guard: tap cue MUST be absent on placeholder
        expect(find.text('Tap to choose this one'), findsNothing);

        final primaryButton = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(primaryButton.text, equals('TAP A CARD TO CHOOSE'));
        expect(primaryButton.onPressed, isNull);
      },
    );

    testWidgets(
      '5. Over-reach guard (O9): Target player sees no vote button and no tap cue on any card',
      (tester) async {
        // P1 is target of voteCard
        await pumpVoteScreen(tester, localPlayerId: 'p1');

        // Target sees I'M READY, not CONFIRM VOTE or TAP A CARD TO CHOOSE
        expect(find.text('CONFIRM VOTE'), findsNothing);
        expect(find.text('TAP A CARD TO CHOOSE'), findsNothing);
        expect(find.text("I'M READY"), findsOneWidget);

        // Target must see no tap cue on active card
        expect(find.text('Tap to choose this one'), findsNothing);
      },
    );
  });
}
