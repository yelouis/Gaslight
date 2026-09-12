import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late GameService gameService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
  });

  Future<void> setupAndPumpReveal({
    required WidgetTester tester,
    required CardModel card1,
    CardModel? card2,
    String currentReaderId = 'local_player_id',
  }) async {
    final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100);
    final guest1 = PlayerState(id: 'guest_1', name: 'Bob', joinedAt: 200);
    final guest2 = PlayerState(id: 'guest_2', name: 'Charlie', joinedAt: 300);

    final cards = [card1];
    final resolutionOrder = ['local_player_id'];
    if (card2 != null) {
      cards.add(card2);
      resolutionOrder.add(card2.targetPlayerId);
    }

    final gameState = GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.reveal,
      totalPlayers: 3,
      currentReaderId: currentReaderId,
      cards: cards,
      readyPlayers: {'local_player_id': true, 'guest_1': true, 'guest_2': true},
      resolutionOrder: resolutionOrder,
      unmaskDeadline: 0,
    );

    await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
    await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
      localPlayer.toMap()..['authUid'] = 'local_auth_uid',
    );
    await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_1').set(
      guest1.toMap()..['authUid'] = 'guest_1_auth_uid',
    );
    await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_2').set(
      guest2.toMap()..['authUid'] = 'guest_2_auth_uid',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', 'TEST');
    await prefs.setString('player_id', 'local_player_id');
    await gameService.tryRejoinSession();
    gameService.listenToRoom('TEST');

    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tester.view.physicalSize = const Size(1200, 2400);
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

    // Fast-forward reveal to stage 4+
    for (int i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('Phase 4 Reveal Score Breakdown Collapse (AC1 / Issue 171)', () {
    testWidgets('1. breakdown lines are absent before tapping a chip and present after', (tester) async {
      try {
        final card = CardModel(
          targetPlayerId: 'local_player_id',
          promptText: 'A prompt about secrets',
          truthAnswer: 'The truth is rare',
          scoreDeltas: {
            'local_player_id': 2,
            'guest_1': 3,
          },
          scoreBreakdown: {
            'guest_1': [
              const ScoreBreakdownItem(rule: 'successful_forgery', points: 3),
            ],
          },
        );

        await setupAndPumpReveal(tester: tester, card1: card);

        // Total score is visible initially
        expect(find.text('Bob: +3'), findsOneWidget);
        // Rule breakdown text is NOT visible before tap
        expect(find.text('Successful Forgery: +3'), findsNothing);

        // Tap Bob's chip to expand
        await tester.tap(find.byKey(const ValueKey('score_breakdown_chip_guest_1')));
        await tester.pump();

        // Rule breakdown text IS visible after tap
        expect(find.text('Successful Forgery: +3'), findsOneWidget);

        // Tap Bob's chip again to collapse
        await tester.tap(find.byKey(const ValueKey('score_breakdown_chip_guest_1')));
        await tester.pump();

        // Rule breakdown text is hidden again
        expect(find.text('Successful Forgery: +3'), findsNothing);
        // Total remains visible
        expect(find.text('Bob: +3'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('2. the hint string renders verbatim in brass 11pt', (tester) async {
      try {
        final card = CardModel(
          targetPlayerId: 'local_player_id',
          promptText: 'A prompt about secrets',
          truthAnswer: 'The truth is rare',
          scoreDeltas: {
            'local_player_id': 2,
            'guest_1': 3,
          },
          scoreBreakdown: {},
        );

        await setupAndPumpReveal(tester: tester, card1: card);

        final hintFinder = find.text('Tap a player to see their score breakdown');
        expect(hintFinder, findsOneWidget);

        final Text hintText = tester.widget(hintFinder);
        expect(hintText.style?.color, equals(AppColors.brass));
        expect(hintText.style?.fontSize, equals(11.0));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('3. all chips report equal height when collapsed even with differing rule counts', (tester) async {
      try {
        final card = CardModel(
          targetPlayerId: 'local_player_id',
          promptText: 'A prompt about secrets',
          truthAnswer: 'The truth is rare',
          scoreDeltas: {
            'local_player_id': 2,
            'guest_1': 5,
          },
          scoreBreakdown: {
            'local_player_id': [
              const ScoreBreakdownItem(rule: 'believable_target', points: 2),
            ],
            'guest_1': [
              const ScoreBreakdownItem(rule: 'successful_forgery', points: 3),
              const ScoreBreakdownItem(rule: 'target_forger_guess', points: 1),
              const ScoreBreakdownItem(rule: 'revenge_guess', points: 1),
            ],
          },
        );

        await setupAndPumpReveal(tester: tester, card1: card);

        final chip1 = find.byKey(const ValueKey('score_breakdown_chip_local_player_id'));
        final chip2 = find.byKey(const ValueKey('score_breakdown_chip_guest_1'));
        expect(chip1, findsOneWidget);
        expect(chip2, findsOneWidget);

        final size1 = tester.getSize(chip1);
        final size2 = tester.getSize(chip2);

        expect(size1.height, equals(size2.height),
            reason: 'Both chips must have identical height when collapsed despite 1 vs 3 rule lines');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('4. expand a chip, advance currentReaderId without re-pumping, assert expansion is cleared', (tester) async {
      try {
        final card1 = CardModel(
          targetPlayerId: 'local_player_id',
          promptText: 'Card 1 Prompt',
          truthAnswer: 'Answer 1',
          scoreDeltas: {
            'guest_1': 3,
          },
          scoreBreakdown: {
            'guest_1': [
              const ScoreBreakdownItem(rule: 'successful_forgery', points: 3),
            ],
          },
        );

        final card2 = CardModel(
          targetPlayerId: 'guest_1',
          promptText: 'Card 2 Prompt',
          truthAnswer: 'Answer 2',
          scoreDeltas: {
            'guest_1': 3,
          },
          scoreBreakdown: {
            'guest_1': [
              const ScoreBreakdownItem(rule: 'successful_forgery', points: 3),
            ],
          },
        );

        await setupAndPumpReveal(
          tester: tester,
          card1: card1,
          card2: card2,
          currentReaderId: 'local_player_id',
        );

        // Expand chip on card 1
        await tester.tap(find.byKey(const ValueKey('score_breakdown_chip_guest_1')));
        await tester.pump();
        expect(find.text('Successful Forgery: +3'), findsOneWidget);

        // Advance to card 2 by updating Firestore document WITHOUT rebuilding/re-pumping the widget tree from scratch
        await mockDb.collection('rooms').doc('TEST').update({
          'currentReaderId': 'guest_1',
        });

        // Pump to let the stream emit the new state and run build()
        for (int i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }

        // Assert the expansion was cleared on card change
        expect(find.text('Successful Forgery: +3'), findsNothing,
            reason: 'Advancing card must reset expansion state keyed on currentReaderId');
        expect(find.text('Bob: +3'), findsOneWidget,
            reason: 'Player total must remain visible');
      } finally {
        gameService.dispose();
      }
    });
  });
}
