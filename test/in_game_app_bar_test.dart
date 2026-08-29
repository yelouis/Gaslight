import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late GameService gameService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
  });

  Future<void> setupAndPumpScreen({
    required WidgetTester tester,
    required Widget child,
    required GamePhase phase,
    double width = 375,
    double height = 812,
    double textScale = 1.0,
  }) async {
    final localPlayer = PlayerState(
      id: 'local_player_id',
      name: 'Alice',
      joinedAt: 100,
      isHost: true,
    );
    final guestPlayer = PlayerState(
      id: 'guest_id',
      name: 'Bob',
      joinedAt: 200,
    );

    final card1 = CardModel(
      targetPlayerId: 'local_player_id',
      promptText: 'Is this real life?',
      truthAnswer: 'Truth answer 1',
      sabotageAnswers: {'guest_id': 'Alice lie 1'},
    );
    final card2 = CardModel(
      targetPlayerId: 'guest_id',
      promptText: 'Or is this fantasy?',
      truthAnswer: 'Truth answer 2',
      sabotageAnswers: {'local_player_id': 'Bob lie 1'},
    );

    final gameState = GameState(
      roomCode: 'TEST',
      currentPhase: phase,
      totalPlayers: 2,
      cards: [card1, card2],
      currentCardAssignments: {
        'local_player_id': 'guest_id',
        'guest_id': 'local_player_id',
      },
      currentRotationIndex: 1,
      sabotageAnswersCount: 2,
      currentReaderId: 'guest_id',
      readyPlayers: {},
    );

    await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
    await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
      localPlayer.toMap()..['authUid'] = 'local_auth_uid',
    );
    await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(
      guestPlayer.toMap()..['authUid'] = 'guest_auth_uid',
    );

    SharedPreferences.setMockInitialValues({
      'room_code': 'TEST',
      'player_id': 'local_player_id',
    });

    gameService.listenToRoom('TEST');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('room_code', 'TEST');
    await prefs.setString('player_id', 'local_player_id');
    await tester.runAsync(() async {
      await gameService.tryRejoinSession();
    });

    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(
      ChangeNotifierProvider<GameService>.value(
        value: gameService,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              accessibleNavigation: true,
              size: Size(width, height),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1000));
  }

  tearDown(() {
    gameService.dispose();
  });

  group('Issue 136: In-Game AppBar Sizing (R1)', () {
    testWidgets('Falsifying test: Forgery phase rotation label fits inside AppBar bounds', (tester) async {
      await setupAndPumpScreen(
        tester: tester,
        child: const Phase2CraftScreen(),
        phase: GamePhase.forgery,
        width: 375,
        textScale: 1.0,
      );

      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);
      final appBarRenderBox = tester.renderObject<RenderBox>(appBarFinder);
      final appBarBottom = appBarRenderBox.localToGlobal(Offset.zero).dy + appBarRenderBox.size.height;

      final rotationFinder = find.text('Rotation 1 of 2');
      expect(rotationFinder, findsOneWidget);
      final rotationRenderBox = tester.renderObject<RenderBox>(rotationFinder);
      final rotationBottom = rotationRenderBox.localToGlobal(Offset.zero).dy + rotationRenderBox.size.height;

      // The rotation text must be completely contained within the AppBar height bounds
      expect(
        rotationBottom,
        lessThanOrEqualTo(appBarBottom),
        reason: 'Rotation text bottom ($rotationBottom) must be inside AppBar bottom ($appBarBottom)',
      );
    });

    final widths = [320.0, 375.0, 430.0];
    final textScales = [1.0, 1.3, 2.0];

    for (final width in widths) {
      for (final textScale in textScales) {
        testWidgets('Matrix: Forgery rotation label fits at width $width, textScale $textScale', (tester) async {
          await setupAndPumpScreen(
            tester: tester,
            child: const Phase2CraftScreen(),
            phase: GamePhase.forgery,
            width: width,
            textScale: textScale,
          );

          final appBarFinder = find.byType(AppBar);
          expect(appBarFinder, findsOneWidget);
          final appBarRenderBox = tester.renderObject<RenderBox>(appBarFinder);
          final appBarBottom = appBarRenderBox.localToGlobal(Offset.zero).dy + appBarRenderBox.size.height;

          final rotationFinder = find.text('Rotation 1 of 2');
          expect(rotationFinder, findsOneWidget);
          final rotationRenderBox = tester.renderObject<RenderBox>(rotationFinder);
          final rotationBottom = rotationRenderBox.localToGlobal(Offset.zero).dy + rotationRenderBox.size.height;

          expect(
            rotationBottom,
            lessThanOrEqualTo(appBarBottom),
            reason: 'At width $width, scale $textScale: rotationBottom ($rotationBottom) <= appBarBottom ($appBarBottom)',
          );
        });
      }
    }

    testWidgets('Over-reach guard: Truth phase (2 lines) is shorter than Forgery phase (3 lines) at textScale 1.0', (tester) async {
      await setupAndPumpScreen(
        tester: tester,
        child: const Phase2CraftScreen(),
        phase: GamePhase.truth,
        width: 375,
        textScale: 1.0,
      );

      final truthAppBarBox = tester.renderObject<RenderBox>(find.byType(AppBar));
      final truthHeight = truthAppBarBox.size.height;

      await setupAndPumpScreen(
        tester: tester,
        child: const Phase2CraftScreen(),
        phase: GamePhase.forgery,
        width: 375,
        textScale: 1.0,
      );

      final forgeryAppBarBox = tester.renderObject<RenderBox>(find.byType(AppBar));
      final forgeryHeight = forgeryAppBarBox.size.height;

      expect(
        truthHeight,
        lessThan(forgeryHeight),
        reason: 'Truth AppBar height ($truthHeight) must be less than Forgery AppBar height ($forgeryHeight)',
      );
    });

    testWidgets('Over-reach guard: Vote screen AppBar renders cleanly at textScale 1.0 and 2.0', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await setupAndPumpScreen(
          tester: tester,
          child: const Phase3VoteScreen(),
          phase: GamePhase.vote,
          width: 375,
          textScale: scale,
        );

        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBarRenderBox = tester.renderObject<RenderBox>(appBarFinder);
        final appBarBottom = appBarRenderBox.localToGlobal(Offset.zero).dy + appBarRenderBox.size.height;

        final roomCodeFinder = find.text('ROOM: TEST');
        expect(roomCodeFinder, findsOneWidget);
        final roomCodeRenderBox = tester.renderObject<RenderBox>(roomCodeFinder);
        final roomCodeBottom = roomCodeRenderBox.localToGlobal(Offset.zero).dy + roomCodeRenderBox.size.height;

        expect(
          roomCodeBottom,
          lessThanOrEqualTo(appBarBottom),
          reason: 'Vote screen at scale $scale: roomCodeBottom ($roomCodeBottom) <= appBarBottom ($appBarBottom)',
        );
      }
    });

    testWidgets('Over-reach guard: Reveal screen AppBar renders cleanly at textScale 1.0 and 2.0', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await setupAndPumpScreen(
          tester: tester,
          child: const Phase4RevealScreen(),
          phase: GamePhase.reveal,
          width: 375,
          textScale: scale,
        );

        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBarRenderBox = tester.renderObject<RenderBox>(appBarFinder);
        final appBarBottom = appBarRenderBox.localToGlobal(Offset.zero).dy + appBarRenderBox.size.height;

        final roomCodeFinder = find.text('ROOM: TEST');
        expect(roomCodeFinder, findsOneWidget);
        final roomCodeRenderBox = tester.renderObject<RenderBox>(roomCodeFinder);
        final roomCodeBottom = roomCodeRenderBox.localToGlobal(Offset.zero).dy + roomCodeRenderBox.size.height;

        expect(
          roomCodeBottom,
          lessThanOrEqualTo(appBarBottom),
          reason: 'Reveal screen at scale $scale: roomCodeBottom ($roomCodeBottom) <= appBarBottom ($appBarBottom)',
        );
      }
    });
  });
}
