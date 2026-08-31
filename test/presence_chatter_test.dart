// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

class CountingFakeFirestore extends FakeFirestore {
  int lastSeenWriteCount = 0;

  @override
  FakeCollectionReference collection(String collectionPath) {
    return CountingFakeCollectionReference(this, collectionPath);
  }
}

class CountingFakeCollectionReference extends FakeCollectionReference {
  final CountingFakeFirestore countingFirestore;
  CountingFakeCollectionReference(this.countingFirestore, String path) : super(countingFirestore, path);

  @override
  FakeDocumentReference<Map<String, dynamic>> doc([String? path]) {
    final docPath = path != null ? '${this.path}/$path' : '${this.path}/auto_id';
    return CountingFakeDocumentReference(countingFirestore, docPath);
  }
}

class CountingFakeDocumentReference extends FakeDocumentReference<Map<String, dynamic>> {
  final CountingFakeFirestore countingFirestore;
  CountingFakeDocumentReference(this.countingFirestore, String path) : super(countingFirestore, path);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return CountingFakeCollectionReference(countingFirestore, '$path/$collectionPath');
  }

  @override
  Future<void> update(Map<Object, Object?> data) async {
    if (data.containsKey('lastSeen')) {
      countingFirestore.lastSeenWriteCount++;
    }
    return super.update(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 142: Presence Chatter & Battery Optimization (U3)', () {
    late CountingFakeFirestore mockDb;
    late FakeFirebaseFunctions mockFunctions;

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

    final hostPlayer = PlayerState(
      id: 'p_host',
      name: 'Alice',
      isHost: true,
      joinedAt: 100,
      lastSeen: 1000,
      lobbyReady: false,
    );

    final guestPlayer = PlayerState(
      id: 'p_guest',
      name: 'Bob',
      isHost: false,
      joinedAt: 101,
      lastSeen: 1000,
      lobbyReady: false,
    );

    setUp(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({});
      mockDb = CountingFakeFirestore();
      mockDb.data['rooms/TEST'] = testGameState.toMap();
      mockDb.data['rooms/TEST/players/p_host'] = hostPlayer.copyWith(lastSeen: now).toMap();
      mockDb.data['rooms/TEST/players/p_guest'] = guestPlayer.copyWith(lastSeen: now).toMap();
      mockFunctions = FakeFirebaseFunctions(mockDb);
    });

    testWidgets('1. Cadence: 60s of elapsed time produces exactly 2 heartbeat writes (30s interval), not 6', (tester) async {
      final gameService = GameService(db: mockDb, functions: mockFunctions);
      await gameService.joinRoom('TEST', 'Alice', 'p_host', avatarIndex: 0);
      await tester.pumpAndSettle();

      mockDb.lastSeenWriteCount = 0;

      // Advance 60s in 10s increments
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 10));
      }

      expect(mockDb.lastSeenWriteCount, equals(2), reason: '60s at 30s cadence must produce exactly 2 writes, not 6');

      gameService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('2. Rebuild suppression: snapshot with only lastSeen changed does NOT notify listeners, real change DOES', (tester) async {
      final gameService = GameService(db: mockDb, functions: mockFunctions);
      await gameService.joinRoom('TEST', 'Alice', 'p_host', avatarIndex: 0);
      await tester.pumpAndSettle();

      int notifyCount = 0;
      gameService.addListener(() {
        notifyCount++;
      });

      // 1. Deliver snapshot whose ONLY change is lastSeen on Bob (current timestamp, not stale)
      final now = DateTime.now().millisecondsSinceEpoch;
      final updatedBobLastSeen = guestPlayer.copyWith(lastSeen: now);
      mockDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').set(updatedBobLastSeen.toMap());
      await tester.pump(Duration.zero);

      expect(notifyCount, equals(0), reason: 'lastSeen-only snapshot must NOT trigger notifyListeners()');

      // 2. Deliver snapshot with real change (e.g. lobbyReady toggle)
      final updatedBobReady = guestPlayer.copyWith(lastSeen: now, lobbyReady: true);
      mockDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').set(updatedBobReady.toMap());
      await tester.pump(Duration.zero);

      expect(notifyCount, greaterThanOrEqualTo(1), reason: 'Real player state change MUST trigger notifyListeners()');

      gameService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('3a. Non-host triggers 0 handleDisconnect calls for stale presence', (tester) async {
      final nonHostService = GameService(db: mockDb, functions: mockFunctions);
      await nonHostService.joinRoom('TEST', 'Bob', 'p_guest', avatarIndex: 1);
      await tester.pumpAndSettle();

      final initialDisconnectCalls = mockFunctions.callableInvocations['handleDisconnect'] ?? 0;

      // Seed a stale player (lastSeen 5 minutes ago)
      final stalePlayer = PlayerState(
        id: 'p_stale',
        name: 'Charlie',
        isHost: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch - 300000,
        joinedAt: 50,
      );
      mockDb.collection('rooms').doc('TEST').collection('players').doc('p_stale').set(stalePlayer.toMap());
      await tester.pump(const Duration(milliseconds: 50));

      final nonHostCalls = (mockFunctions.callableInvocations['handleDisconnect'] ?? 0) - initialDisconnectCalls;
      expect(nonHostCalls, equals(0), reason: 'Non-host must NOT fire handleDisconnect for stale presence');

      nonHostService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('3b. Host triggers <= 5 handleDisconnect calls over 5 minutes with 60s cooldown against repeated snapshots', (tester) async {
      final hostService = GameService(db: mockDb, functions: mockFunctions);
      await hostService.joinRoom('TEST', 'Alice', 'p_host', avatarIndex: 0);
      await tester.pumpAndSettle();

      final stalePlayer = PlayerState(
        id: 'p_stale',
        name: 'Charlie',
        isHost: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch - 300000,
        joinedAt: 50,
      );
      mockDb.collection('rooms').doc('TEST').collection('players').doc('p_stale').set(stalePlayer.toMap());
      await tester.pump(Duration.zero);

      final hostStartCalls = mockFunctions.callableInvocations['handleDisconnect'] ?? 0;

      // Trigger 10 snapshots over 5 simulated minutes (every 30s)
      for (int i = 0; i < 10; i++) {
        mockDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').set(
          guestPlayer.copyWith(lastSeen: DateTime.now().millisecondsSinceEpoch + (i + 1) * 1000).toMap(),
        );
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(seconds: 30));
      }

      final hostCalls = (mockFunctions.callableInvocations['handleDisconnect'] ?? 0) - hostStartCalls;
      expect(hostCalls, lessThanOrEqualTo(5), reason: 'Host must be throttled by 60s cooldown, max 5 calls over 5 minutes');

      hostService.dispose();
      await tester.pump(Duration.zero);
    });

    testWidgets('4. Backgrounding: AppLifecycleState.paused stops heartbeat timer; resumed restarts it with immediate write', (tester) async {
      final lifecycleService = GameService(db: mockDb, functions: mockFunctions);
      await lifecycleService.joinRoom('TEST', 'Alice', 'p_host', avatarIndex: 0);
      await tester.pumpAndSettle();

      const initialTimestamp = 1000;
      mockDb.data['rooms/TEST/players/p_host']['lastSeen'] = initialTimestamp;

      // Push paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(Duration.zero);

      // Advance 5 minutes (300 seconds)
      await tester.pump(const Duration(minutes: 5));

      // Assert 0 writes occurred during paused state
      expect(mockDb.data['rooms/TEST/players/p_host']['lastSeen'], equals(initialTimestamp));

      // Push resumed
      final resumeTime = DateTime.now().millisecondsSinceEpoch;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(Duration.zero);

      final resumedTimestamp = mockDb.data['rooms/TEST/players/p_host']['lastSeen'] as int;
      expect(resumedTimestamp, greaterThanOrEqualTo(resumeTime));

      lifecycleService.dispose();
      await tester.pump(Duration.zero);
    });
  });
}
