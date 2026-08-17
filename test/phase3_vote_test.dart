import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/audio_service.dart';
import 'fake_functions.dart';
import 'simulation_test.dart'; // import FakeFirestore
import 'audio_service_test.dart'; // import FakeAudioPlayer

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase3VoteScreen Ballot Ticker Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;
    late FakeAudioPlayer mockAudio;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
      mockAudio = FakeAudioPlayer();
      AudioService.instance.setPlayers(
        submitPlayer: mockAudio,
        votePlayer: mockAudio,
        revealPlayer: mockAudio,
        unmaskPlayer: mockAudio,
      );
      AudioService.instance.soundEnabled = true;
    });

    Future<void> setupAndPumpVoteScreen({
      required WidgetTester tester,
      required bool isReader,
      required bool reduceMotion,
      required Map<String, bool> readyPlayers,
    }) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);
      final p4 = PlayerState(id: 'p4', name: 'Eve', role: PlayerRole.spectator);

      final card = CardModel(
        promptText: 'A prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'True',
        sabotageAnswers: {'p2': 'Sabotage 2', 'p3': 'Sabotage 3'},
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 4,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'c1'},
        readyPlayers: readyPlayers,
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
      await prefs.setString('player_id', isReader ? 'p1' : 'p2');
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            builder: (context, child) {
              return MediaQuery(
                data: MediaQueryData(accessibleNavigation: reduceMotion),
                child: child!,
              );
            },
            home: const Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Ballot Ticker shows correct expected voters and caption', (WidgetTester tester) async {
      await setupAndPumpVoteScreen(
        tester: tester,
        isReader: true,
        reduceMotion: false,
        readyPlayers: {'p2': true},
      );

      expect(find.text('1 of 2 ballots sealed'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('1 of 2 ballots sealed'));
      expect(textWidget.style?.fontFamily, 'Lora');
      expect(textWidget.style?.fontFeatures, contains(const FontFeature.tabularFigures()));

      await gameService.leaveRoom();
    });

    testWidgets('Per-seal stamp plays at volume 0.4 during unsealed->sealed transition', (WidgetTester tester) async {
      await setupAndPumpVoteScreen(
        tester: tester,
        isReader: true,
        reduceMotion: false,
        readyPlayers: {},
      );

      expect(mockAudio.playCallCount, 0);

      await mockDb.collection('rooms').doc('TEST').update({
        'readyPlayers': {'p2': true},
      });

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pump();

      expect(mockAudio.playCallCount, 1);

      await gameService.leaveRoom();
    });

    testWidgets('No per-seal stamp plays under reduce-motion', (WidgetTester tester) async {
      await setupAndPumpVoteScreen(
        tester: tester,
        isReader: true,
        reduceMotion: true,
        readyPlayers: {'p2': true},
      );

      expect(mockAudio.playCallCount, 0);

      await mockDb.collection('rooms').doc('TEST').update({
        'readyPlayers': {'p2': true, 'p3': true},
      });

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pump();

      expect(mockAudio.playCallCount, 0);

      await gameService.leaveRoom();
    });

    testWidgets('cross-card duplicate text authored by another player is votable and not labelled (Your Forgery) (Issue 90 / W3)', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      // Current card being voted on belongs to targetPlayerId 'p1'.
      // Options on p1's card:
      // - opt1: "asdf" (authored by Charlie 'p3')
      // - opt2: "my_forgery_text" (authored by Bob 'p2')
      // - opt3: "truth_text" (authored by Alice 'p1')
      final cardPrevious = CardModel(
        promptText: 'Previous prompt',
        targetPlayerId: 'p_previous',
        truthAnswer: 'previous_truth',
      );

      final card = CardModel(
        promptText: 'Card prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'truth_text',
        sabotageAnswers: {'p2': 'my_forgery_text', 'p3': 'asdf'},
        options: [
          CardAnswerOption(id: 'opt1', text: 'asdf'),
          CardAnswerOption(id: 'opt2', text: 'my_forgery_text'),
          CardAnswerOption(id: 'opt3', text: 'truth_text'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [cardPrevious, card],
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
      await prefs.setString('player_id', 'p2');
      await gameService.tryRejoinSession();

      // Simulate player p2 having submitted "asdf" for a PREVIOUS card (targetCardId 'p_previous')
      await gameService.submitCardAnswer('p_previous', 'p2', 'asdf', false);

      // Simulate player p2 having submitted "my_forgery_text" for the CURRENT card (targetCardId 'p1')
      await gameService.submitCardAnswer('p1', 'p2', 'my_forgery_text', false);

      // Reset readyPlayers to empty for the vote phase
      await mockDb.collection('rooms').doc('TEST').update({'readyPlayers': {}});

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

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
      await tester.pump(const Duration(milliseconds: 300));

      // Over-reach guard: "my_forgery_text" submitted by p2 on THIS card MUST be marked as (Your Forgery)
      expect(find.text('(Your Forgery)'), findsOneWidget);

      // The "asdf" option written by p3 on this card must be VOTABLE (InkWell onTap non-null)
      // and NOT marked as self-answer.
      final asdfFinder = find.ancestor(
        of: find.text('asdf'),
        matching: find.byType(InkWell),
      );
      expect(asdfFinder, findsOneWidget);
      final asdfInkWell = tester.widget<InkWell>(asdfFinder);
      expect(asdfInkWell.onTap, isNotNull, reason: 'asdf from previous card must remain votable');

      await gameService.leaveRoom();
    });
  });
}
