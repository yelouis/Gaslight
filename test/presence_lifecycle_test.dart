import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 112 (M2): Presence Resume Hook & Heartbeat Lifecycle Widget Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final testGameState = GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.lobby,
      currentRound: 1,
      totalRounds: 3,
      totalPlayers: 3,
      sabotageAnswersCount: 1,
      forgeriesPerCard: 1,
      selectedDeckId: PromptDecks.fallbackDeckId,
    );

    final testPlayer = PlayerState(
      id: 'p_test',
      name: 'Alice',
      isHost: true,
      joinedAt: 100,
      lastSeen: 1000,
      lobbyReady: false,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      mockDb.data['rooms/TEST'] = testGameState.toMap();
      mockDb.data['rooms/TEST/players/p_test'] = testPlayer.toMap();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('AppLifecycleState.resumed immediately writes lastSeen without advancing 10s of timer cadence', (WidgetTester tester) async {
      // 1. Join room session (starts heartbeat and registers WidgetsBindingObserver)
      await gameService.joinRoom('TEST', 'Alice', 'p_test', avatarIndex: 0);
      await tester.pumpAndSettle();

      // Seed an initial stale lastSeen timestamp
      const initialTimestamp = 50000;
      mockDb.data['rooms/TEST/players/p_test']['lastSeen'] = initialTimestamp;

      // 2. Dispatch AppLifecycleState.resumed directly to the binding
      final resumeTimeBefore = DateTime.now().millisecondsSinceEpoch;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      // Pump 0 milliseconds (immediate async microtask processing, NOT 10 seconds of timer cadence)
      await tester.pump(Duration.zero);

      final updatedLastSeen = mockDb.data['rooms/TEST/players/p_test']['lastSeen'] as int;
      expect(updatedLastSeen, isNotNull);
      expect(updatedLastSeen, greaterThanOrEqualTo(resumeTimeBefore));
      expect(updatedLastSeen, isNot(equals(initialTimestamp)));

      gameService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('Heartbeat timer continues periodic 10s ticks after resume restart', (WidgetTester tester) async {
      await gameService.joinRoom('TEST', 'Alice', 'p_test', avatarIndex: 0);
      await tester.pumpAndSettle();

      // Dispatch resume to trigger immediate write & timer restart
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);
      final resumedTimestamp = mockDb.data['rooms/TEST/players/p_test']['lastSeen'] as int;

      // Advance 10 seconds to verify the periodic timer is actively ticking on its cadence
      await tester.pump(const Duration(seconds: 10));
      final tickTimestamp = mockDb.data['rooms/TEST/players/p_test']['lastSeen'] as int;
      expect(tickTimestamp, greaterThanOrEqualTo(resumedTimestamp));

      gameService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('Over-reach guard: no observer write occurs when stopHeartbeat is invoked', (WidgetTester tester) async {
      await gameService.joinRoom('TEST', 'Alice', 'p_test', avatarIndex: 0);
      await tester.pumpAndSettle();

      // Disable heartbeat / remove observer via stopHeartbeat
      gameService.stopHeartbeat();

      const sentinelTimestamp = 99999;
      mockDb.data['rooms/TEST/players/p_test']['lastSeen'] = sentinelTimestamp;

      // Dispatch resume
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);

      // Verify lastSeen was NOT modified
      expect(mockDb.data['rooms/TEST/players/p_test']['lastSeen'], equals(sentinelTimestamp));

      gameService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('Over-reach guard: dispose removes observer and leaves no lingering callbacks', (WidgetTester tester) async {
      await gameService.joinRoom('TEST', 'Alice', 'p_test', avatarIndex: 0);
      await tester.pumpAndSettle();

      // Dispose service
      gameService.dispose();
      await tester.pump(Duration.zero);

      const sentinelTimestamp = 88888;
      mockDb.data['rooms/TEST/players/p_test']['lastSeen'] = sentinelTimestamp;

      // Dispatch resume to binding after dispose
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);

      // Verify lastSeen was NOT updated after disposal
      expect(mockDb.data['rooms/TEST/players/p_test']['lastSeen'], equals(sentinelTimestamp));
    });
  });
}
