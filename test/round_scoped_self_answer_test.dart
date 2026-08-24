// Your own forgery must be locked out on every round, not just the first.
//
// Cards are identified by `targetPlayerId`, which repeats every round, so the
// per-card caches in GameService collided across rounds: in round 2 the lockout
// consulted round 1's option id and round 1's text, matched neither live
// option, and quietly let the player vote for their own lie.
//
// Falsified against the un-scoped caches: both round-2 assertions below failed.
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;
  // What the server would hand back for the current round's card.
  late String serverOptionId;

  GameState stateForRound(int round) => GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        currentRound: round,
        totalRounds: 3,
        totalPlayers: 3,
        sabotageAnswersCount: 1,
        forgeriesPerCard: 1,
        selectedDeckId: 'the_daily_grind',
      );

  final table = [
    PlayerState(id: 'p_me', name: 'Me', isHost: true, joinedAt: 100),
    PlayerState(id: 'p_target', name: 'Target', isHost: false, joinedAt: 200),
    PlayerState(id: 'p_other', name: 'Other', isHost: false, joinedAt: 300),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    // Stubbed so the test exercises the CACHE KEY, not the fake's room fixtures.
    serverOptionId = 'opt-round-1';
    fakeFns.overrideCallable('submitAnswer', (params) async => {'success': true});
    fakeFns.overrideCallable('getMyOptionId', (params) async => {'optionId': serverOptionId});
    gameService = GameService(db: mockDb, functions: fakeFns);
  });

  tearDown(() => gameService.dispose());

  test('a forgery written in round 1 does not leak into round 2', () async {
    gameService.debugSetState(stateForRound(1), table, 'p_me');
    await gameService.submitCardAnswer('p_target', 'p_me', 'my round one lie', false);
    expect(gameService.isMySubmittedAnswer('p_target', 'my round one lie'), isTrue,
        reason: 'round 1 lockout must work');

    // Same card id — targetPlayerId repeats every round — but a new round.
    gameService.debugSetState(stateForRound(2), table, 'p_me');
    expect(
      gameService.isMySubmittedAnswer('p_target', 'my round one lie'),
      isFalse,
      reason: "last round's answer must not block an option on this round's card",
    );

    await gameService.submitCardAnswer('p_target', 'p_me', 'my round two lie', false);
    expect(
      gameService.isMySubmittedAnswer('p_target', 'my round two lie'),
      isTrue,
      reason: 'the round-2 forgery is what must be locked out in round 2',
    );
  });

  test('a cached option id from round 1 is not reused in round 2', () async {
    gameService.debugSetState(stateForRound(1), table, 'p_me');
    await gameService.fetchMyOptionId('p_target');
    expect(gameService.getMyOptionIdForCard('p_target'), 'opt-round-1');

    // Same card id, new round: the round-1 id must not be served again.
    gameService.debugSetState(stateForRound(2), table, 'p_me');
    serverOptionId = 'opt-round-2';
    expect(
      gameService.getMyOptionIdForCard('p_target'),
      isNull,
      reason: "round 2 must not answer with round 1's cached option id",
    );

    await gameService.fetchMyOptionId('p_target');
    expect(gameService.getMyOptionIdForCard('p_target'), 'opt-round-2');
  });
}
