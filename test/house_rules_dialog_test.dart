import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/widgets/house_rules_dialog.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HouseRulesDialog Tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> setupRoom({
      required bool isHost,
      int sabotageAnswersCount = 2,
      bool isTimerDisabled = false,
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

      final gameState = GameState(
        roomCode: roomCode,
        totalPlayers: 2,
        sabotageAnswersCount: sabotageAnswersCount,
        isTimerDisabled: isTimerDisabled,
      );

      await mockDb.collection('rooms').doc(roomCode).set(gameState.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(hostPlayer.id).set(hostPlayer.toMap());
      await mockDb.collection('rooms').doc(roomCode).collection('players').doc(guestPlayer.id).set(guestPlayer.toMap());

      gameService.listenToRoom(roomCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', roomCode);
      await prefs.setString('player_id', currentUserId);
      await gameService.tryRejoinSession();
    }

    testWidgets('Host can edit settings and writes to server', (tester) async {
      try {
        await setupRoom(isHost: true);

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Scaffold(
                body: HouseRulesDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.onChanged, isNotNull);

        final dropdownWidget = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
        expect(dropdownWidget.onChanged, isNotNull);

        // Tap switch to disable timers
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(gameService.gameState?.isTimerDisabled, isTrue);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Non-host cannot edit — controls disabled and explanation shown', (tester) async {
      try {
        await setupRoom(isHost: false);

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Scaffold(
                body: HouseRulesDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // FALSIFYING ASSERTION — switch onChanged must be null for non-host
        final switchWidget = tester.widget<Switch>(find.byType(Switch));
        expect(switchWidget.onChanged, isNull);

        final dropdownWidget = tester.widget<DropdownButtonFormField<int>>(find.byType(DropdownButtonFormField<int>));
        expect(dropdownWidget.onChanged, isNull);

        expect(find.textContaining('Only the host may set the house rules'), findsOneWidget);

        // Tapping switch should do nothing
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        expect(gameService.gameState?.isTimerDisabled, isFalse);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('Values stream from Firestore game state', (tester) async {
      try {
        await setupRoom(isHost: false, sabotageAnswersCount: 4);

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Scaffold(
                body: HouseRulesDialog(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('4 Rounds'), findsOneWidget);
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
  });
}
