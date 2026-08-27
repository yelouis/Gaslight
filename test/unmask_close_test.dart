import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:clock/clock.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wave Q: Issue 133 / Q1 - Phase4RevealScreen unmask close client trigger (W1-W7)', () {
    late FakeFirestore mockDb;
    late FakeFirebaseFunctions mockFunctions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      mockFunctions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: mockFunctions);
    });

    Future<void> pumpRevealScreen({
      required WidgetTester tester,
      required bool isHost,
      required int unmaskDeadline,
      String localPlayerId = 'p_guest',
      String currentReaderId = 'p_reader',
      CardModel? initialCard,
    }) async {
      final hostPlayer = PlayerState(
        id: 'p_host',
        name: 'AliceHost',
        isHost: true,
        joinedAt: 100,
      );
      final guestPlayer = PlayerState(
        id: 'p_guest',
        name: 'BobGuest',
        isHost: false,
        joinedAt: 200,
      );
      final readerPlayer = PlayerState(
        id: 'p_reader',
        name: 'CharlieReader',
        isHost: false,
        joinedAt: 300,
      );

      final card = initialCard ?? CardModel(
        targetPlayerId: currentReaderId,
        promptText: 'A deep mystery',
        truthAnswer: 'The truth',
        sabotageAnswers: {'p_guest': 'A clever lie'},
        votes: {'p_host': 'p_guest', 'p_guest': currentReaderId},
        scoreDeltas: const {},
      );

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 3,
        currentReaderId: currentReaderId,
        cards: [card],
        readyPlayers: {'p_host': true, 'p_guest': true, 'p_reader': true},
        resolutionOrder: [currentReaderId],
        unmaskDeadline: unmaskDeadline,
      );

      await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p_host').set(
        hostPlayer.toMap()..['authUid'] = 'host_auth_uid',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').set(
        guestPlayer.toMap()..['authUid'] = 'guest_auth_uid',
      );
      await mockDb.collection('rooms').doc('TEST').collection('players').doc('p_reader').set(
        readerPlayer.toMap()..['authUid'] = 'reader_auth_uid',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', isHost ? 'p_host' : localPlayerId);

      gameService.listenToRoom('TEST');
      await gameService.tryRejoinSession();

      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase4RevealScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('W1 — non-host player triggers closeUnmaskWindow past unmaskDeadline + 1500', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false, // Non-host!
            unmaskDeadline: deadline,
          );

          await tester.pump(const Duration(milliseconds: 200));

          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(1));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W2 — host still triggers closeUnmaskWindow past deadline + 1500', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: true, // Host
            unmaskDeadline: deadline,
          );

          await tester.pump(const Duration(milliseconds: 200));
          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(1));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W3 — no storm: pumping 20 ticks (4 seconds) produces exactly 1 call when success', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false,
            unmaskDeadline: deadline,
          );

          for (int i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }

          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(1));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W4 — bounded retry: pumping 60 ticks with failed-precondition produces exactly 6 calls', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      mockFunctions.overrideCallable('closeUnmaskWindow', (params) async {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'The unmask window has not expired yet.',
        );
      });

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false,
            unmaskDeadline: deadline,
          );

          for (int i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }

          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(6));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W5 — safety margin: 0 calls at deadline + 500ms, 1 call at +1500ms', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;
      DateTime currentTime = baseTime.add(const Duration(milliseconds: 500));

      try {
        await withClock(Clock(() => currentTime), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false,
            unmaskDeadline: deadline,
          );

          await tester.pump(const Duration(milliseconds: 200));
          expect(mockFunctions.callableInvocations['closeUnmaskWindow'] ?? 0, equals(0));

          // Advance time to +1500ms (safety margin boundary)
          currentTime = baseTime.add(const Duration(milliseconds: 1500));
          await tester.pump(const Duration(milliseconds: 200));
          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(1));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W6 — per-card reset: latch and attempt counter reset when target card changes', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false,
            unmaskDeadline: deadline,
            currentReaderId: 'p_reader1',
          );

          await tester.pump(const Duration(milliseconds: 200));
          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(1));

          // Advance to card 2
          final card2 = CardModel(
            targetPlayerId: 'p_reader2',
            promptText: 'Another mystery',
            truthAnswer: 'Truth 2',
            sabotageAnswers: {'p_guest': 'Lie 2'},
            votes: {'p_host': 'p_guest'},
            scoreDeltas: const {},
          );

          final updatedState = gameService.gameState!.copyWith(
            currentReaderId: 'p_reader2',
            cards: [...gameService.gameState!.cards, card2],
            unmaskDeadline: deadline,
          );

          await mockDb.collection('rooms').doc('TEST').set(updatedState.toMap());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));

          expect(mockFunctions.callableInvocations['closeUnmaskWindow'], equals(2));
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });

    testWidgets('W7 — silence: failed-precondition rejection produces no SnackBar in tree', (tester) async {
      final baseTime = DateTime(2026, 8, 27, 12, 0, 0);
      final deadline = baseTime.millisecondsSinceEpoch;

      mockFunctions.overrideCallable('closeUnmaskWindow', (params) async {
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'The unmask window has not expired yet.',
        );
      });

      try {
        await withClock(Clock.fixed(baseTime.add(const Duration(milliseconds: 1500))), () async {
          await pumpRevealScreen(
            tester: tester,
            isHost: false,
            unmaskDeadline: deadline,
          );

          await tester.pump(const Duration(milliseconds: 200));

          expect(find.byType(SnackBar), findsNothing);
        });
      } finally {
        await tester.pumpWidget(const SizedBox());
        gameService.dispose();
      }
    });
  });
}
