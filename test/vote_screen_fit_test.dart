import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 198 / AM3: the vote screen, not the deck widget, keeps the deck's navigation and the action
/// button on screen, and opens the deck on a card the voter can choose.
///
/// `test/vote_option_truncation_test.dart` (320 x 640) and `test/stacked_deck_navigation_test.dart`
/// (375 x 812) test `CardGrid` alone, and the design promise they back — six options fit in 320 x 640 with
/// no vertical scrolling — never held for the whole screen: its header, avatar, subtitles, prompt card and
/// discussion line take about 450 pt above the deck, so PREV, the dots and NEXT sat below the fold at
/// 375 x 667, and a voter's own sealed forgery was often the front card. This pumps the real `GaslightApp`
/// on the vote screen, as a voter and as the target, and measures the screen without scrolling it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      var any = false;
      for (final path in files) {
        final file = File(path);
        if (!file.existsSync()) continue;
        any = true;
        loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(Uint8List.fromList(b))));
      }
      if (any) await loader.load();
    }

    await load('Lora', [
      'assets/fonts/lora/Lora-Regular.ttf',
      'assets/fonts/lora/Lora-Bold.ttf',
      'assets/fonts/lora/Lora-Italic.ttf',
    ]);
    await load('CormorantGaramond', [
      'assets/fonts/cormorant_garamond/CormorantGaramond-Regular.ttf',
      'assets/fonts/cormorant_garamond/CormorantGaramond-Bold.ttf',
      'assets/fonts/cormorant_garamond/CormorantGaramond-Italic.ttf',
    ]);
    await load('PhosphorLight', [
      'assets/fonts/phosphor/Phosphor-Light.ttf',
    ]);
  });

  group('the vote screen keeps its deck navigation and action button on screen (Issue 198 / AM3)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie');

    // Card A is Alice's. Bob's own forgery comes FIRST, which is what the deck used to open on.
    final cardA = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      truthAnswer: 'Alice Real Truth',
      sabotageAnswers: {'p2': 'Bob Own Forgery A', 'p3': 'Charlie Forgery A'},
      options: [
        CardAnswerOption(id: 'a1', text: 'Bob Own Forgery A'),
        CardAnswerOption(id: 'a2', text: 'Charlie Forgery A'),
        CardAnswerOption(id: 'a3', text: 'Alice Real Truth'),
      ],
    );

    // Card B is Charlie's. Bob's own forgery is first here too, so the first option he can choose is II.
    final cardB = CardModel(
      promptText: 'What is Charlie secret truth?',
      targetPlayerId: 'p3',
      truthAnswer: 'Charlie Real Truth',
      sabotageAnswers: {'p1': 'Alice Forgery B', 'p2': 'Bob Own Forgery B'},
      options: [
        CardAnswerOption(id: 'b1', text: 'Bob Own Forgery B'),
        CardAnswerOption(id: 'b2', text: 'Alice Forgery B'),
        CardAnswerOption(id: 'b3', text: 'Charlie Real Truth'),
      ],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    GameState voteState(String readerId) => GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.vote,
          totalPlayers: 3,
          currentReaderId: readerId,
          isTimerDisabled: true,
          cards: [cardA, cardB],
        );

    /// The real app (production theme and routing) on the vote screen at [size] and [textScale], with
    /// reduced motion so nothing is mid-animation when it is measured. A voter has already written their
    /// forgery for each card, so the screen knows which option is theirs.
    Future<void> pumpVoteScreen(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required String localPlayerId,
      String readerId = 'p1',
    }) async {
      final state = voteState(readerId);
      await mockDb.collection('rooms').doc('TEST').set(state.toMap());
      gameService.debugSetState(state, [p1, p2, p3], localPlayerId);
      if (localPlayerId == 'p2') {
        await gameService.submitCardAnswer('p1', 'p2', 'Bob Own Forgery A', false);
        await gameService.submitCardAnswer('p3', 'p2', 'Bob Own Forgery B', false);
      }

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const GaslightApp(),
        ),
      );
      // The lobby routes itself to the vote screen on the first frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Phase3VoteScreen), findsOneWidget, reason: 'the app did not reach the vote screen');
    }

    /// A control is on screen when, with nothing scrolled, its whole rectangle is inside the window AND inside
    /// the viewport of every scroll view it sits in (a control below a scroll view's edge can still have
    /// coordinates inside the window, and is clipped), and a tap at its centre reaches it.
    void expectOnScreen(WidgetTester tester, Finder control, String what, Size size) {
      expect(control, findsOneWidget, reason: '$what is not on the vote screen at all');
      final rect = tester.getRect(control);
      bool within(Rect outer) =>
          rect.left >= outer.left && rect.top >= outer.top && rect.right <= outer.right && rect.bottom <= outer.bottom;
      expect(
        within(Offset.zero & size),
        isTrue,
        reason: '$what is at $rect, which is not inside the ${size.width.toInt()} x ${size.height.toInt()} screen',
      );
      for (final element in find.ancestor(of: control, matching: find.byType(Scrollable)).evaluate()) {
        final box = element.renderObject! as RenderBox;
        final viewport = box.localToGlobal(Offset.zero) & box.size;
        expect(within(viewport), isTrue, reason: '$what is at $rect, which a scroll view showing only $viewport clips');
      }
      expect(control.hitTestable(), findsOneWidget, reason: '$what is covered: a tap at its centre does not reach it');
    }

    for (final size in const [Size(320, 640), Size(375, 667), Size(375, 812), Size(1280, 800)]) {
      for (final textScale in const [1.0, 1.3]) {
        final where = '${size.width.toInt()} x ${size.height.toInt()} at text scale $textScale';

        testWidgets('voter at $where: PREV, NEXT, every dot and the action button are on screen, and the deck '
            'opens on a card they can choose', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await pumpVoteScreen(tester, size: size, textScale: textScale, localPlayerId: 'p2');

            expectOnScreen(tester, find.bySemanticsLabel('Previous option'), 'Previous option', size);
            expectOnScreen(tester, find.bySemanticsLabel('Next option'), 'Next option', size);
            for (var k = 1; k <= 3; k++) {
              expectOnScreen(tester, find.bySemanticsLabel('Show option $k of 3'), 'Show option $k of 3', size);
            }
            expectOnScreen(tester, find.widgetWithText(PrimaryButton, 'TAP A CARD TO CHOOSE'), 'TAP A CARD TO CHOOSE', size);

            // Bob's own forgery is option I. The deck opens on option II, which he can choose: it shows the cue.
            expect(find.text('CARD II OF III'), findsOneWidget, reason: 'the deck did not skip the voter\'s own forgery');
            expect(find.text('Tap to choose this one'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });

        testWidgets('target at $where: PREV, NEXT, every dot and the ready button are on screen, and the deck '
            'opens on card I', (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            await pumpVoteScreen(tester, size: size, textScale: textScale, localPlayerId: 'p1');

            expectOnScreen(tester, find.bySemanticsLabel('Previous option'), 'Previous option', size);
            expectOnScreen(tester, find.bySemanticsLabel('Next option'), 'Next option', size);
            for (var k = 1; k <= 3; k++) {
              expectOnScreen(tester, find.bySemanticsLabel('Show option $k of 3'), 'Show option $k of 3', size);
            }
            expectOnScreen(tester, find.widgetWithText(PrimaryButton, "I'M READY"), "I'M READY", size);

            expect(find.text('CARD I OF III'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        });
      }
    }

    testWidgets('a new card opens its own deck on its first votable option, not on the previous index', (tester) async {
      await pumpVoteScreen(tester, size: const Size(375, 667), textScale: 1.0, localPlayerId: 'p2');

      // Card A: the voter's own forgery is I, so the deck opens on II. Walk to III.
      expect(find.text('CARD II OF III'), findsOneWidget);
      await tester.tap(find.byKey(const Key('stacked_deck_next_button')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CARD III OF III'), findsOneWidget, reason: 'the walk to option III did not happen');

      // The reader changes to Charlie: card B's room state is pumped.
      gameService.debugSetState(voteState('p3'), [p1, p2, p3], 'p2');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('What is Charlie secret truth?'), findsOneWidget, reason: 'the screen did not move to card B');
      expect(find.text('CARD II OF III'), findsOneWidget,
          reason: "card B's deck must open on its first votable option (II), not on the last card's index (III) or on Bob's own forgery (I)");
      expect(find.text('Tap to choose this one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the front card is visible at first paint (Issue 199 / AN1)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice');
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie', isHost: true);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    void expectOnScreen(WidgetTester tester, Finder control, String what, Size size) {
      expect(control, findsOneWidget, reason: '$what is not on the vote screen at all');
      final rect = tester.getRect(control);
      bool within(Rect outer) =>
          rect.left >= outer.left && rect.top >= outer.top && rect.right <= outer.right && rect.bottom <= outer.bottom;
      expect(
        within(Offset.zero & size),
        isTrue,
        reason: '$what is at $rect, which is not inside the ${size.width.toInt()} x ${size.height.toInt()} screen',
      );
      for (final element in find.ancestor(of: control, matching: find.byType(Scrollable)).evaluate()) {
        final box = element.renderObject! as RenderBox;
        final viewport = box.localToGlobal(Offset.zero) & box.size;
        expect(within(viewport), isTrue, reason: '$what is at $rect, which a scroll view showing only $viewport clips');
      }
      expect(control.hitTestable(), findsOneWidget, reason: '$what is covered: a tap at its centre does not reach it');
    }

    Future<void> pumpVoteScreenForCard(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required String localPlayerId,
      required CardModel card,
    }) async {
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        isTimerDisabled: true,
        cards: [card],
      );
      await mockDb.collection('rooms').doc('TEST').set(state.toMap());
      gameService.debugSetState(state, [p1, p2, p3], localPlayerId);
      if (localPlayerId == 'p2') {
        await gameService.submitCardAnswer('p1', 'p2', 'Bob Own Forgery A', false);
      }

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const GaslightApp(),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Phase3VoteScreen), findsOneWidget, reason: 'the app did not reach the vote screen');
    }

    final prompts = <int, String>{
      29: 'What is Charlie secret truth?',
      65: 'The trick I use to avoid making small talk with people in public.',
      89: 'The first thing I would buy with lottery money that would make people question my sanity.',
    };

    final sizes = const [Size(320, 640), Size(375, 667), Size(375, 812), Size(1280, 800)];
    final textScales = const [1.0, 1.3];
    final roles = const [
      ('voter', 'p2', true, 'OPTION II', 'Charlie Forgery A'),
      ('target', 'p1', false, 'OPTION I', 'Bob Own Forgery A'),
    ];

    for (final size in sizes) {
      for (final textScale in textScales) {
        for (final roleInfo in roles) {
          final role = roleInfo.$1;
          final playerId = roleInfo.$2;
          final isVoter = roleInfo.$3;
          final frontOptionLabel = roleInfo.$4;
          final frontAnswerText = roleInfo.$5;

          for (final entry in prompts.entries) {
            final promptLength = entry.key;
            final promptText = entry.value;
            final where = '${size.width.toInt()} x ${size.height.toInt()} at text scale $textScale';

            testWidgets('$role at $where ($promptLength chars): card label and answer are visible', (tester) async {
              final card = CardModel(
                promptText: promptText,
                targetPlayerId: 'p1',
                truthAnswer: 'Alice Real Truth',
                sabotageAnswers: {'p2': 'Bob Own Forgery A', 'p3': 'Charlie Forgery A'},
                options: [
                  CardAnswerOption(id: 'a1', text: 'Bob Own Forgery A'),
                  CardAnswerOption(id: 'a2', text: 'Charlie Forgery A'),
                  CardAnswerOption(id: 'a3', text: 'Alice Real Truth'),
                ],
              );

              await pumpVoteScreenForCard(
                tester,
                size: size,
                textScale: textScale,
                localPlayerId: playerId,
                card: card,
              );

              // (a) the front card's OPTION <roman> label passes the file's existing "on screen" check:
              // inside the window, inside every enclosing scroll viewport, and reachable by a tap at its centre
              expectOnScreen(tester, find.text(frontOptionLabel), frontOptionLabel, size);

              // (b) the front card's answer Text has at least 20 px inside the scroll viewport, measured from its top edge
              final scrollBox = tester.renderObject(find.byType(Scrollable)) as RenderBox;
              final viewport = scrollBox.localToGlobal(Offset.zero) & scrollBox.size;
              final answerRect = tester.getRect(find.text(frontAnswerText));
              final visiblePx = viewport.bottom - answerRect.top;

              // The only exceptions to (b), listed by name in the test with a comment giving the measured value:
              // - 320x640 x 1.3: voter with the 89-character prompt (-10.5 px); target with 65 and 89 (-26.5, -58.5);
              // - 375x667 x 1.3: target with 89 (0.5);
              // - 375x812 x 1.0: the full header, unchanged, with 89 (voter 16.5, target -6.5).
              final isException =
                  (size == const Size(320, 640) && textScale == 1.3 && isVoter && promptLength == 89) || // -10.5 px
                  (size == const Size(320, 640) && textScale == 1.3 && !isVoter && promptLength == 65) || // -26.5 px
                  (size == const Size(320, 640) && textScale == 1.3 && !isVoter && promptLength == 89) || // -58.5 px
                  (size == const Size(375, 667) && textScale == 1.3 && !isVoter && promptLength == 89) || // 0.5 px
                  (size == const Size(375, 812) && textScale == 1.0 && isVoter && promptLength == 89) || // 16.5 px
                  (size == const Size(375, 812) && textScale == 1.0 && !isVoter && promptLength == 89); // -6.5 px

              if (!isException) {
                expect(
                  visiblePx,
                  greaterThanOrEqualTo(20.0),
                  reason: '$role at $where ($promptLength chars): answer top is at ${answerRect.top}, '
                      'viewport bottom is at ${viewport.bottom} ($visiblePx px visible, expected >= 20.0)',
                );
              }

              // Also assert the header mode from step 1
              final double effectiveHeight = size.height / textScale;
              final bool compactHeader = effectiveHeight < 740;

              if (compactHeader) {
                expect(find.text('Prompt:'), findsNothing);
                expect(
                  find.text('Find the real truth among the forgeries. Talk it out — discussion is part of the game.'),
                  findsNothing,
                );
                if (isVoter) {
                  expect(find.text('VOTING ON'), findsNothing);
                }
              } else {
                expect(find.text('Prompt:'), findsOneWidget);
                expect(
                  find.text('Find the real truth among the forgeries. Talk it out — discussion is part of the game.'),
                  findsOneWidget,
                );
                if (isVoter) {
                  expect(find.text('VOTING ON'), findsOneWidget);
                }
              }

              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}
