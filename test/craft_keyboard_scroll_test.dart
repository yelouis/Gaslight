import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/services/game_service.dart';
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

  group('AA3 (Issue 157): Scroll Focused Field Above Keyboard Tests', () {
    testWidgets(
      'at 375x667 with viewInsets.bottom = 300, focusing field scrolls answer_field bottom <= 667 - 300',
      (WidgetTester tester) async {
        final state = makeTruthState();
        final me = makeHost();
        gameService.debugSetState(state, [me], me.id);

        tester.view.physicalSize = const Size(375, 667);
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
        await tester.pump(const Duration(milliseconds: 500));

        final answerFieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(answerFieldFinder, findsOneWidget);

        // Focus the field
        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        editableText.focusNode.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        expect(editableText.focusNode.hasFocus, isTrue, reason: 'Field must have focus');

        final fieldRect = tester.getRect(answerFieldFinder);
        // Visible height above keyboard is 667 - 300 = 367
        expect(
          fieldRect.bottom,
          lessThanOrEqualTo(367.0),
          reason: 'Focused field bottom (${fieldRect.bottom}) must be <= 367.0 to sit above keyboard',
        );
      },
    );

    testWidgets(
      'at 375x667 with field focused, keyboard opening (viewInsets.bottom 0 -> 300) scrolls answer_field bottom <= 667 - 300',
      (WidgetTester tester) async {
        final state = makeTruthState();
        final me = makeHost();
        gameService.debugSetState(state, [me], me.id);

        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding.zero;
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
        await tester.pump(const Duration(milliseconds: 500));

        final answerFieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(answerFieldFinder, findsOneWidget);
        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        editableText.focusNode.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Now simulate keyboard opening
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));

        final fieldRect = tester.getRect(answerFieldFinder);
        expect(
          fieldRect.bottom,
          lessThanOrEqualTo(367.0),
          reason: 'Field bottom (${fieldRect.bottom}) must scroll above keyboard on metric change',
        );
      },
    );

    testWidgets(
      'over-reach guard: with viewInsets.bottom = 0, scroll offset is 0 and CASE DOSSIER prompt is visible',
      (WidgetTester tester) async {
        final state = makeTruthState();
        final me = makeHost();
        gameService.debugSetState(state, [me], me.id);

        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = FakeViewPadding.zero;
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
        await tester.pump(const Duration(milliseconds: 500));

        final answerFieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(answerFieldFinder, findsOneWidget);
        final editableText = tester.widget<EditableText>(find.byType(EditableText));
        editableText.focusNode.requestFocus();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
        expect(scrollable.position.pixels, equals(0.0), reason: 'Scroll offset must remain 0 when there is no keyboard');
        expect(find.text('CASE DOSSIER'), findsOneWidget);
        expect(tester.getTopLeft(find.text('CASE DOSSIER')).dy, greaterThan(0));
      },
    );
  });
}
