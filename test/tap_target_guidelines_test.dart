import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 187 / AI8: controls need a >= 44 x 44 pt hit box and an accessible name.
///
/// Measured on the SE: the host's remove-player badge was 22 x 22, the stacked-deck
/// jump dots 13 x 19, PREV / NEXT 71 x 30; and there was no `Semantics` anywhere in
/// `lib/`, so the kick badge, the share button, the six avatar tokens and the deck dots
/// had no name for VoiceOver. These are Flutter's own mechanical guidelines, run on the
/// two screens that carry the five controls, plus an exact check of each control's
/// semantics: its label, that it is a button, and that it carries a TAP ACTION (a node
/// with no tap action is skipped by both guidelines and cannot be activated by a screen
/// reader, so a label alone would pass them while the control stayed unusable).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tap targets and accessible names (Issue 187 / AI8)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final host = PlayerState(id: 'p_host', name: 'Alice', isHost: true, joinedAt: 100, lobbyReady: false);
    final guest1 = PlayerState(id: 'p_g1', name: 'Bob', isHost: false, joinedAt: 200, lobbyReady: true);
    final guest2 = PlayerState(id: 'p_g2', name: 'Charlie', isHost: false, joinedAt: 300, lobbyReady: false);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    /// The real app at 375 x 667, routed to whichever screen [state] belongs to.
    Future<void> pumpApp(
      WidgetTester tester, {
      GameState? state,
      List<PlayerState> players = const [],
      String localPlayerId = '',
    }) async {
      if (state != null) gameService.debugSetState(state, players, localPlayerId);
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(value: gameService, child: const GaslightApp()),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    /// Both guidelines SKIP a node that is scrolled out of view (`isHidden`) and one that
    /// touches the edge of a scrollable or of the screen ("it might be partially scrolled
    /// off-screen"), so a guideline run proves nothing about such a control. Fail loudly
    /// instead of passing vacuously. [clearOfEdges] is false only for the vote screen's
    /// deck row, which is flush with its scroll view's left, right and bottom edges by
    /// design: the guidelines can never see PREV / NEXT / the dots there, so their sizes
    /// are asserted directly instead (see 'hit boxes' below).
    void expectMeasurable(WidgetTester tester, Finder control, String name, {bool clearOfEdges = true}) {
      expect(control, findsOneWidget, reason: '$name must be on the screen under test');
      expect(tester.getSemantics(control).getSemanticsData().flagsCollection.isHidden, isFalse,
          reason: '$name is scrolled out of view, so the guidelines would skip it');
      if (!clearOfEdges) return;
      final rect = tester.getRect(control);
      final edges = <String, Rect>{
        'the screen': Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio),
        for (final scrollable in find.ancestor(of: control, matching: find.byType(Scrollable)).evaluate())
          'a scrollable': tester.getRect(find.byWidget(scrollable.widget)),
      };
      for (final edge in edges.entries) {
        final clear = rect.left - edge.value.left > 0.5 &&
            edge.value.right - rect.right > 0.5 &&
            rect.top - edge.value.top > 0.5 &&
            edge.value.bottom - rect.bottom > 0.5;
        expect(clear, isTrue,
            reason: '$name ($rect) touches the edge of ${edge.key} (${edge.value}), so the guidelines would skip it');
      }
    }

    void expectAtLeast44(WidgetTester tester, Finder control, String name) {
      final size = tester.getSize(control);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$name is ${size.width} pt wide');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$name is ${size.height} pt tall');
    }

    /// The share button, found by its envelope icon, NOT by its label: the label is what
    /// the labeled guideline has to catch, so the precondition must not depend on it.
    Finder shareButton() => find.ancestor(
          of: find.byWidgetPredicate((w) => w is ThematicIcon && w.type == ThematicIconType.envelope),
          matching: find.byType(InkWell),
        );

    // (a) the host's parlour with 3 players: two kick badges, the share button.
    Future<void> pumpHostParlour(WidgetTester tester) async {
      await pumpApp(
        tester,
        state: GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.lobby,
          currentRound: 1,
          totalRounds: 3,
          totalPlayers: 3,
          sabotageAnswersCount: 1,
          forgeriesPerCard: 1,
        ),
        players: [host, guest1, guest2],
        localPlayerId: 'p_host',
      );
      expectMeasurable(tester, find.byKey(const ValueKey('kick_p_g1')), 'the kick badge for Bob');
      expectMeasurable(tester, find.byKey(const ValueKey('kick_p_g2')), 'the kick badge for Charlie');
      expectMeasurable(tester, shareButton(), 'the share button');
    }

    // (b) the vote screen, voter view, THREE options. The deck's PREV / NEXT / dots sit
    // below the fold at 375 x 667 until the page is scrolled to them, which is exactly
    // what a voter does, so scroll them in before measuring.
    Future<void> pumpVoteScreen(WidgetTester tester) async {
      await pumpApp(
        tester,
        state: GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.vote,
          totalPlayers: 3,
          currentReaderId: 'p_host',
          isTimerDisabled: true,
          cards: [
            CardModel(
              promptText: 'What is Alice secret truth?',
              targetPlayerId: 'p_host',
              truthAnswer: 'Alice Real Truth',
              sabotageAnswers: {'p_g1': 'Bob Own Forgery Answer', 'p_g2': 'Charlie Forgery Answer'},
              options: [
                CardAnswerOption(id: 'opt1', text: 'Charlie Forgery Answer'),
                CardAnswerOption(id: 'opt2', text: 'Bob Own Forgery Answer'),
                CardAnswerOption(id: 'opt3', text: 'THE SOUL IS SILENT'),
              ],
            ),
          ],
        ),
        players: [host, guest1, guest2],
        localPlayerId: 'p_g1',
      );
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('stacked_deck_next_button'))), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 300));
      expectMeasurable(tester, find.byKey(const Key('stacked_deck_prev_button')), 'PREV', clearOfEdges: false);
      expectMeasurable(tester, find.byKey(const Key('stacked_deck_next_button')), 'NEXT', clearOfEdges: false);
      for (var i = 0; i < 3; i++) {
        expectMeasurable(tester, find.byKey(Key('stacked_deck_dot_$i')), 'jump dot $i', clearOfEdges: false);
      }
    }

    for (final screen in const ['host parlour', 'vote screen']) {
      testWidgets('$screen meets iOSTapTargetGuideline (44 x 44 pt)', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          screen == 'host parlour' ? await pumpHostParlour(tester) : await pumpVoteScreen(tester);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        } finally {
          handle.dispose();
          gameService.dispose();
        }
      });

      testWidgets('$screen meets labeledTapTargetGuideline (every tappable has a name)', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          screen == 'host parlour' ? await pumpHostParlour(tester) : await pumpVoteScreen(tester);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        } finally {
          handle.dispose();
          gameService.dispose();
        }
      });
    }

    /// A button with exactly this name, a tap action unless [tappable] is false, and
    /// (when given) this selected / enabled state.
    Matcher button(String label, {bool? selected, bool tappable = true, bool? enabled}) => isSemantics(
          label: label,
          isButton: true,
          hasTapAction: tappable,
          hasSelectedState: selected != null,
          isSelected: selected ?? false,
          hasEnabledState: enabled == null ? null : true,
          isEnabled: enabled,
        );

    testWidgets('semantics: the parlour\'s kick badges and share button are named buttons with a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpHostParlour(tester);

        expect(tester.getSemantics(find.byKey(const ValueKey('kick_p_g1'))), button('Remove Bob'));
        expect(tester.getSemantics(find.byKey(const ValueKey('kick_p_g2'))), button('Remove Charlie'));
        expect(find.byKey(const ValueKey('kick_p_host')), findsNothing, reason: 'the host has no kick badge');

        expect(tester.getSemantics(find.bySemanticsLabel('Share room code')), button('Share room code'));

        // The guidelines also flagged the deck card's 12-pt PEEK INSIDE link (triage rule):
        // it keeps its visible name, read once, on a node that now has a tap action.
        expect(find.bySemanticsLabel('PEEK INSIDE'), findsOneWidget);
        expect(tester.getSemantics(find.bySemanticsLabel('PEEK INSIDE')), button('PEEK INSIDE'));
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('hit boxes: the parlour\'s kick badges, share button and PEEK INSIDE link are at least 44 x 44 pt', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpHostParlour(tester);
        expect(tester.getSize(find.byKey(const ValueKey('kick_p_g1'))), const Size(44, 44));
        expect(tester.getSize(find.byKey(const ValueKey('kick_p_g2'))), const Size(44, 44));
        expectAtLeast44(tester, shareButton(), 'the share button');
        final peek = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('peek_inside_'),
        );
        expect(peek, findsOneWidget, reason: 'only the centred deck card offers PEEK INSIDE');
        expectAtLeast44(tester, peek, 'PEEK INSIDE');
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('hit boxes: PREV, NEXT and the three jump dots on the vote screen are at least 44 x 44 pt', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        // Asserted directly because the guidelines cannot see this row (see expectMeasurable).
        await pumpVoteScreen(tester);
        expectAtLeast44(tester, find.byKey(const Key('stacked_deck_prev_button')), 'PREV');
        expectAtLeast44(tester, find.byKey(const Key('stacked_deck_next_button')), 'NEXT');
        for (var i = 0; i < 3; i++) {
          expect(tester.getSize(find.byKey(Key('stacked_deck_dot_$i'))), const Size(44, 44), reason: 'jump dot $i');
        }
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('kick: the badge\'s outer corner and the avatar\'s centre-right both open the remove dialog', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpHostParlour(tester);

        // The 44-pt hit box is the avatar's top-right 44 x 44 (Flutter does not hit-test
        // outside a parent's bounds, so a box hung off the avatar's corner would lose its
        // outer part). Measure from the box, so the points track the layout.
        final box = tester.getRect(find.byKey(const ValueKey('kick_p_g1')));
        expect(box.size, const Size(44, 44));
        final points = {
          'outer corner of the badge': Offset(box.right - 2, box.top + 2),
          'centre-right of the avatar': Offset(box.right - 8, box.top + 28),
        };
        for (final entry in points.entries) {
          await tester.tapAt(entry.value);
          await tester.pumpAndSettle();
          expect(find.text('Remove player?'), findsOneWidget, reason: 'a tap on the ${entry.key} must open the dialog');
          await tester.tap(find.byKey(const ValueKey('confirm_dialog_cancel')));
          await tester.pumpAndSettle();
          expect(find.text('Remove player?'), findsNothing);
        }
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('semantics: the entry screen\'s six avatar tokens are named, the chosen one is selected', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpApp(tester); // no game state: the entry screen

        expect(tester.getSemantics(find.bySemanticsLabel('Token 1 of 6')), button('Token 1 of 6', selected: true));
        for (var i = 2; i <= 6; i++) {
          expect(tester.getSemantics(find.bySemanticsLabel('Token $i of 6')), button('Token $i of 6', selected: false));
        }
        for (var i = 1; i <= 6; i++) {
          expectAtLeast44(tester, find.bySemanticsLabel('Token $i of 6'), 'token $i');
        }
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('semantics: PREV, NEXT and the three jump dots are named buttons with a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await pumpVoteScreen(tester);

        // On the first option PREV has nowhere to go: named, announced as disabled, no tap.
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_prev_button'))),
            button('Previous option', tappable: false, enabled: false));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_next_button'))), button('Next option', enabled: true));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_dot_0'))), button('Show option 1 of 3', selected: true));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_dot_1'))), button('Show option 2 of 3', selected: false));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_dot_2'))), button('Show option 3 of 3', selected: false));

        // Step to the last option: PREV is now live, NEXT has nowhere to go.
        await tester.tap(find.byKey(const Key('stacked_deck_dot_2')));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_prev_button'))), button('Previous option', enabled: true));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_next_button'))),
            button('Next option', tappable: false, enabled: false));
        expect(tester.getSemantics(find.byKey(const Key('stacked_deck_dot_2'))), button('Show option 3 of 3', selected: true));
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });

    testWidgets('many options: the dot slots shrink instead of overflowing, PREV / NEXT stay 44 pt tall', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        // 9 options (a 10-player table) on the narrowest supported screen. The recorded,
        // bounded deviation: dot slots are 44 pt wide only while they fit.
        gameService.debugSetState(
          GameState(
            roomCode: 'TEST',
            currentPhase: GamePhase.vote,
            totalPlayers: 3,
            currentReaderId: 'p_host',
            isTimerDisabled: true,
            cards: [
              CardModel(
                promptText: 'What is Alice secret truth?',
                targetPlayerId: 'p_host',
                truthAnswer: 'Alice Real Truth',
                sabotageAnswers: {'p_g1': 'Bob Own Forgery Answer'},
                options: [for (var i = 0; i < 9; i++) CardAnswerOption(id: 'opt$i', text: 'Answer number $i')],
              ),
            ],
          ),
          [host, guest1, guest2],
          'p_g1',
        );
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(value: gameService, child: const GaslightApp()),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await Scrollable.ensureVisible(tester.element(find.byKey(const Key('stacked_deck_next_button'))), alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'nine dots must not overflow the row');
        for (var i = 0; i < 9; i++) {
          final slot = tester.getSize(find.byKey(Key('stacked_deck_dot_$i')));
          expect(slot.height, 44, reason: 'dot $i keeps its 44-pt height');
          expect(slot.width, lessThan(44), reason: 'dot $i has shrunk below 44 pt wide: nine do not fit');
          expect(slot.width, greaterThan(0));
        }
        expect(tester.getSize(find.byKey(const Key('stacked_deck_prev_button'))).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(find.byKey(const Key('stacked_deck_next_button'))).height, greaterThanOrEqualTo(44));
      } finally {
        handle.dispose();
        gameService.dispose();
      }
    });
  });
}
