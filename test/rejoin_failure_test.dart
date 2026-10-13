import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'helpers/rendered_contrast.dart';
import 'simulation_test.dart';

/// Issue 183 / AI10: auto-rejoin must keep the saved seat on a transient failure.
///
/// On launch `LobbyScreen` calls `tryRejoinSession()`, which re-binds through the `joinRoom`
/// callable. Until now ANY exception from that call removed `seat_token_<room>`,
/// `room_code` and `player_id` and the lobby said "Your session expired" -- including a
/// dropped connection (on iOS that arrives as `unknown`) or a failed anonymous sign-in
/// (`unauthenticated`). Only a definitive rejection (`not-found`, `permission-denied`,
/// `invalid-argument`) or a missing room / player document may clear the seat.
/// A Firestore that cannot be reached: the very first read throws, as a cold start with no
/// connection and an empty cache does. That exception is raised OUTSIDE the `joinRoom` call.
class _UnreachableFirestore extends FakeFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable', message: 'offline');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tryRejoinSession keeps or clears the saved seat (Issue 183 / AI10)', () {
    const room = 'ABCD';
    const playerId = 'p1';
    const seatToken = 'tok';

    late FakeFirestore db;
    late FakeFirebaseFunctions functions;
    late GameService gs;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'room_code': room,
        'player_id': playerId,
        'seat_token_$room': seatToken,
      });
      db = FakeFirestore();
      functions = FakeFirebaseFunctions(db);
      gs = GameService(db: db, functions: functions);
      addTearDown(gs.dispose);
    });

    Future<void> seedRoom({bool withRoom = true, bool withPlayer = true}) async {
      if (withRoom) {
        await db.collection('rooms').doc(room).set(GameState(roomCode: room, totalPlayers: 1).toMap());
      }
      if (withPlayer) {
        await db
            .collection('rooms')
            .doc(room)
            .collection('players')
            .doc(playerId)
            .set(PlayerState(id: playerId, name: 'Alice', isHost: true, joinedAt: 1).toMap());
      }
    }

    void joinRoomThrows(Object error) {
      functions.overrideCallable('joinRoom', (_) async => throw error);
    }

    /// Each of the three keys, by name.
    Future<Map<String, String?>> savedKeys() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        'room_code': prefs.getString('room_code'),
        'player_id': prefs.getString('player_id'),
        'seat_token_$room': prefs.getString('seat_token_$room'),
      };
    }

    Future<void> expectSeatKept() async {
      expect(await savedKeys(), {'room_code': room, 'player_id': playerId, 'seat_token_$room': seatToken});
    }

    Future<void> expectSeatCleared() async {
      expect(await savedKeys(), {'room_code': null, 'player_id': null, 'seat_token_$room': null});
    }

    // Cases 1-4: a transient failure keeps the seat.
    final transient = <String, Object>{
      'unknown': FirebaseFunctionsException(code: 'unknown', message: 'x'),
      'unavailable': FirebaseFunctionsException(code: 'unavailable', message: 'x'),
      'unauthenticated': FirebaseFunctionsException(code: 'unauthenticated', message: 'x'),
      'a plain Exception': Exception('x'),
    };
    for (final entry in transient.entries) {
      test('joinRoom throws ${entry.key}: false, connection, all three keys still present', () async {
        await seedRoom();
        joinRoomThrows(entry.value);

        expect(await gs.tryRejoinSession(), isFalse);
        expect(gs.lastRejoinFailure, RejoinFailure.connection);
        await expectSeatKept();
      });
    }

    // Cases 5-6: a definitive rejection clears it.
    for (final code in ['not-found', 'permission-denied', 'invalid-argument']) {
      test('joinRoom throws $code: false, expired, all three keys removed', () async {
        await seedRoom();
        joinRoomThrows(FirebaseFunctionsException(code: code, message: 'x'));

        expect(await gs.tryRejoinSession(), isFalse);
        expect(gs.lastRejoinFailure, RejoinFailure.expired);
        await expectSeatCleared();
      });
    }

    // Other server-side codes are not a verdict on the seat: keep it.
    for (final code in ['deadline-exceeded', 'internal', 'resource-exhausted', 'failed-precondition']) {
      test('joinRoom throws $code: false, connection, seat kept', () async {
        await seedRoom();
        joinRoomThrows(FirebaseFunctionsException(code: code, message: 'x'));

        expect(await gs.tryRejoinSession(), isFalse);
        expect(gs.lastRejoinFailure, RejoinFailure.connection);
        await expectSeatKept();
      });
    }

    // The room / player read itself can fail before joinRoom is ever called.
    test('Firestore unreachable on the first read: false, connection, all three keys still present', () async {
      final offline = GameService(db: _UnreachableFirestore(), functions: functions);
      addTearDown(offline.dispose);

      expect(await offline.tryRejoinSession(), isFalse);
      expect(offline.lastRejoinFailure, RejoinFailure.connection);
      await expectSeatKept();
    });

    // Case 7: success.
    test('success through the default fake: true, none, the saved seat token untouched', () async {
      await seedRoom();

      expect(await gs.tryRejoinSession(), isTrue);
      expect(gs.lastRejoinFailure, RejoinFailure.none);
      expect(gs.gameState, isNotNull);
      await expectSeatKept();
    });

    test('success returning a fresh seat token: true, none, seat_token holds the returned token', () async {
      await seedRoom();
      functions.overrideCallable('joinRoom', (_) async => {'seatToken': 'tok2'});

      expect(await gs.tryRejoinSession(), isTrue);
      expect(gs.lastRejoinFailure, RejoinFailure.none);
      final keys = await savedKeys();
      expect(keys['seat_token_$room'], 'tok2');
      expect(keys['room_code'], room);
      expect(keys['player_id'], playerId);
    });

    // Case 8: the room or the player document is gone.
    test('room document absent: false, expired, keys removed', () async {
      await seedRoom(withRoom: false, withPlayer: false);

      expect(await gs.tryRejoinSession(), isFalse);
      expect(gs.lastRejoinFailure, RejoinFailure.expired);
      await expectSeatCleared();
    });

    test('room present but player document absent: false, expired, keys removed', () async {
      await seedRoom(withPlayer: false);

      expect(await gs.tryRejoinSession(), isFalse);
      expect(gs.lastRejoinFailure, RejoinFailure.expired);
      await expectSeatCleared();
    });

    test('nothing saved: false, none, and nothing was invented', () async {
      SharedPreferences.setMockInitialValues({});
      await seedRoom();

      expect(await gs.tryRejoinSession(), isFalse);
      expect(gs.lastRejoinFailure, RejoinFailure.none);
      expect(await savedKeys(), {'room_code': null, 'player_id': null, 'seat_token_$room': null});
    });

    test('the verdict is reset by the next attempt', () async {
      await seedRoom();
      joinRoomThrows(FirebaseFunctionsException(code: 'unknown', message: 'x'));
      expect(await gs.tryRejoinSession(), isFalse);
      expect(gs.lastRejoinFailure, RejoinFailure.connection);

      functions.overrideCallable('joinRoom', (_) async => {'seatToken': 'tok2'});
      expect(await gs.tryRejoinSession(), isTrue);
      expect(gs.lastRejoinFailure, RejoinFailure.none);
    });
  });

  group('LobbyScreen reports an auto-rejoin failure truthfully (Issue 183 / AI10)', () {
    const connection = 'Could not reach the parlour. Check your connection and try again.';
    const expired = 'Your session expired — please rejoin.';
    const rejoined = 'Rejoined active game session!';

    late FakeFirestore db;
    late FakeFirebaseFunctions functions;
    late GameService gameService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'room_code': 'ABCD',
        'player_id': 'p1',
        'seat_token_ABCD': 'tok',
      });
      db = FakeFirestore();
      functions = FakeFirebaseFunctions(db);
      gameService = GameService(db: db, functions: functions);
      await db.collection('rooms').doc('ABCD').set(GameState(roomCode: 'ABCD', totalPlayers: 1).toMap());
      await db
          .collection('rooms')
          .doc('ABCD')
          .collection('players')
          .doc('p1')
          .set(PlayerState(id: 'p1', name: 'Alice', isHost: true, joinedAt: 1).toMap());
    });

    Future<void> pumpLobby(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
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
      // Known-empty start (lesson 2.47): nothing is on screen before the rejoin answers.
      expect(find.byType(SnackBar), findsNothing);
    }

    Future<Map<String, String?>> savedKeys() async {
      final prefs = await SharedPreferences.getInstance();
      return {
        'room_code': prefs.getString('room_code'),
        'player_id': prefs.getString('player_id'),
        'seat_token_ABCD': prefs.getString('seat_token_ABCD'),
      };
    }

    testWidgets('unknown: the connection sentence with RETRY, the seat is kept, and RETRY rejoins', (tester) async {
      try {
        var offline = true;
        functions.overrideCallable('joinRoom', (_) async {
          if (offline) throw FirebaseFunctionsException(code: 'unknown', message: 'x');
          return {'seatToken': 'tok2'};
        });

        await pumpLobby(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SnackBar), findsOneWidget, reason: 'exactly one SnackBar');
        expect(find.text(connection), findsOneWidget);
        expect(find.text('RETRY'), findsOneWidget);
        expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, const Duration(seconds: 10),
            reason: 'long enough to read and reach RETRY');
        expect(find.text(expired), findsNothing, reason: 'a dropped connection is not an expired session');
        expect(find.text(rejoined), findsNothing);
        expect(await savedKeys(), {'room_code': 'ABCD', 'player_id': 'p1', 'seat_token_ABCD': 'tok'});
        expect(gameService.gameState, isNull);
        expect(tester.takeException(), isNull);

        // The connection comes back (the override stops failing); the host taps RETRY.
        offline = false;
        await tester.tap(find.text('RETRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text(rejoined), findsOneWidget);
        expect(find.text(connection), findsNothing);
        expect(gameService.gameState, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('unknown twice: RETRY while still offline shows the sentence again, once', (tester) async {
      try {
        functions.overrideCallable('joinRoom', (_) async => throw FirebaseFunctionsException(code: 'unknown', message: 'x'));

        await pumpLobby(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(connection), findsOneWidget);

        await tester.tap(find.text('RETRY'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(connection), findsOneWidget);
        expect(find.text('RETRY'), findsOneWidget);
        expect(await savedKeys(), {'room_code': 'ABCD', 'player_id': 'p1', 'seat_token_ABCD': 'tok'});
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('a SnackBar already on screen is replaced by the connection sentence, not queued behind it', (tester) async {
      try {
        final gate = Completer<void>();
        functions.overrideCallable('joinRoom', (_) async {
          await gate.future;
          throw FirebaseFunctionsException(code: 'unknown', message: 'x');
        });

        await pumpLobby(tester);
        await tester.pump();
        // Something else is on screen when the failure arrives.
        ScaffoldMessenger.of(tester.element(find.byType(LobbyScreen)))
            .showSnackBar(const SnackBar(content: Text('stale')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('stale'), findsOneWidget);

        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('stale'), findsNothing, reason: 'queued behind it, it would stay for its full 4 s');
        expect(find.text(connection), findsOneWidget);
        expect(find.text('RETRY'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('the RETRY label and the sentence are readable on the SnackBar, measured from pixels (>= 4.5 : 1)', (tester) async {
      try {
        functions.overrideCallable('joinRoom', (_) async => throw FirebaseFunctionsException(code: 'unknown', message: 'x'));
        // The real GaslightApp, so the SnackBar takes the PRODUCTION theme: an unstyled
        // SnackBarAction takes its colour from the theme, which a plain MaterialApp cannot show.
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final rootBoundary = GlobalKey(debugLabel: 'rootBoundary');
        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: RepaintBoundary(key: rootBoundary, child: const GaslightApp()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('RETRY'), findsOneWidget);

        final retry = await measureRenderedContrast(tester, rootBoundary, find.text('RETRY'));
        final sentence = await measureRenderedContrast(tester, rootBoundary, find.text(connection));
        debugPrint('RETRY rendered contrast ${retry.ratio.toStringAsFixed(2)} '
            '(${retry.foreground} on ${retry.background}); sentence ${sentence.ratio.toStringAsFixed(2)}');
        expect(sentence.ratio, greaterThanOrEqualTo(4.5), reason: 'the sentence measured ${sentence.ratio}');
        expect(retry.ratio, greaterThanOrEqualTo(4.5),
            reason: 'RETRY measured ${retry.ratio.toStringAsFixed(2)} : 1 (${retry.foreground} on ${retry.background}); '
                'an unstyled SnackBarAction takes the theme colour, which is invisible on this dark SnackBar');
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('not-found: the expired sentence, no RETRY, the seat is cleared', (tester) async {
      try {
        functions.overrideCallable('joinRoom', (_) async => throw FirebaseFunctionsException(code: 'not-found', message: 'x'));

        await pumpLobby(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text(expired), findsOneWidget);
        expect(find.text(connection), findsNothing);
        expect(find.text('RETRY'), findsNothing);
        expect(await savedKeys(), {'room_code': null, 'player_id': null, 'seat_token_ABCD': null});
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('a rejoin that fails after the screen is gone is swallowed quietly', (tester) async {
      try {
        final gate = Completer<void>();
        functions.overrideCallable('joinRoom', (_) async {
          await gate.future;
          throw FirebaseFunctionsException(code: 'unknown', message: 'x');
        });

        await pumpLobby(tester);
        await tester.pump();
        // The app moves on (or the screen is rebuilt) while the rejoin is still in flight.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'ScaffoldMessenger.of(context) on a disposed screen throws unless _attemptRejoin checks mounted');
        expect(await savedKeys(), {'room_code': 'ABCD', 'player_id': 'p1', 'seat_token_ABCD': 'tok'});
      } finally {
        gameService.dispose();
      }
    });
  });
}
