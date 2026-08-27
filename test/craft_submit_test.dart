import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    gameService = GameService(db: mockDb, functions: fakeFns);
  });

  tearDown(() {
    gameService.dispose();
  });

  GameState makeTruthState() {
    final card = CardModel(
      targetPlayerId: 'p_host',
      promptText: 'A deep dark secret',
    );
    return GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.truth,
      totalPlayers: 2,
      isTimerDisabled: true,
      cards: [card],
      currentCardAssignments: {'p_host': 'p_host'},
      resolutionOrder: ['p_host'],
    );
  }

  PlayerState makeHost() => PlayerState(
        id: 'p_host',
        name: 'Alice',
        isHost: true,
      );

  group('Issue 131 (P10): Return Key Submits & Pinned Button Tests', () {
    testWidgets('Entering text and sending TextInputAction.done submits the answer once', (WidgetTester tester) async {
      final state = makeTruthState();
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      int submitCalls = 0;
      fakeFns.overrideCallable('submitAnswer', (params) async {
        submitCalls++;
        return {'success': true};
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      // Dismiss dealt overlay if present
      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      expect(fieldFinder, findsOneWidget);

      await tester.enterText(fieldFinder, 'My truthful answer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(submitCalls, equals(1), reason: 'TextInputAction.done must trigger submitAnswer once');
    });

    testWidgets('101-character text via done key triggers length guard and shows snackbar without submission', (WidgetTester tester) async {
      final state = makeTruthState();
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      int submitCalls = 0;
      fakeFns.overrideCallable('submitAnswer', (params) async {
        submitCalls++;
        return {'success': true};
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      // 101 characters
      const overlengthText = 'aaaaaaaaaabbbbbbbbbbccccccccccddddddddddeeeeeeeeeeffffffffffgggggggggghhhhhhhhhhiiiiiiiiiijjjjjjjjjjk';
      expect(overlengthText.length, 101);

      await tester.enterText(fieldFinder, overlengthText);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(submitCalls, equals(0), reason: 'Overlength answer must not be submitted to server');
      expect(find.textContaining('Trim it to 100 or fewer'), findsOneWidget);
    });

    testWidgets('Rapid successive done actions are guarded against re-entrancy (submitted once)', (WidgetTester tester) async {
      final state = makeTruthState();
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      int submitCalls = 0;
      fakeFns.overrideCallable('submitAnswer', (params) async {
        submitCalls++;
        await Future.delayed(const Duration(milliseconds: 200));
        return {'success': true};
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      await tester.enterText(fieldFinder, 'Valid answer');

      // Send done twice in rapid succession
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(submitCalls, equals(1), reason: 'Re-entrant submissions must be ignored while in-flight');
    });

    testWidgets('Pinned SUBMIT DOSSIER button stays within visible bounds above simulated keyboard (viewInsets.bottom = 300)', (WidgetTester tester) async {
      final state = makeTruthState();
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      final submitBtnFinder = find.widgetWithText(PrimaryButton, 'SUBMIT DOSSIER');
      expect(submitBtnFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(submitBtnFinder);
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Visible height available above keyboard is 640 - 300 = 340
      final buttonBottomY = position.dy + size.height;
      expect(buttonBottomY, lessThanOrEqualTo(340.0),
          reason: 'Submit button must be fully rendered in visible area above the 300pt keyboard inset');
      expect(position.dy, greaterThanOrEqualTo(0.0));
    });

    testWidgets('Tapping SUBMIT DOSSIER button directly still submits correctly', (WidgetTester tester) async {
      final state = makeTruthState();
      final me = makeHost();
      gameService.debugSetState(state, [me], me.id);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      int submitCalls = 0;
      fakeFns.overrideCallable('submitAnswer', (params) async {
        submitCalls++;
        return {'success': true};
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase2CraftScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      if (find.text('DISMISS').evaluate().isNotEmpty) {
        await tester.tap(find.text('DISMISS'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(milliseconds: 50));
      }

      final fieldFinder = find.byKey(const ValueKey('answer_field'));
      await tester.enterText(fieldFinder, 'Direct button tap answer');

      final submitBtn = find.widgetWithText(PrimaryButton, 'SUBMIT DOSSIER');
      await tester.tap(submitBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(submitCalls, equals(1));
    });
  });
}
