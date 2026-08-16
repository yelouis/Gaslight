import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lobby Host Kick Control Widget Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final hostPlayer = PlayerState(
      id: 'p_host',
      name: 'Alice',
      isHost: true,
      joinedAt: 100,
      lobbyReady: false,
    );

    final guest1 = PlayerState(
      id: 'p_g1',
      name: 'Bob',
      isHost: false,
      joinedAt: 200,
      lobbyReady: true,
    );

    final guest2 = PlayerState(
      id: 'p_g2',
      name: 'Charlie',
      isHost: false,
      joinedAt: 300,
      lobbyReady: false,
    );

    final lobbyGameState = GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.lobby,
      currentRound: 1,
      totalRounds: 3,
      totalPlayers: 3,
      sabotageAnswersCount: 1,
      forgeriesPerCard: 1,
      selectedDeckId: 'the_daily_grind',
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('remove control renders for host on non-host rows and not on host row', (WidgetTester tester) async {
      gameService.debugSetState(lobbyGameState, [hostPlayer, guest1, guest2], 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: LobbyScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Host row must NOT have a kick control
      expect(find.byKey(const ValueKey('kick_p_host')), findsNothing);

      // Non-host rows MUST have a kick control
      expect(find.byKey(const ValueKey('kick_p_g1')), findsOneWidget);
      expect(find.byKey(const ValueKey('kick_p_g2')), findsOneWidget);

      // Tapping kick control opens confirmation dialog
      await tester.tap(find.byKey(const ValueKey('kick_p_g1')));
      await tester.pumpAndSettle();

      expect(find.text('Remove player?'), findsOneWidget);
      expect(find.text('Remove Bob from this room? They can rejoin with the room code.'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('REMOVE'), findsOneWidget);
    });

    testWidgets('remove control does not render for non-host viewer on any row', (WidgetTester tester) async {
      gameService.debugSetState(lobbyGameState, [hostPlayer, guest1, guest2], 'p_g1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: LobbyScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-host viewer must NOT see any kick controls
      expect(find.byKey(const ValueKey('kick_p_host')), findsNothing);
      expect(find.byKey(const ValueKey('kick_p_g1')), findsNothing);
      expect(find.byKey(const ValueKey('kick_p_g2')), findsNothing);
    });
  });
}
