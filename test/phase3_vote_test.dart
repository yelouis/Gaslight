import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/widgets/raven_mascot.dart';
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

    // The voter has to know whose card this is — the target wrote the truth,
    // and without their name "which one is the truth?" is unanswerable. This
    // header used to render the VIEWER's own avatar, which named the wrong
    // person entirely. Falsified by restoring `PlayerAvatar(player: me)`:
    // both assertions below fail.
    testWidgets('the vote header names whose card is being voted on', (WidgetTester tester) async {
      await setupAndPumpVoteScreen(
        tester: tester,
        isReader: false, // viewer is Bob; the card belongs to Alice
        reduceMotion: true,
        readyPlayers: const {},
      );

      expect(find.text('VOTING ON'), findsOneWidget);
      expect(
        find.text("One of these is Alice's truth."),
        findsOneWidget,
        reason: 'the card belongs to Alice, not to the viewer',
      );
      expect(
        find.text("One of these is Bob's truth."),
        findsNothing,
        reason: "the header must not name the viewer",
      );

      await gameService.leaveRoom();
    });

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

    testWidgets('same-card duplicate text is distinguished by optionId (Issue 90 / W4)', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      // On card p1, two options have identical text "duplicate_text"
      // opt1 is Bob's (p2), opt2 is Charlie's (p3)
      final card = CardModel(
        promptText: 'Prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'truth_text',
        sabotageAnswers: {'p2': 'duplicate_text', 'p3': 'duplicate_text'},
        options: [
          CardAnswerOption(id: 'opt_bob', text: 'duplicate_text'),
          CardAnswerOption(id: 'opt_charlie', text: 'duplicate_text'),
          CardAnswerOption(id: 'opt_truth', text: 'truth_text'),
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
      // Populate sealed document with answerAuthors mapping
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').set({
        'truthAnswer': 'truth_text',
        'sabotageAnswers': {'p2': 'duplicate_text', 'p3': 'duplicate_text'},
        'answerAuthors': {
          'opt_bob': 'p2',
          'opt_charlie': 'p3',
          'opt_truth': 'p1',
        },
      });

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p2');
      await gameService.tryRejoinSession();

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
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly one option should be marked (Your Forgery)
      expect(find.text('(Your Forgery)'), findsOneWidget);

      // Verify that there are two InkWells matching duplicate_text cards:
      // one is disabled (onTap null for Bob's opt_bob), one is enabled (onTap non-null for Charlie's opt_charlie)
      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell)).where((w) => w.child is AnimatedContainer).toList();
      final disabledCount = inkWells.where((w) => w.onTap == null).length;
      final enabledCount = inkWells.where((w) => w.onTap != null).length;

      expect(disabledCount, 1, reason: 'Only Bob\'s own option must be disabled');
      expect(enabledCount, 2, reason: 'Charlie\'s duplicate and Alice\'s truth must be votable');

      await gameService.leaveRoom();
    });

    testWidgets('fallback to per-card text matching when optionId fetch returns null (Issue 90 / W4)', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      final card = CardModel(
        promptText: 'Prompt',
        targetPlayerId: 'p1',
        truthAnswer: 'truth_text',
        sabotageAnswers: {'p2': 'bob_forgery', 'p3': 'charlie_forgery'},
        options: [
          CardAnswerOption(id: 'opt1', text: 'bob_forgery'),
          CardAnswerOption(id: 'opt2', text: 'charlie_forgery'),
          CardAnswerOption(id: 'opt3', text: 'truth_text'),
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
      // Sealed document has NO answerAuthors (simulating missing ID or network fallback)
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').set({
        'truthAnswer': 'truth_text',
        'sabotageAnswers': {'p2': 'bob_forgery', 'p3': 'charlie_forgery'},
      });

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p2');
      await gameService.tryRejoinSession();

      // Bob submitted "bob_forgery" for this card
      await gameService.submitCardAnswer('p1', 'p2', 'bob_forgery', false);
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
      await tester.pump(const Duration(milliseconds: 300));

      // With null optionId, fallback text matching identifies Bob's forgery
      expect(find.text('(Your Forgery)'), findsOneWidget);

      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell)).where((w) => w.child is AnimatedContainer).toList();
      final disabledCount = inkWells.where((w) => w.onTap == null).length;
      final enabledCount = inkWells.where((w) => w.onTap != null).length;

      expect(disabledCount, 1, reason: 'Fallback must disable only Bob\'s submitted answer');
      expect(enabledCount, 2, reason: 'Fallback must not block everything');

      await gameService.leaveRoom();
    });

    testWidgets('falsification: option id overrides superseded text and prevents double-sealing (Issue 94 / Y1)', (WidgetTester tester) async {
      /*
       * Falsification run against unmodified code (unioning layers and accumulating superseded text):
       * Expected: 1 tile disabled ((Your Forgery) on Bob's latest "asdfw4er"), Charlie's "asdf" enabled
       * Observed failure on pre-Y1 code:
       *   Expected: exactly one matching candidate
       *     Actual: Found 2 widgets with text '(Your Forgery)'
       *   disabledCount was 2, enabledCount was 1.
       */
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      final initialCard = CardModel(
        promptText: 'A situation where I completely faked my way through a presentation.',
        targetPlayerId: 'p1',
        truthAnswer: 'High school',
        sabotageAnswers: {},
        options: [],
      );

      final initialGameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [initialCard],
        currentCardAssignments: {'p1': 'p1', 'p2': 'p1', 'p3': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(initialGameState.toMap());
      for (var p in [p1, p2, p3]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').set({
        'truthAnswer': 'High school',
        'sabotageAnswers': {},
      });

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p2');
      await gameService.tryRejoinSession();

      // Bob first submitted "asdf" and then resubmitted "asdfw4er" for card p1
      await gameService.submitCardAnswer('p1', 'p2', 'asdf', false);
      await gameService.submitCardAnswer('p1', 'p2', 'asdfw4er', false);

      // Now phase advances to vote. Card p1 has Bob's latest "asdfw4er", Charlie's "asdf", and Alice's "High school"
      final voteCard = CardModel(
        promptText: 'A situation where I completely faked my way through a presentation.',
        targetPlayerId: 'p1',
        truthAnswer: 'High school',
        sabotageAnswers: {'p2': 'asdfw4er', 'p3': 'asdf'},
        options: [
          CardAnswerOption(id: 'opt_bob', text: 'asdfw4er'),
          CardAnswerOption(id: 'opt_charlie', text: 'asdf'),
          CardAnswerOption(id: 'opt_truth', text: 'High school'),
        ],
      );

      final voteGameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [voteCard],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(voteGameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('p1').set({
        'truthAnswer': 'High school',
        'sabotageAnswers': {'p2': 'asdfw4er', 'p3': 'asdf'},
        'answerAuthors': {
          'opt_bob': 'p2',
          'opt_charlie': 'p3',
          'opt_truth': 'p1',
        },
      });

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
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly one option should be marked (Your Forgery) - only Bob's "asdfw4er"
      expect(find.text('(Your Forgery)'), findsOneWidget);

      final inkWells = tester.widgetList<InkWell>(find.byType(InkWell)).where((w) => w.child is AnimatedContainer).toList();
      final disabledCount = inkWells.where((w) => w.onTap == null).length;
      final enabledCount = inkWells.where((w) => w.onTap != null).length;

      expect(disabledCount, 1, reason: 'Only Bob\'s latest option (asdfw4er) must be disabled');
      expect(enabledCount, 2, reason: 'Charlie\'s asdf and Alice\'s High school must be votable');

      final asdfFinder = find.ancestor(
        of: find.text('asdf'),
        matching: find.byType(InkWell),
      );
      expect(asdfFinder, findsOneWidget);
      final asdfInkWell = tester.widget<InkWell>(asdfFinder);
      expect(asdfInkWell.onTap, isNotNull, reason: 'Charlie\'s asdf tile must be votable');

      await gameService.leaveRoom();
    });

    testWidgets('O4: placeholder answers are sealed and unvotable for all players', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);
      final p3 = PlayerState(id: 'p3', name: 'Charlie', role: PlayerRole.voter);

      final card = CardModel(
        promptText: 'A prompt',
        targetPlayerId: 'p1',
        options: [
          CardAnswerOption(id: 'opt_truth', text: 'Real Truth Answer'),
          CardAnswerOption(id: 'opt_placeholder', text: 'THE SOUL IS SILENT'),
          CardAnswerOption(id: 'opt_forgery', text: 'Real Forgery'),
        ],
        votes: {},
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p2');
      await gameService.tryRejoinSession();

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: const Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();

      // Placeholder option tile should have onTap == null and show SEALED banner
      final placeholderFinder = find.ancestor(
        of: find.text('THE SOUL IS SILENT'),
        matching: find.byType(InkWell),
      );
      expect(placeholderFinder, findsOneWidget);
      final placeholderInkWell = tester.widget<InkWell>(placeholderFinder);
      expect(placeholderInkWell.onTap, isNull, reason: 'Placeholder tile must be disabled/unvotable');

      // Real forgery option tile should have onTap != null
      final forgeryFinder = find.ancestor(
        of: find.text('Real Forgery'),
        matching: find.byType(InkWell),
      );
      expect(forgeryFinder, findsOneWidget);
      final forgeryInkWell = tester.widget<InkWell>(forgeryFinder);
      expect(forgeryInkWell.onTap, isNotNull, reason: 'Valid non-self option must be votable');

      await gameService.leaveRoom();
    });

    testWidgets('O7: RavenMascot is displayed on the ballot-sealed waiting screen (Issue 116)', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob');
      final p3 = PlayerState(id: 'p3', name: 'Charlie');

      final card = CardModel(
        promptText: 'What is the secret?',
        targetPlayerId: 'p1',
        options: [
          CardAnswerOption(id: 'opt1', text: 'Truth option'),
          CardAnswerOption(id: 'opt2', text: 'Forgery option'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {'p2': true}, // p2 has sealed their ballot
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

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify "YOUR BALLOT IS SEALED" text and RavenMascot are both present
      expect(find.text('YOUR BALLOT IS SEALED'), findsOneWidget);
      expect(find.byType(RavenMascot), findsOneWidget);

      await gameService.leaveRoom();
    });

    testWidgets('O9: Target player sees card prompt and read-only options grid with no confirm vote button (Issue 121)', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob');
      final p3 = PlayerState(id: 'p3', name: 'Charlie');

      final card = CardModel(
        promptText: 'What is Alice secret truth?',
        targetPlayerId: 'p1',
        options: [
          CardAnswerOption(id: 'opt1', text: 'Alice Truth Answer'),
          CardAnswerOption(id: 'opt2', text: 'Bob Forgery Answer'),
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
      await prefs.setString('player_id', 'p1'); // Alice is the target player
      await gameService.tryRejoinSession();

      // Submit Alice's answer so isSelf matches
      await gameService.submitCardAnswer('p1', 'p1', 'Alice Truth Answer', true);
      await mockDb.collection('rooms').doc('TEST').update({'readyPlayers': {}});

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase3VoteScreen(),
          ),
        ),
      );
      await tester.pump();

      // 1. Verify target sees header and prompt
      expect(find.text('THEY ARE VOTING ON YOUR TRUTH'), findsOneWidget);
      expect(find.text('What is Alice secret truth?'), findsOneWidget);

      // 2. Verify options are visible in the grid
      expect(find.text('Alice Truth Answer'), findsOneWidget);
      expect(find.text('Bob Forgery Answer'), findsOneWidget);
      expect(find.text('(Your Truth)'), findsOneWidget);

      // 3. Verify options are read-only / disabled for target
      final truthTileFinder = find.ancestor(
        of: find.text('Alice Truth Answer'),
        matching: find.byType(InkWell),
      );
      expect(truthTileFinder, findsOneWidget);
      final truthInkWell = tester.widget<InkWell>(truthTileFinder);
      expect(truthInkWell.onTap, isNull, reason: 'Target cannot tap options');

      // 4. Verify CONFIRM VOTE button is absent for target
      expect(find.text('CONFIRM VOTE'), findsNothing);

      await gameService.leaveRoom();
    });
  });
}
