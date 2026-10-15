import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 196 / AM1: the waiting line on the craft and vote screens agrees with the number of players
/// still to go. It read "Waiting for 1 players..." for the last player (AL1 found it, and the web
/// runs showed it). The strings are asserted verbatim on the real screens, at 1 and at 2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the waiting lines agree with their numbers (Issue 196 / AM1)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    /// [count] players in the room, the local one (the host, Alice) already done, everyone else not.
    List<PlayerState> roster(int count) => [
          PlayerState(id: 'p1', name: 'Alice', isHost: true),
          for (var i = 2; i <= count; i++) PlayerState(id: 'p$i', name: 'Player $i'),
        ];

    Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    /// The craft screen after Alice has submitted: she is ready, [count] - 1 others are not.
    Future<void> pumpCraftWaiting(WidgetTester tester, {required int count}) async {
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: count,
        isTimerDisabled: true,
        cards: [CardModel(targetPlayerId: 'p1', promptText: 'A prompt')],
        currentCardAssignments: {'p1': 'p1'},
        resolutionOrder: ['p1'],
        readyPlayers: {'p1': true},
      );
      gameService.debugSetState(state, roster(count), 'p1');
      await pumpScreen(tester, const Phase2CraftScreen());
      expect(find.text('THE INK DRIES…'), findsOneWidget, reason: 'the screen must be the craft waiting screen');
    }

    /// The vote screen after Bob (a voter, not the card's target) has voted: he is ready, and so is
    /// everyone named in [alsoReady]. Alice is the target. With three players, Bob alone ready leaves 2
    /// to go, and Bob plus Charlie leaves 1.
    Future<void> pumpVoteWaiting(WidgetTester tester, {required Set<String> alsoReady}) async {
      final players = [
        PlayerState(id: 'p1', name: 'Alice', isHost: true),
        PlayerState(id: 'p2', name: 'Bob'),
        PlayerState(id: 'p3', name: 'Charlie'),
      ];
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        isTimerDisabled: true,
        cards: [
          CardModel(
            promptText: 'What is Alice secret truth?',
            targetPlayerId: 'p1',
            truthAnswer: 'Alice Real Truth',
            sabotageAnswers: {'p2': 'Bob Forgery', 'p3': 'Charlie Forgery'},
            options: [
              CardAnswerOption(id: 'opt1', text: 'Alice Real Truth'),
              CardAnswerOption(id: 'opt2', text: 'Bob Forgery'),
              CardAnswerOption(id: 'opt3', text: 'Charlie Forgery'),
            ],
          ),
        ],
        readyPlayers: {'p2': true, for (final id in alsoReady) id: true},
      );
      gameService.debugSetState(state, players, 'p2');
      await pumpScreen(tester, const Phase3VoteScreen());
      expect(find.text('YOUR BALLOT IS SEALED'), findsOneWidget, reason: 'the screen must be the vote waiting screen');
    }

    testWidgets('craft: one player still writing reads "Waiting for 1 player..."', (tester) async {
      await pumpCraftWaiting(tester, count: 2);

      expect(find.text('Waiting for 1 player...'), findsOneWidget);
      expect(find.text('Waiting for 1 players...'), findsNothing);
    });

    testWidgets('craft: two players still writing read "Waiting for 2 players..."', (tester) async {
      await pumpCraftWaiting(tester, count: 3);

      expect(find.text('Waiting for 2 players...'), findsOneWidget);
      expect(find.text('Waiting for 2 player...'), findsNothing);
    });

    testWidgets('vote: one player still to vote reads "Waiting for 1 player..."', (tester) async {
      await pumpVoteWaiting(tester, alsoReady: {'p3'});

      expect(find.text('Waiting for 1 player...'), findsOneWidget);
      expect(find.text('Waiting for 1 players...'), findsNothing);
    });

    testWidgets('vote: two players still to vote read "Waiting for 2 players..."', (tester) async {
      await pumpVoteWaiting(tester, alsoReady: {});

      expect(find.text('Waiting for 2 players...'), findsOneWidget);
      expect(find.text('Waiting for 2 player...'), findsNothing);
    });
  });
}
