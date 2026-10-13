import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 185 / AI11: the craft screen's SnackBar for a failed submit is chosen from the error's
/// CODE and `details.reason`, never from its message text.
///
/// The screen matched `errStr.contains('similar')`. The server's similarity rejection is
/// `invalid-argument`, the same code as its length and type rejections, so the code alone cannot
/// tell them apart -- the server now says `details.reason == 'too_similar'`, and the client reads
/// that. The local pre-check (answers the SERVER would also reject) is unchanged and is covered
/// by test/phase2_craft_test.dart.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('craft: a failed submit is reported from its code and reason (Issue 185 / AI11)', () {
    const tooSimilar = 'Too similar to an existing answer! Be more creative.';
    const generic = 'Something went wrong. Try again.';

    late FakeFirestore db;
    late FakeFirebaseFunctions functions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = FakeFirestore();
      functions = FakeFirebaseFunctions(db);
      gameService = GameService(db: db, functions: functions);
    });

    /// The forgery screen, as 'local_player_id', writing a forgery for 'guest_id''s card. The
    /// typed text passes the local similarity pre-check, so any SnackBar comes from the server.
    Future<void> pumpCraftScreen(WidgetTester tester) async {
      final card = CardModel(
        targetPlayerId: 'guest_id',
        promptText: 'Is this real life?',
        truthAnswer: 'sleeping in my bed all day',
        sabotageAnswers: {'guest_id': 'playing video games'},
      );
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.forgery,
        totalPlayers: 2,
        cards: [card],
        currentCardAssignments: {'local_player_id': 'guest_id', 'guest_id': 'local_player_id'},
        readyPlayers: {},
      );
      await db.collection('rooms').doc('TEST').set(state.toMap());
      await db.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
            PlayerState(id: 'local_player_id', name: 'LocalPlayer', joinedAt: 100).toMap()..['authUid'] = 'local_auth_uid',
          );
      await db.collection('rooms').doc('TEST').collection('players').doc('guest_id').set(
            PlayerState(id: 'guest_id', name: 'GuestPlayer', joinedAt: 200).toMap()..['authUid'] = 'guest_auth_uid',
          );
      gameService.listenToRoom('TEST');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('room_code', 'TEST');
      await prefs.setString('player_id', 'local_player_id');
      await gameService.tryRejoinSession();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true),
              child: Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1000));
    }

    /// What the SnackBar on screen says.
    String snackBarText(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join(' | ');

    /// Throw [error] from the callable, submit a forgery, and leave exactly one SnackBar up.
    Future<void> submitAndFailWith(WidgetTester tester, Object error) async {
      functions.overrideCallable('submitAnswer', (_) async => throw error);
      await pumpCraftScreen(tester);
      // Known-empty start (lesson 2.47): the rejoin SnackBar is not on this screen, but assert it.
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(SnackBar), findsNothing);

      await tester.enterText(find.byType(TextField), 'cooking delicious pasta');
      await tester.pump();
      await tester.tap(find.text('SUBMIT DOSSIER'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(functions.callableInvocations['submitAnswer'], 1, reason: 'the local pre-check must have let it through');
      expect(find.byType(SnackBar), findsOneWidget, reason: 'exactly one SnackBar');
      expect(tester.takeException(), isNull);
    }

    testWidgets('invalid-argument + too_similar: the similarity sentence, whatever the message says', (tester) async {
      try {
        await submitAndFailWith(
          tester,
          // A message WITHOUT the word "similar": only the reason can produce the sentence.
          FirebaseFunctionsException(code: 'invalid-argument', message: 'Answer rejected.', details: {'reason': 'too_similar'}),
        );
        expect(snackBarText(tester), tooSimilar);
        expect(find.textContaining('Answer rejected'), findsNothing, reason: 'the raw message never reaches the screen');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('invalid-argument whose message says "similar" but has no reason: the generic sentence', (tester) async {
      try {
        // Matching the message is exactly what is no longer done.
        await submitAndFailWith(
          tester,
          FirebaseFunctionsException(code: 'invalid-argument', message: "Answer is too similar to another player's answer!"),
        );
        expect(snackBarText(tester), generic);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('another invalid-argument (e.g. length): the generic sentence', (tester) async {
      try {
        await submitAndFailWith(
          tester,
          FirebaseFunctionsException(code: 'invalid-argument', message: 'Answer is too long.', details: {'reason': 'too_long'}),
        );
        expect(snackBarText(tester), generic);
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('a plain Exception: the generic sentence', (tester) async {
      try {
        await submitAndFailWith(tester, Exception('x'));
        expect(snackBarText(tester), generic);
        expect(find.textContaining('Exception'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });
  });
}
