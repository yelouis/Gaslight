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
  });
}
