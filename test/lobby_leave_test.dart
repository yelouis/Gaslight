import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 50: Lobby Leave Control Tests', () {
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

    Future<void> pumpLobbyScreen(WidgetTester tester, {required bool isHost}) async {
      await tester.runAsync(() async {
        await gameService.createRoom(isHost ? 'Host' : 'Guest', isHost ? 'p_host' : 'p_guest');
        gameService.stopHeartbeat();
        if (!isHost) {
          await fakeDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').update({'isHost': false});
        }
        await Future.delayed(const Duration(milliseconds: 100));
      });

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
    }

    testWidgets('non-host can leave from the lobby', (tester) async {
      await pumpLobbyScreen(tester, isHost: false);

      // Falsifying assertion: find leave button by tooltip
      final leaveButton = find.byTooltip('Leave room');
      expect(leaveButton, findsOneWidget);

      await tester.tap(leaveButton);
      await tester.pumpAndSettle();

      // Assert exact non-host dialog copy
      expect(find.text('Leave this room?'), findsOneWidget);
      expect(find.text("You can rejoin with the room code as long as the game hasn't started."), findsOneWidget);
      expect(find.text('STAY'), findsOneWidget);
      expect(find.text('LEAVE'), findsOneWidget);

      // Tap STAY
      await tester.tap(find.text('STAY'));
      await tester.pumpAndSettle();

      expect(gameService.gameState, isNotNull);
      expect(fakeFunctions.callableInvocations['handleDisconnect'] ?? 0, 0);

      // Re-open and tap LEAVE
      await tester.tap(leaveButton);
      await tester.pumpAndSettle();
      
      expect(find.text('LEAVE'), findsOneWidget);
      await tester.tap(find.text('LEAVE'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(gameService.gameState, isNull);
      expect(fakeFunctions.callableInvocations['handleDisconnect'], 1);
    });

    testWidgets('host sees the room-closing copy', (tester) async {
      await pumpLobbyScreen(tester, isHost: true);

      final leaveButton = find.byTooltip('Leave room');
      expect(leaveButton, findsOneWidget);

      await tester.tap(leaveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Assert exact host dialog copy
      expect(find.text('Close this room?'), findsOneWidget);
      expect(find.text('You are the host. Leaving will close the room for everyone.'), findsOneWidget);
      expect(find.text('STAY'), findsOneWidget);
      expect(find.text('CLOSE ROOM'), findsOneWidget);
    });

    testWidgets('over-reach guard: sound toggle is present in actions and toggles sound', (tester) async {
      await pumpLobbyScreen(tester, isHost: true);

      final initialSound = gameService.soundEnabled;
      final soundToggle = find.byType(IconButton).last;
      expect(soundToggle, findsOneWidget);

      await tester.tap(soundToggle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(gameService.soundEnabled, !initialSound);
    });
  });
}
