import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 51: Room Closed Lifecycle', () {
    late FakeFirestore fakeDb;
    late FakeFirebaseFunctions fakeFunctions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeDb = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(fakeDb);
      gameService = GameService(db: fakeDb, functions: fakeFunctions);
    });

    tearDown(() {
      gameService.dispose();
    });

    test('deleting room document sets roomClosed to true and clears gameState', () async {
      // 1. Create a room
      await gameService.createRoom('Host', 'p_host');
      await Future.delayed(Duration.zero);
      expect(gameService.gameState, isNotNull);
      expect(gameService.roomClosed, isFalse);

      final roomCode = gameService.gameState!.roomCode;

      // 2. Delete room document via doc ref (simulating server deletion on host disconnect)
      await fakeDb.collection('rooms').doc(roomCode).delete();
      await Future.delayed(Duration.zero);

      // 3. Assert roomClosed == true and gameState == null
      expect(gameService.gameState, isNull);
      expect(gameService.roomClosed, isTrue);
    });

    test('leaveRoom performs teardown and invokes handleDisconnect callable exactly once (over-reach guard)', () async {
      await gameService.createRoom('Host', 'p_host');
      await Future.delayed(Duration.zero);
      expect(gameService.gameState, isNotNull);
      expect(gameService.currentPlayerId, equals('p_host'));

      await gameService.leaveRoom();

      expect(gameService.gameState, isNull);
      expect(gameService.currentPlayerId, isNull);
      expect(fakeFunctions.callableInvocations['handleDisconnect'], equals(1));
    });
  });
}
