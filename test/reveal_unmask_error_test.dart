import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 185 / AI11: the reveal screen's accusation SnackBar is chosen from the error's CODE and
/// `details.reason`, never from its message text.
///
/// `submitUnmaskGuess` throws `failed-precondition` for six different reasons. The screen used
/// `e.toString().contains('already submitted') || e.toString().contains('failed-precondition')`,
/// so a tap that landed as the countdown expired was told "That guess is already locked in."
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reveal: a failed accusation is reported from its code and reason (Issue 185 / AI11)', () {
    late FakeFirestore db;
    late FakeFirebaseFunctions functions;
    late GameService gameService;

    final alice = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final bob = PlayerState(id: 'p2', name: 'Bob');
    final charlie = PlayerState(id: 'p3', name: 'Charlie');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = FakeFirestore();
      functions = FakeFirebaseFunctions(db);
      gameService = GameService(db: db, functions: functions);
    });

    /// The reveal's unmask panel, as Bob, who voted Charlie's forgery. Charlie is the one
    /// candidate to accuse (not Bob himself, not Alice whose card it is).
    Future<void> pumpUnmaskPanel(WidgetTester tester) async {
      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'What is Alice secret truth?',
        truthAnswer: 'Alice Real Truth',
        sabotageAnswers: {'p3': 'Charlie Forgery Answer'},
        votes: {'p2': 'p3'},
      );
      gameService.debugSetState(
        GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1'],
          unmaskDeadline: DateTime.now().millisecondsSinceEpoch + 120000,
        ),
        [alice, bob, charlie],
        'p2',
      );
      // Tall enough that the accusation buttons need no scrolling: the layout is not what is
      // under test, and the Ahem test font is wider than the shipped ones.
      tester.view.physicalSize = const Size(375, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(value: gameService, child: const GaslightApp()),
      );
      for (var i = 0; i < 40 && find.text('REVENGE UNMASKING!').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('REVENGE UNMASKING!'), findsOneWidget, reason: 'the panel must be on screen');
      expect(find.text('CHARLIE'), findsOneWidget);
    }

    /// What the SnackBar on screen says.
    String snackBarText(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join(' | ');

    /// Throw [error] from the callable, tap the accusation, and leave exactly one SnackBar up.
    Future<void> accuseAndFailWith(WidgetTester tester, Object error) async {
      functions.overrideCallable('submitUnmaskGuess', (_) async => throw error);
      await pumpUnmaskPanel(tester);
      // Known-empty start (lesson 2.47): nothing is on screen before the action.
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('CHARLIE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(functions.callableInvocations['submitUnmaskGuess'], 1, reason: 'the tap must have submitted');
      expect(find.byType(SnackBar), findsOneWidget, reason: 'exactly one SnackBar');
      expect(tester.takeException(), isNull);
    }

    testWidgets('failed-precondition + deadline_passed: "The guessing window has closed."', (tester) async {
      try {
        await accuseAndFailWith(
          tester,
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Unmask guess deadline has passed or is inactive.',
            details: {'reason': 'deadline_passed'},
          ),
        );
        expect(snackBarText(tester), 'The guessing window has closed.');
        expect(find.textContaining('Unmask guess deadline'), findsNothing, reason: 'the raw message never reaches the screen');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('failed-precondition + already_submitted: "That guess is already locked in."', (tester) async {
      try {
        await accuseAndFailWith(
          tester,
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'Player has already submitted an unmask guess.',
            details: {'reason': 'already_submitted'},
          ),
        );
        expect(snackBarText(tester), 'That guess is already locked in.');
        expect(find.textContaining('already submitted'), findsNothing, reason: 'the raw message never reaches the screen');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('failed-precondition without a reason: the generic sentence, not "locked in"', (tester) async {
      try {
        // Another of the six failed-precondition reasons, or an old server: no details.
        await accuseAndFailWith(
          tester,
          FirebaseFunctionsException(code: 'failed-precondition', message: 'Player did not cast a vote for this card.'),
        );
        expect(snackBarText(tester), 'Something went wrong. Try again.');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('a plain Exception: the generic sentence', (tester) async {
      try {
        await accuseAndFailWith(tester, Exception('x'));
        expect(snackBarText(tester), 'Something went wrong. Try again.');
        expect(find.textContaining('Exception'), findsNothing);
      } finally {
        gameService.dispose();
      }
    });
  });
}
