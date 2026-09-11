import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'fake_functions.dart';
import 'simulation_test.dart'; // import FakeFirestore

void main() {
  group('Phase 3 Vote: Target Forgery Author Guessing (AA16b / Issue 162)', () {
    late FakeFirestore mockDb;
    late FakeFirebaseFunctions mockFunctions;
    late GameService gameService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      mockFunctions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: mockFunctions);
      FlutterError.onError = (FlutterErrorDetails details) {
        // ignore: avoid_print
        print('FLUTTER_ERROR_ON_ERROR: ${details.exceptionAsString()}');
        // ignore: avoid_print
        print('CONTEXT: ${details.context}');
        // ignore: avoid_print
        print('INFORMATION:\n${details.informationCollector?.call().map((d) => d.toString()).join("\n")}');
      };
    });

    tearDown(() {
      gameService.dispose();
    });

    Future<void> pumpVoteScreen(WidgetTester tester, {Size size = const Size(390, 844)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
              child: child!,
            ),
            home: const Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('1. Target taps player chip on forgery -> chip highlights and attribution saved to backend', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      final card = CardModel(
        promptText: 'Alice secret prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'Bob Forgery 1', 'p3': 'Charlie Forgery 2'},
        options: [
          CardAnswerOption(id: 'opt_forgery_bob', text: 'Bob Forgery 1'),
          CardAnswerOption(id: 'opt_truth', text: 'Alice Truth Answer'),
          CardAnswerOption(id: 'opt_forgery_charlie', text: 'Charlie Forgery 2'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2, p3]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1'); // Alice is target
      await gameService.tryRejoinSession();

      await pumpVoteScreen(tester);

      // At card 0: Bob Forgery 1.
      expect(find.text('Bob Forgery 1'), findsOneWidget);
      expect(find.text('WHO AUTHORED THIS LIE? (TAP TO ATTRIBUTE)'), findsOneWidget);

      // Alice should see chips for Bob and Charlie
      final bobChipFinder = find.byKey(const Key('attribution_chip_opt_forgery_bob_p2'));
      final charlieChipFinder = find.byKey(const Key('attribution_chip_opt_forgery_bob_p3'));
      expect(bobChipFinder, findsOneWidget);
      expect(charlieChipFinder, findsOneWidget);

      // Initially Bob chip is unselected (background color not AppColors.brass)
      final bobChipBefore = tester.widget<ActionChip>(bobChipFinder);
      expect(bobChipBefore.backgroundColor, isNot(equals(AppColors.brass)));

      // Ensure visible and tap Bob chip to attribute
      await tester.ensureVisible(bobChipFinder);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(bobChipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Bob chip is now highlighted with AppColors.brass
      final bobChipAfter = tester.widget<ActionChip>(bobChipFinder);
      expect(bobChipAfter.backgroundColor, equals(AppColors.brass));

      // Check backend persistence in fake Firestore sealed collection
      final sealedDoc = await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').get();
      expect(sealedDoc.data()?['targetForgeryGuesses'], equals({'opt_forgery_bob': 'p2'}));

      // Tap Bob chip again to un-attribute
      await tester.ensureVisible(bobChipFinder);
      await tester.tap(bobChipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      final bobChipCleared = tester.widget<ActionChip>(bobChipFinder);
      expect(bobChipCleared.backgroundColor, isNot(equals(AppColors.brass)));

      final sealedDocCleared = await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').get();
      expect(sealedDocCleared.data()?['targetForgeryGuesses'], equals({}));

      await gameService.leaveRoom();
    });

    testWidgets('2. Target navigates to another forgery and assigns a different chip', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      final card = CardModel(
        promptText: 'Alice secret prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'Bob Forgery 1', 'p3': 'Charlie Forgery 2'},
        options: [
          CardAnswerOption(id: 'opt_forgery_bob', text: 'Bob Forgery 1'),
          CardAnswerOption(id: 'opt_truth', text: 'Alice Truth Answer'),
          CardAnswerOption(id: 'opt_forgery_charlie', text: 'Charlie Forgery 2'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2, p3]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await pumpVoteScreen(tester);

      // Attribute card 0 (Bob Forgery 1) to Bob
      final bobChip1Finder = find.byKey(const Key('attribution_chip_opt_forgery_bob_p2'));
      await tester.ensureVisible(bobChip1Finder);
      await tester.tap(bobChip1Finder);
      await tester.pump(const Duration(milliseconds: 200));

      // Navigate to card 2 (Charlie Forgery 2) via dot 2
      final dot2Finder = find.byKey(const Key('stacked_deck_dot_2'));
      await tester.ensureVisible(dot2Finder);
      await tester.tap(dot2Finder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Charlie Forgery 2'), findsOneWidget);

      // Attribute card 2 to Charlie
      final charlieChipFinder = find.byKey(const Key('attribution_chip_opt_forgery_charlie_p3'));
      await tester.ensureVisible(charlieChipFinder);
      await tester.tap(charlieChipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      final charlieChip = tester.widget<ActionChip>(charlieChipFinder);
      expect(charlieChip.backgroundColor, equals(AppColors.brass));

      // Backend now contains both guesses
      final sealedDoc = await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').get();
      expect(sealedDoc.data()?['targetForgeryGuesses'], equals({
        'opt_forgery_bob': 'p2',
        'opt_forgery_charlie': 'p3',
      }));

      // Navigate back to card 0 and verify Bob chip remains highlighted
      final dot0Finder = find.byKey(const Key('stacked_deck_dot_0'));
      await tester.ensureVisible(dot0Finder);
      await tester.tap(dot0Finder);
      await tester.pump(const Duration(milliseconds: 200));

      final bobChip = tester.widget<ActionChip>(find.byKey(const Key('attribution_chip_opt_forgery_bob_p2')));
      expect(bobChip.backgroundColor, equals(AppColors.brass));

      await gameService.leaveRoom();
    });

    testWidgets('3. Target\'s own truth offers no attribution affordance', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);

      final card = CardModel(
        promptText: 'Alice prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'Bob Forgery'},
        options: [
          CardAnswerOption(id: 'opt_truth', text: 'Alice Truth Answer'),
          CardAnswerOption(id: 'opt_forgery', text: 'Bob Forgery'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      // Submit Alice truth to populate myOptionIdForThisCard
      await gameService.submitCardAnswer('p1', 'p1', 'Alice Truth Answer', true);
      await mockDb.collection('rooms').doc('TEST').update({'readyPlayers': {}});

      await pumpVoteScreen(tester);

      // On Alice truth card (index 0):
      expect(find.text('This is your own truth — no forgery to unmask.'), findsOneWidget);
      expect(find.text('WHO AUTHORED THIS LIE? (TAP TO ATTRIBUTE)'), findsNothing);

      await gameService.leaveRoom();
    });

    testWidgets('4. Target does not appear in candidate author list', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);
      final p4 = PlayerState(id: 'p4', name: 'Spectator Sam', role: PlayerRole.spectator);

      final card = CardModel(
        promptText: 'Alice prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'Bob Forgery', 'p3': 'Charlie Forgery'},
        options: [
          CardAnswerOption(id: 'opt_forgery', text: 'Bob Forgery'),
          CardAnswerOption(id: 'opt_truth', text: 'Alice Truth Answer'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 4,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2, p3, p4]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1'); // Alice
      await gameService.tryRejoinSession();

      await pumpVoteScreen(tester);

      // Alice must NOT appear in candidate chip list
      expect(find.byKey(const Key('attribution_chip_opt_forgery_p1')), findsNothing);
      // Spectator Sam must NOT appear in candidate chip list
      expect(find.byKey(const Key('attribution_chip_opt_forgery_p4')), findsNothing);
      // Bob and Charlie MUST appear
      expect(find.byKey(const Key('attribution_chip_opt_forgery_p2')), findsOneWidget);
      expect(find.byKey(const Key('attribution_chip_opt_forgery_p3')), findsOneWidget);

      await gameService.leaveRoom();
    });

    testWidgets('5. 320 pt layout test with 6 options and 5 players — zero overflow, all chips reachable', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob');
      final p3 = PlayerState(id: 'p3', name: 'Charlie');
      final p4 = PlayerState(id: 'p4', name: 'Diana');
      final p5 = PlayerState(id: 'p5', name: 'Evan');

      final card = CardModel(
        promptText: 'Alice 6-option prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'F1', 'p3': 'F2', 'p4': 'F3', 'p5': 'F4'},
        options: [
          CardAnswerOption(id: 'opt1', text: 'Bob Forgery with quite a long description text 1'),
          CardAnswerOption(id: 'opt2', text: 'Charlie Forgery with quite a long description text 2'),
          CardAnswerOption(id: 'opt3', text: 'Diana Forgery with quite a long description text 3'),
          CardAnswerOption(id: 'opt4', text: 'Evan Forgery with quite a long description text 4'),
          CardAnswerOption(id: 'opt5', text: 'THE SOUL IS SILENT'),
          CardAnswerOption(id: 'opt6', text: 'Alice Truth Answer'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 5,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2, p3, p4, p5]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await pumpVoteScreen(tester, size: const Size(320, 640));

      // Zero Flutter overflow errors
      final err = tester.takeException();
      expect(err, isNull);

      // All 4 candidate author chips (Bob, Charlie, Diana, Evan) are present
      final evanChipFinder = find.byKey(const Key('attribution_chip_opt1_p5'));
      expect(find.byKey(const Key('attribution_chip_opt1_p2')), findsOneWidget);
      expect(find.byKey(const Key('attribution_chip_opt1_p3')), findsOneWidget);
      expect(find.byKey(const Key('attribution_chip_opt1_p4')), findsOneWidget);
      expect(evanChipFinder, findsOneWidget);

      await tester.ensureVisible(evanChipFinder);
      await tester.tap(evanChipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.widget<ActionChip>(evanChipFinder).backgroundColor, equals(AppColors.brass));

      await gameService.leaveRoom();
    });

    testWidgets('6. State-lifetime guard: reader change without re-pump clears map', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob');

      final card1 = CardModel(
        promptText: 'Card 1 prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'Truth 1',
        sabotageAnswers: {'p2': 'Forgery 1'},
        options: [
          CardAnswerOption(id: 'c1_opt_forgery', text: 'Forgery 1'),
          CardAnswerOption(id: 'c1_opt_truth', text: 'Truth 1'),
        ],
      );

      final card2 = CardModel(
        promptText: 'Card 2 prompt',
        targetPlayerId: 'p2',
        truthAnswer: 'Truth 2',
        sabotageAnswers: {'p1': 'Alice Forgery 2'},
        options: [
          CardAnswerOption(id: 'c2_opt_forgery', text: 'Alice Forgery 2'),
          CardAnswerOption(id: 'c2_opt_truth', text: 'Truth 2'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        currentReaderId: 'p1',
        cards: [card1, card2],
        currentCardAssignments: {'p1': 'p1', 'p2': 'p2'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();

      await pumpVoteScreen(tester);

      // Attribute card 1 forgery to Bob
      final bobChip1Finder = find.byKey(const Key('attribution_chip_c1_opt_forgery_p2'));
      await tester.ensureVisible(bobChip1Finder);
      await tester.tap(bobChip1Finder);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.widget<ActionChip>(bobChip1Finder).backgroundColor, equals(AppColors.brass));

      // Advance reader to p2 in same room without re-pumping widget tree
      await mockDb.collection('rooms').doc('TEST').update({
        'currentReaderId': 'p2',
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Alice is now voter on Bob's card (not target), so attribution chips should not be present
      expect(find.text('WHO AUTHORED THIS LIE? (TAP TO ATTRIBUTE)'), findsNothing);

      // Now advance back to reader p1
      await mockDb.collection('rooms').doc('TEST').update({
        'currentReaderId': 'p1',
      });
      await tester.pump(const Duration(milliseconds: 200));

      // Attribution map was cleared on reader change! Bob chip is no longer highlighted
      final bobChipAfter = find.byKey(const Key('attribution_chip_c1_opt_forgery_p2'));
      await tester.ensureVisible(bobChipAfter);
      expect(tester.widget<ActionChip>(bobChipAfter).backgroundColor, isNot(equals(AppColors.brass)));

      await gameService.leaveRoom();
    });

    testWidgets('7. Voter path unchanged: confirm vote still works, self-voting refused', (tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob');
      final p3 = PlayerState(id: 'p3', name: 'Charlie');

      final card = CardModel(
        promptText: 'Alice secret truth',
        targetPlayerId: 'p1',
        truthAnswer: 'Alice Truth Answer',
        sabotageAnswers: {'p2': 'Bob Forgery Answer', 'p3': 'Charlie Forgery Answer'},
        options: [
          CardAnswerOption(id: 'opt1', text: 'Alice Truth Answer'),
          CardAnswerOption(id: 'opt2', text: 'Bob Forgery Answer'),
          CardAnswerOption(id: 'opt3', text: 'Charlie Forgery Answer'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2, p3]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p2'); // Bob is voter
      await gameService.tryRejoinSession();

      // Submit Bob's forgery answer
      await gameService.submitCardAnswer('p1', 'p2', 'Bob Forgery Answer', false);
      await mockDb.collection('rooms').doc('TEST').update({'readyPlayers': {}});

      await pumpVoteScreen(tester);

      // Voter does NOT see target attribution chips
      expect(find.text('WHO AUTHORED THIS LIE? (TAP TO ATTRIBUTE)'), findsNothing);

      // Peel to Bob's own forgery at index 1
      final dot1Finder = find.byKey(const Key('stacked_deck_dot_1'));
      await tester.ensureVisible(dot1Finder);
      await tester.tap(dot1Finder);
      await tester.pump(const Duration(milliseconds: 200));

      // Bob cannot vote for his own forgery
      final bobAnswerFinder = find.text('Bob Forgery Answer');
      await tester.ensureVisible(bobAnswerFinder);
      await tester.tap(bobAnswerFinder);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsNothing);

      // Peel to Alice's truth at index 0 and select it
      final dot0Finder = find.byKey(const Key('stacked_deck_dot_0'));
      await tester.ensureVisible(dot0Finder);
      await tester.tap(dot0Finder);
      await tester.pump(const Duration(milliseconds: 200));

      final truthAnswerFinder = find.text('Alice Truth Answer');
      await tester.ensureVisible(truthAnswerFinder);
      await tester.tap(truthAnswerFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Wax seal stamp appears on selected card
      expect(find.byKey(const Key('active_card_wax_seal_stamp')), findsOneWidget);

      // Confirm vote button is present and can be tapped
      final confirmFinder = find.text('CONFIRM VOTE');
      await tester.ensureVisible(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verified: vote is recorded and screen transitions to ballot sealed waiting UI
      expect(find.text('YOUR BALLOT IS SEALED'), findsOneWidget);

      await gameService.leaveRoom();
    });
  });
}
