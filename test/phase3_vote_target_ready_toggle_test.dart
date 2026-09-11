import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase3VoteScreen target ready toggle tests (AA8 / Issue 161)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie');

    final card1 = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      options: [
        CardAnswerOption(id: 'opt1', text: 'Alice Truth Answer'),
        CardAnswerOption(id: 'opt2', text: 'Bob Forgery Answer'),
        CardAnswerOption(id: 'opt3', text: 'Charlie Forgery Answer'),
      ],
    );

    final card2 = CardModel(
      promptText: 'What is Bob secret truth?',
      targetPlayerId: 'p2',
      options: [
        CardAnswerOption(id: 'opt4', text: 'Bob Truth Answer'),
        CardAnswerOption(id: 'opt5', text: 'Alice Forgery Answer'),
        CardAnswerOption(id: 'opt6', text: 'Charlie Forgery Answer 2'),
      ],
    );

    final card3 = CardModel(
      promptText: 'What is Alice second secret truth?',
      targetPlayerId: 'p1',
      options: [
        CardAnswerOption(id: 'opt7', text: 'Alice Truth Answer 2'),
        CardAnswerOption(id: 'opt8', text: 'Bob Forgery Answer 2'),
        CardAnswerOption(id: 'opt9', text: 'Charlie Forgery Answer 3'),
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

    Future<void> setupVoteRoom(WidgetTester tester, {String currentReaderId = 'p1', Map<String, bool>? readyPlayers}) async {
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: currentReaderId,
        cards: [card1, card2, card3],
        currentCardAssignments: {'p1': 'p1', 'p2': 'p2', 'p3': 'p3'},
        readyPlayers: readyPlayers ?? {},
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
      await prefs.setString('player_id', 'p1'); // Alice is logged in
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('Test 1: target taps I\'M READY, sees NOT READY, taps again, is un-readied', (WidgetTester tester) async {
      await setupVoteRoom(tester, currentReaderId: 'p1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();

      // Initial state: Target sees "I'M READY"
      expect(find.text("I'M READY"), findsOneWidget);
      expect(find.text('NOT READY'), findsNothing);

      // Tap "I'M READY"
      await tester.tap(find.text("I'M READY"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Target sees "NOT READY" and readyPlayers reflects ready
      expect(find.text('NOT READY'), findsOneWidget);
      expect(find.text("I'M READY"), findsNothing);
      expect(gameService.gameState?.readyPlayers['p1'], isTrue);

      // Tap "NOT READY" to un-ready
      await tester.tap(find.text('NOT READY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Target sees "I'M READY" again and is un-readied in server state
      expect(find.text("I'M READY"), findsOneWidget);
      expect(find.text('NOT READY'), findsNothing);
      expect(gameService.gameState?.readyPlayers['p1'], isFalse);

      await gameService.leaveRoom();
    });

    testWidgets('Test 2: after a reader change, button reflects new card readiness and is not stuck from previous card (no re-pump)', (WidgetTester tester) async {
      await setupVoteRoom(tester, currentReaderId: 'p1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();

      // Card 1: Target taps "I'M READY" -> sees "NOT READY"
      expect(find.text("I'M READY"), findsOneWidget);
      await tester.tap(find.text("I'M READY"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('NOT READY'), findsOneWidget);
      expect(gameService.gameState?.readyPlayers['p1'], isTrue);

      // Advance to Card 2 without re-pumping Phase3VoteScreen widget!
      // In Card 2, reader is p2 (Alice is a voter)
      await mockDb.collection('rooms').doc('TEST').update({
        'currentReaderId': 'p2',
        'readyPlayers': {},
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // As a voter on Card 2, Alice sees CONFIRM VOTE (not target ready buttons)
      expect(find.text('CONFIRM VOTE'), findsOneWidget);
      expect(find.text("I'M READY"), findsNothing);
      expect(find.text('NOT READY'), findsNothing);

      // Now advance to Card 3 without re-pumping!
      // On Card 3, Alice is the target again (currentReaderId: 'p1'), and readyPlayers is empty
      await mockDb.collection('rooms').doc('TEST').update({
        'currentReaderId': 'p1',
        'readyPlayers': {},
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The button must reflect Card 3's readiness ("I'M READY") and NOT be stuck at "NOT READY" from Card 1!
      expect(find.text("I'M READY"), findsOneWidget, reason: 'Button must show I\'M READY and not be stuck from Card 1');
      expect(find.text('NOT READY'), findsNothing);

      await gameService.leaveRoom();
    });
  });
}
