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

  group('Lobby Parlor Sheet Draggable Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupAndPumpParlor(WidgetTester tester, {int playerCount = 1}) async {
      const roomCode = 'TEST';
      final hostPlayer = PlayerState(
        id: 'host_user',
        name: 'HostUser',
        isHost: true,
        joinedAt: 100,
      );

      final gameState = GameState(
        roomCode: roomCode,
        totalPlayers: playerCount,
        sabotageAnswersCount: 2,
      );

      await mockDb.collection('rooms').doc(roomCode).set(gameState.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(hostPlayer.id).set(hostPlayer.toMap());

      for (int i = 2; i <= playerCount; i++) {
        final p = PlayerState(
          id: 'player_$i',
          name: 'Player $i',
          joinedAt: 100 + i * 10,
        );
        await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p.id).set(p.toMap());
      }

      gameService.listenToRoom(roomCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', roomCode);
      await prefs.setString('player_id', 'host_user');
      await gameService.tryRejoinSession();

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: const LobbyScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('Header drag moves sheet down on 1-player short roster', (tester) async {
      try {
        await setupAndPumpParlor(tester, playerCount: 1);

        final headerText = find.text('1 SUSPECTS JOINED');
        expect(headerText, findsOneWidget);

        final initialTop = tester.getTopLeft(headerText).dy;

        // Drag down on header text '1 SUSPECTS JOINED'
        await tester.drag(headerText, const Offset(0, 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final currentTop = tester.getTopLeft(headerText).dy;
        // Dragging down moves the sheet header DOWN (greater dy value)
        expect(currentTop, greaterThan(initialTop));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Header tap toggles sheet expansion', (tester) async {
      try {
        await setupAndPumpParlor(tester, playerCount: 1);

        final headerText = find.text('1 SUSPECTS JOINED');
        final initialTop = tester.getTopLeft(headerText).dy;

        // Tap header to expand to 0.7 (header moves UP, smaller dy)
        await tester.tap(headerText);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final expandedTop = tester.getTopLeft(headerText).dy;
        expect(expandedTop, lessThan(initialTop));

        // Tap header again to collapse to 0.25 (header moves DOWN, larger dy)
        await tester.tap(headerText);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final collapsedTop = tester.getTopLeft(headerText).dy;
        expect(collapsedTop, greaterThan(expandedTop));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Grid scrolls independently when sheet is expanded with 10 players', (tester) async {
      try {
        await setupAndPumpParlor(tester, playerCount: 10);

        final headerText = find.text('10 SUSPECTS JOINED');

        // Expand sheet to max
        await tester.tap(headerText);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        final expandedTop = tester.getTopLeft(headerText).dy;

        // Roster player item
        final gridItem = find.text('Player 2');
        expect(gridItem, findsOneWidget);

        await tester.drag(gridItem, const Offset(0, -100));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Sheet extent stays expanded at same top position
        final endTop = tester.getTopLeft(headerText).dy;
        expect(endTop, equals(expandedTop));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('No memory leak on dispose', (tester) async {
      await setupAndPumpParlor(tester, playerCount: 1);
      await tester.pumpWidget(Container());
      expect(tester.takeException(), isNull);
      gameService.dispose();
    });
  });
}
