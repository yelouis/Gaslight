import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inline House Rules Panel Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupRoomAndPump(WidgetTester tester, {
      required bool isHost,
      int sabotageAnswersCount = 2,
      bool isTimerDisabled = false,
      double textScale = 1.0,
    }) async {
      const roomCode = 'TEST';
      final currentUserId = 'player_1';

      final hostPlayer = PlayerState(
        id: isHost ? currentUserId : 'host_user',
        name: isHost ? 'HostUser' : 'OtherHost',
        isHost: true,
        joinedAt: 100,
      );

      final guestPlayer = PlayerState(
        id: isHost ? 'guest_user' : currentUserId,
        name: isHost ? 'GuestUser' : 'GuestUser',
        isHost: false,
        joinedAt: 200,
      );

      final p3 = PlayerState(id: 'p3', name: 'Player 3', isHost: false, joinedAt: 300);
      final p4 = PlayerState(id: 'p4', name: 'Player 4', isHost: false, joinedAt: 400);
      final p5 = PlayerState(id: 'p5', name: 'Player 5', isHost: false, joinedAt: 500);
      final p6 = PlayerState(id: 'p6', name: 'Player 6', isHost: false, joinedAt: 600);

      final gameState = GameState(
        roomCode: roomCode,
        totalPlayers: 6,
        forgeriesPerCard: sabotageAnswersCount,
        isTimerDisabled: isTimerDisabled,
      );

      await mockDb.collection('rooms').doc(roomCode).set(gameState.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(hostPlayer.id).set(hostPlayer.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(guestPlayer.id).set(guestPlayer.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p3.id).set(p3.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p4.id).set(p4.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p5.id).set(p5.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p6.id).set(p6.toMap());

      gameService.listenToRoom(roomCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', roomCode);
      await prefs.setString('player_id', currentUserId);
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                accessibleNavigation: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: const LobbyScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Host can edit rounds 1-5 and toggle timers in inline panel', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: true);

        expect(find.text('HOUSE RULES'), findsOneWidget);
        expect(find.text('5'), findsNWidgets(2));

        final chip5 = find.text('5').first;
        await tester.ensureVisible(chip5);
        await tester.pump();
        await tester.tap(chip5);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(gameService.gameState?.sabotageAnswersCount, equals(5));

        final timerSwitch = find.widgetWithText(SwitchListTile, 'Disable Game Timers');
        await tester.ensureVisible(timerSwitch);
        await tester.pump();
        await tester.tap(timerSwitch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(gameService.gameState?.isTimerDisabled, isTrue);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Non-host cannot edit — panel ignored and caption shown', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: false);

        expect(find.text('HOUSE RULES'), findsOneWidget);
        expect(find.text('Only the host can modify house rules.'), findsOneWidget);

        final chip5 = find.text('5').first;
        await tester.ensureVisible(chip5);
        await tester.pump();
        await tester.tap(chip5, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(gameService.gameState?.sabotageAnswersCount, equals(2));

        final timerSwitch = find.widgetWithText(SwitchListTile, 'Disable Game Timers');
        await tester.ensureVisible(timerSwitch);
        await tester.pump();
        await tester.tap(timerSwitch, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(gameService.gameState?.isTimerDisabled, isFalse);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Values stream from Firestore game state', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: false, sabotageAnswersCount: 5);

        final chip5 = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '5').first);
        expect(chip5.selected, isTrue);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('createRoom uses creation default of 2 rounds', (tester) async {
      try {
        await gameService.createRoom('HostUser', 'player_1');
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        expect(gameService.gameState?.sabotageAnswersCount, equals(2));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Family-Friendly Decks Only is host-only', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: false);
        expect(find.text('Family-Friendly Decks Only'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Family-Friendly Decks Only is present for the host', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: true);
        expect(find.text('Family-Friendly Decks Only'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('genuine house rules remain visible to non-hosts', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: false);
        expect(find.text('HOUSE RULES'), findsOneWidget);
        expect(find.text('Forgeries Per Card:'), findsOneWidget);
        expect(find.text('Rounds:'), findsOneWidget);
        expect(find.text('Disable Game Timers'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('AppBar contains leave and sound icon buttons and inline panel exists', (tester) async {
      try {
        await setupRoomAndPump(tester, isHost: true);
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.byType(IconButton)),
          findsNWidgets(2),
        );
        expect(find.text('HOUSE RULES'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('non-host Parlor layout fits 360x640 portrait without overflow at scale 1.0 and 1.3', (tester) async {
      try {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await setupRoomAndPump(tester, isHost: false, textScale: 1.0);
        expect(tester.takeException(), isNull);

        await setupRoomAndPump(tester, isHost: false, textScale: 1.3);
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('client updateLobbySettings payload omits untouched keys', (tester) async {
      try {
        final fakeFunctions = FakeFirebaseFunctions(mockDb);
        final customGameService = GameService(db: mockDb, functions: fakeFunctions);

        const roomCode = 'TEST';
        final currentUserId = 'player_1';
        final hostPlayer = PlayerState(id: currentUserId, name: 'HostUser', isHost: true, joinedAt: 100);
        final gameState = GameState(roomCode: roomCode, totalPlayers: 1, sabotageAnswersCount: 2, isTimerDisabled: false);

        await mockDb.collection('rooms').doc(roomCode).set(gameState.toMap());
        await mockDb.collection('rooms').doc(roomCode).collection('players').doc(hostPlayer.id).set(hostPlayer.toMap());

        customGameService.listenToRoom(roomCode);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', roomCode);
        await prefs.setString('player_id', currentUserId);
        await customGameService.tryRejoinSession();

        await customGameService.updateLobbySettings(selectedDeckId: 'custom');

        expect(fakeFunctions.lastCallName, equals('updateLobbySettings'));
        final payload = fakeFunctions.lastCallParams;
        expect(payload, isNotNull);
        expect(payload!.containsKey('roomCode'), isTrue);
        expect(payload['selectedDeckId'], equals('custom'));
        expect(payload.containsKey('sabotageAnswersCount'), isFalse);
        expect(payload.containsKey('isTimerDisabled'), isFalse);

        customGameService.dispose();
      } finally {
        gameService.dispose();
      }
    });
  });
}
