import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart'; // import FakeFirestore

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 91 / X1: fetchMyOptionId in-flight guard & cache behavior', () {
    /*
     * Falsification run against unmodified GameService (without in-flight guard):
     * Expected: duplicate in-flight call to fetchMyOptionId('card_a') issues 1 callable invocation
     * Observed failure:
     *   Expected: <1>
     *     Actual: <2>
     *   Counts duplicate in-flight call as 2 invocations instead of 1.
     */

    late FakeFirestore mockDb;
    late FakeFirebaseFunctions fakeFunctions;
    late GameService gameService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: fakeFunctions);

      final p1 = PlayerState(id: 'p1', name: 'Alice', role: PlayerRole.voter, isHost: true);
      final p2 = PlayerState(id: 'p2', name: 'Bob', role: PlayerRole.voter);

      final cardA = CardModel(
        promptText: 'Prompt A',
        targetPlayerId: 'card_a',
        truthAnswer: 'truth_a',
        sabotageAnswers: {'p1': 'lie_a'},
        options: [
          CardAnswerOption(id: 'opt_a1', text: 'truth_a'),
          CardAnswerOption(id: 'opt_a2', text: 'lie_a'),
        ],
      );
      final cardB = CardModel(
        promptText: 'Prompt B',
        targetPlayerId: 'card_b',
        truthAnswer: 'truth_b',
        sabotageAnswers: {'p1': 'lie_b'},
        options: [
          CardAnswerOption(id: 'opt_b1', text: 'truth_b'),
          CardAnswerOption(id: 'opt_b2', text: 'lie_b'),
        ],
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 2,
        currentReaderId: 'card_a',
        cards: [cardA, cardB],
        currentCardAssignments: {'p1': 'card_a', 'p2': 'card_b'},
        readyPlayers: {},
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      for (var p in [p1, p2]) {
        await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(
          p.toMap()..['authUid'] = 'uid_${p.id}',
        );
      }
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('card_a').set({
        'truthAnswer': 'truth_a',
        'sabotageAnswers': {'p1': 'lie_a'},
        'answerAuthors': {'opt_a1': 'card_a', 'opt_a2': 'p1'},
      });
      await mockDb.collection('rooms').doc('TEST').collection('sealed').doc('card_b').set({
        'truthAnswer': 'truth_b',
        'sabotageAnswers': {'p1': 'lie_b'},
        'answerAuthors': {'opt_b1': 'card_b', 'opt_b2': 'p1'},
      });

      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'p1');
      await gameService.tryRejoinSession();
      // Allow snapshot stream to settle
      await Future.delayed(const Duration(milliseconds: 50));
    });

    tearDown(() async {
      await gameService.leaveRoom();
    });

    test('falsification: duplicate in-flight calls for same card issue exactly one callable invocation', () async {
      final gate = Completer<void>();
      fakeFunctions.getMyOptionIdCompleter = gate;
      fakeFunctions.getMyOptionIdCallCount = 0;

      // Issue two calls concurrently without awaiting
      final future1 = gameService.fetchMyOptionId('card_a');
      final future2 = gameService.fetchMyOptionId('card_a');

      // Assert only 1 callable invocation was issued
      expect(fakeFunctions.getMyOptionIdCallCount, 1,
          reason: 'Duplicate in-flight fetch for same card must be guarded');

      // Second call returned null immediately (or completes with same id)
      final immediateRes2 = await future2;
      expect(immediateRes2, isNull, reason: 'In-flight guard returns null to allow fallback');

      // Complete gate
      gate.complete();
      final res1 = await future1;
      expect(res1, 'opt_a2');

      // Subsequent call uses cache and does not increment call count
      final cachedRes = await gameService.fetchMyOptionId('card_a');
      expect(cachedRes, 'opt_a2');
      expect(fakeFunctions.getMyOptionIdCallCount, 1,
          reason: 'Completed card must read from cache without refetching');
    });

    test('over-reach guard: fetch for different card while another is in-flight is NOT blocked', () async {
      final gate = Completer<void>();
      fakeFunctions.getMyOptionIdCompleter = gate;
      fakeFunctions.getMyOptionIdCallCount = 0;

      // Start fetch for card_a (now in-flight)
      final futureA = gameService.fetchMyOptionId('card_a');
      expect(fakeFunctions.getMyOptionIdCallCount, 1);

      // Start fetch for card_b (different card)
      final futureB = gameService.fetchMyOptionId('card_b');
      expect(fakeFunctions.getMyOptionIdCallCount, 2,
          reason: 'Fetch for a different card must issue its own callable invocation');

      gate.complete();
      final resA = await futureA;
      final resB = await futureB;
      expect(resA, 'opt_a2');
      expect(resB, 'opt_b2');
    });

    test('wedge check: exception during callable does not permanently wedge in-flight set (finally guard)', () async {
      fakeFunctions.getMyOptionIdCallCount = 0;
      fakeFunctions.overrideCallable('getMyOptionId', (params) async {
        throw Exception('Simulated network failure');
      });

      // First fetch throws and catches
      final res1 = await gameService.fetchMyOptionId('card_a');
      expect(res1, isNull);

      // Clear override by overriding with valid result:
      fakeFunctions.overrideCallable('getMyOptionId', (params) async {
        return {'optionId': 'opt_recovered'};
      });

      // Second fetch should NOT be blocked by stale in-flight marker
      final res2 = await gameService.fetchMyOptionId('card_b');
      expect(res2, isNotNull);
    });
  });
}
