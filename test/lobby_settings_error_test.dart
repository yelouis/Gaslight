import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:gaslight/widgets/deck_carousel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 186 / AI9: a host whose settings change fails must be told.
///
/// Six call sites fired `gs.updateLobbySettings(...)` with no `await` or `catch`, so a
/// failed call (offline, iOS `unknown`, a server `invalid-argument`) left the control
/// unchanged with no message and the exception escaped as an uncaught async error. The
/// Family-Friendly write-through matters most: it is what keeps the filter and the room's
/// deck in agreement (Issue 106), and when it fails silently the lobby shows a
/// family-friendly selection while the room still holds the hidden deck.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('host settings failures are reported (Issue 186 / AI9)', () {
    const connection = 'Could not reach the parlour. Check your connection and try again.';
    const rawText = 'offline-raw-text';

    late FakeFirestore mockDb;
    late FakeFirebaseFunctions functions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      functions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: functions);
    });

    /// The host's parlour with six players. [timersOn] shows the seconds field;
    /// [deckId] is the deck the room holds.
    Future<void> pumpHostParlour(
      WidgetTester tester, {
      bool timersOn = false,
      String? deckId,
    }) async {
      const roomCode = 'TEST';
      const hostId = 'player_1';
      final state = GameState(
        roomCode: roomCode,
        totalPlayers: 6,
        forgeriesPerCard: 2,
        isTimerDisabled: !timersOn,
        selectedDeckId: deckId ?? PromptDecks.fallbackDeckId,
      );
      await mockDb.collection('rooms').doc(roomCode).set(state.toMap());
      final players = [
        PlayerState(id: hostId, name: 'HostUser', isHost: true, joinedAt: 100),
        PlayerState(id: 'guest_user', name: 'GuestUser', isHost: false, joinedAt: 200),
        PlayerState(id: 'p3', name: 'Player 3', isHost: false, joinedAt: 300),
        PlayerState(id: 'p4', name: 'Player 4', isHost: false, joinedAt: 400),
        PlayerState(id: 'p5', name: 'Player 5', isHost: false, joinedAt: 500),
        PlayerState(id: 'p6', name: 'Player 6', isHost: false, joinedAt: 600),
      ];
      for (final p in players) {
        await mockDb.collection('rooms').doc(roomCode).collection('players').doc(p.id).set(p.toMap());
      }

      gameService.listenToRoom(roomCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', roomCode);
      await prefs.setString('player_id', hostId);
      await gameService.tryRejoinSession();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      // Tall enough that the house-rules card sits clear of the player sheet (40% of the
      // screen), whose edge otherwise covers the Family-Friendly toggle.
      tester.view.physicalSize = const Size(800, 2000);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      // The rejoin path shows its own SnackBar ("Rejoined active game session!"). Let it go,
      // so every SnackBar a test then sees is one of the settings messages.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SnackBar), findsNothing, reason: 'the parlour must start with no SnackBar on screen');
    }

    void failWith(Object error) {
      functions.overrideCallable('updateLobbySettings', (_) async => throw error);
    }

    FirebaseFunctionsException unavailable() => FirebaseFunctionsException(code: 'unavailable', message: rawText);

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
    }

    /// Each control that writes a house rule, with the fixture it needs.
    final controls = <String, ({bool timersOn, String? deckId, Future<void> Function(WidgetTester) act})>{
      'rounds chip (rounds_3)': (
        timersOn: false,
        deckId: null,
        act: (tester) => tapVisible(tester, find.byKey(const ValueKey('rounds_3'))),
      ),
      'forgeries chip (forgeries_3)': (
        timersOn: false,
        deckId: null,
        act: (tester) => tapVisible(tester, find.byKey(const ValueKey('forgeries_3'))),
      ),
      'timers switch': (
        timersOn: false,
        deckId: null,
        act: (tester) => tapVisible(tester, find.widgetWithText(SwitchListTile, 'Disable Game Timers')),
      ),
      'seconds field': (
        timersOn: true,
        deckId: null,
        act: (tester) async {
          final field = find.byKey(const ValueKey('timer_seconds_field'));
          await tester.ensureVisible(field);
          await tester.pump();
          await tester.enterText(field, '45');
        },
      ),
      'deck carousel': (
        timersOn: false,
        deckId: null,
        act: (tester) async {
          final pages = find.descendant(of: find.byType(DeckCarousel), matching: find.byType(PageView));
          await tester.ensureVisible(pages);
          await tester.pump();
          await tester.drag(pages, const Offset(-300, 0));
        },
      ),
      // Issue 106's write-through: hiding the room's deck must also move the room off it.
      'Family-Friendly write-through': (
        timersOn: false,
        deckId: 'rated_r_nsfw',
        act: (tester) => tapVisible(tester, find.widgetWithText(SwitchListTile, 'Family-Friendly Decks Only')),
      ),
    };

    for (final entry in controls.entries) {
      testWidgets('${entry.key}: a failed write shows the connection sentence once, no raw text, no uncaught error',
          (tester) async {
        try {
          await pumpHostParlour(tester, timersOn: entry.value.timersOn, deckId: entry.value.deckId);
          failWith(unavailable());

          await entry.value.act(tester);
          await settle(tester);

          expect(functions.callableInvocations['updateLobbySettings'], greaterThanOrEqualTo(1),
              reason: 'the control must actually have attempted the write, or this proves nothing');
          expect(find.byType(SnackBar), findsOneWidget, reason: 'exactly one SnackBar');
          expect(find.text(connection), findsOneWidget);
          expect(find.textContaining(rawText), findsNothing, reason: 'the raw exception text must never reach the screen');
          expect(tester.takeException(), isNull, reason: 'no uncaught async error');
        } finally {
          gameService.dispose();
        }
      });
    }

    for (final c in <({String name, Object error, String sentence})>[
      (
        name: 'invalid-argument',
        error: FirebaseFunctionsException(code: 'invalid-argument', message: rawText),
        sentence: "That house rule can't be set for this table.",
      ),
      (
        name: 'permission-denied',
        error: FirebaseFunctionsException(code: 'permission-denied', message: rawText),
        sentence: 'Only the host can change the house rules.',
      ),
      (
        name: 'a plain Exception',
        error: Exception('x'),
        sentence: 'Something went wrong. Try again.',
      ),
    ]) {
      testWidgets('rounds chip, ${c.name}: "${c.sentence}"', (tester) async {
        try {
          await pumpHostParlour(tester);
          failWith(c.error);

          await tapVisible(tester, find.byKey(const ValueKey('rounds_3')));
          await settle(tester);

          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.text(c.sentence), findsOneWidget);
          expect(find.textContaining(rawText), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          gameService.dispose();
        }
      });
    }

    testWidgets('a flapping connection does not queue a SnackBar per tap (clearSnackBars)', (tester) async {
      try {
        await pumpHostParlour(tester);
        failWith(unavailable());

        await tapVisible(tester, find.byKey(const ValueKey('rounds_3')));
        await tester.pump(const Duration(milliseconds: 300));
        await tapVisible(tester, find.byKey(const ValueKey('rounds_4')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SnackBar), findsOneWidget);

        // A SnackBar lasts 4 s, plus its two 0.25 s animations. Had the second been queued
        // behind the first it would be on screen until about 9.5 s; it REPLACED the first, so
        // both are gone by 7.6 s. One-second pumps, because each animation needs its own frame.
        for (var i = 0; i < 7; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('a failure that arrives after the screen is gone is swallowed quietly', (tester) async {
      try {
        await pumpHostParlour(tester);
        final gate = Completer<void>();
        functions.overrideCallable('updateLobbySettings', (_) async {
          await gate.future;
          throw unavailable();
        });

        await tapVisible(tester, find.byKey(const ValueKey('rounds_3')));
        await tester.pump();
        // The host leaves (or the game starts) while the write is still in flight.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        gate.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'ScaffoldMessenger.of(context) on a disposed screen throws unless _applySetting checks mounted');
      } finally {
        gameService.dispose();
      }
    });
  });

  group('lobbyCallableErrorMessage for settings (Issue 186 / AI9)', () {
    String settings(String code) => lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: code, message: 'raw'),
          action: LobbyAction.settings,
        );

    test('the connection and sign-in sentences are shared with create and join', () {
      const connection = 'Could not reach the parlour. Check your connection and try again.';
      // `unknown` is what a dropped connection reaches Dart as on iOS (Wave AH / AH1).
      for (final code in ['unavailable', 'deadline-exceeded', 'unknown']) {
        expect(settings(code), connection, reason: code);
      }
      expect(settings('unauthenticated'), 'Could not sign in. Check your connection and try again.');
    });

    test('invalid-argument and permission-denied have their own sentences', () {
      expect(settings('invalid-argument'), "That house rule can't be set for this table.");
      expect(settings('permission-denied'), 'Only the host can change the house rules.');
    });

    test('anything else, and a non-Firebase error, is the generic sentence', () {
      for (final code in ['internal', 'not-found', 'resource-exhausted', 'failed-precondition']) {
        expect(settings(code), 'Something went wrong. Try again.', reason: code);
      }
      expect(lobbyCallableErrorMessage(StateError('x'), action: LobbyAction.settings), 'Something went wrong. Try again.');
    });

    test('create and join are unchanged: their invalid-argument sentences, and permission-denied stays generic', () {
      FirebaseFunctionsException e(String code) => FirebaseFunctionsException(code: code, message: 'raw');
      expect(lobbyCallableErrorMessage(e('invalid-argument'), action: LobbyAction.create), 'Enter your name to open a room.');
      expect(lobbyCallableErrorMessage(e('invalid-argument'), action: LobbyAction.join),
          'Enter your name and a four-letter room code.');
      expect(lobbyCallableErrorMessage(e('permission-denied'), action: LobbyAction.create), 'Something went wrong. Try again.');
      expect(lobbyCallableErrorMessage(e('permission-denied'), action: LobbyAction.join), 'Something went wrong. Try again.');
    });
  });
}
