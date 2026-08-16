import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lobby Start Game Readiness Gate Widget Tests', () {
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

    final guest2Unready = PlayerState(
      id: 'p_g2',
      name: 'Charlie',
      isHost: false,
      joinedAt: 300,
      lobbyReady: false,
    );

    final guest2Ready = PlayerState(
      id: 'p_g2',
      name: 'Charlie',
      isHost: false,
      joinedAt: 300,
      lobbyReady: true,
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

    testWidgets('START GAME is disabled with warning text when a non-host is unready, and enabled when all are ready', (WidgetTester tester) async {
      // 1. Unready non-host state: 1 of 2 ready
      gameService.debugSetState(lobbyGameState, [hostPlayer, guest1, guest2Unready], 'p_host');

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

      // Warning text should be visible
      expect(find.text('Waiting on 1 of 2 players to ready up.'), findsOneWidget);

      // PrimaryButton 'START GAME' should be disabled (onPressed == null)
      final unreadyButtonFinder = find.widgetWithText(PrimaryButton, 'START GAME');
      expect(unreadyButtonFinder, findsOneWidget);
      final unreadyButton = tester.widget<PrimaryButton>(unreadyButtonFinder);
      expect(unreadyButton.onPressed, isNull);

      // 2. Ready non-host state: 2 of 2 ready (Host's own lobbyReady is still false)
      gameService.debugSetState(lobbyGameState, [hostPlayer, guest1, guest2Ready], 'p_host');
      await tester.pumpAndSettle();

      // Warning text should be gone
      expect(find.text('Waiting on 1 of 2 players to ready up.'), findsNothing);

      // PrimaryButton 'START GAME' should now be enabled (onPressed != null)
      final readyButtonFinder = find.widgetWithText(PrimaryButton, 'START GAME');
      expect(readyButtonFinder, findsOneWidget);
      final readyButton = tester.widget<PrimaryButton>(readyButtonFinder);
      expect(readyButton.onPressed, isNotNull);
    });
  });
}
