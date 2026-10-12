import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'helpers/rendered_contrast.dart';
import 'simulation_test.dart';

/// Issue 182 / AI5: the vote screen's text must clear 4.5 : 1 AS RENDERED.
///
/// Two subtitles were `colorScheme.onSurface` (ink, "text on parchment") drawn on
/// the dark ground (1.18 : 1 and 1.81 : 1), and on the parchment option card the
/// `OPTION I` label (1.77 : 1) and the "Tap to choose this one" cue (2.02 : 1) were
/// brass, which is an accent for the DARK ground. The voter subtitle is the line that
/// names whose card is being voted on. This pumps the real `GaslightApp` and measures
/// pixels with `measureRenderedContrast`; the widget-tree walk cannot see these.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vote screen text clears the contrast floor as rendered (Issue 182 / AI5)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final p2 = PlayerState(id: 'p2', name: 'Bob');
    final p3 = PlayerState(id: 'p3', name: 'Charlie');

    // Alice (p1) is the card's target; three options, none selected.
    final voteCard = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      truthAnswer: 'Alice Real Truth',
      sabotageAnswers: {
        'p2': 'Bob Own Forgery Answer',
        'p3': 'Charlie Forgery Answer',
      },
      options: [
        CardAnswerOption(id: 'opt1', text: 'Charlie Forgery Answer'),
        CardAnswerOption(id: 'opt2', text: 'Bob Own Forgery Answer'),
        CardAnswerOption(id: 'opt3', text: 'THE SOUL IS SILENT'),
      ],
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    /// The real app (production theme, background and routing) on the vote screen
    /// at 375 x 667, inside a root RepaintBoundary.
    Future<GlobalKey> pumpVoteScreen(WidgetTester tester, {required String localPlayerId}) async {
      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        totalPlayers: 3,
        currentReaderId: 'p1',
        isTimerDisabled: true,
        cards: [voteCard],
      );
      gameService.debugSetState(gameState, [p1, p2, p3], localPlayerId);

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
      // The lobby routes itself to the vote screen on the first frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(Phase3VoteScreen), findsOneWidget, reason: 'the app did not reach the vote screen');
      return rootBoundary;
    }

    /// Scroll [target] clear of the app bar and the pinned bottom button, check it is
    /// genuinely on screen, and measure it. [inflate] must keep the rect inside the
    /// target's own painted region (see the call sites).
    Future<ContrastSample> measure(
      WidgetTester tester,
      GlobalKey rootBoundary,
      Finder target, {
      double inflate = 4,
    }) async {
      expect(target, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
      await tester.pump();
      expect(target.hitTestable(), findsOneWidget, reason: 'the target is covered, so its pixels are not its own');
      return measureRenderedContrast(tester, rootBoundary, target, inflate: inflate);
    }

    testWidgets("target view: 'Keep a straight face while the parlor deliberates.' >= 4.5 : 1", (tester) async {
      try {
        final root = await pumpVoteScreen(tester, localPlayerId: 'p1');

        final sample = await measure(tester, root, find.text('Keep a straight face while the parlor deliberates.'));

        expect(sample.ratio, greaterThanOrEqualTo(4.5),
            reason: 'target subtitle measured ${sample.ratio.toStringAsFixed(2)} : 1 '
                '(${sample.foreground} on ${sample.background}); ink on the dark ground measured 1.18 : 1');
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('voter view: the subtitle, the OPTION label and the tap cue are each >= 4.5 : 1', (tester) async {
      try {
        final root = await pumpVoteScreen(tester, localPlayerId: 'p2');

        // Nothing selected, so the active card shows its cue (non-vacuity for the cue).
        expect(find.text('Tap to choose this one'), findsOneWidget);

        final failures = <String>[];
        // Subtitle on the dark ground: names whose card is being voted on.
        final subtitle = await measure(tester, root, find.textContaining("'s truth."));
        // The OPTION chip has 2 px of vertical padding and the cue sits 4 px under the
        // answer text, so a wide ring would pick up a neighbouring surface or glyph as the
        // "foreground" and mask a bad label: keep the rect inside the target's own region.
        final option = await measure(tester, root, find.text('OPTION I'), inflate: 1);
        final cue = await measure(tester, root, find.text('Tap to choose this one'), inflate: 2);

        for (final entry in {'subtitle': subtitle, 'OPTION I label': option, 'tap cue': cue}.entries) {
          if (entry.value.ratio < 4.5) {
            failures.add('${entry.key}: ${entry.value.ratio.toStringAsFixed(2)} : 1 '
                '(${entry.value.foreground} on ${entry.value.background})');
          }
        }
        debugPrint('vote screen voter view: subtitle ${subtitle.ratio.toStringAsFixed(2)}, '
            'OPTION ${option.ratio.toStringAsFixed(2)}, cue ${cue.ratio.toStringAsFixed(2)}');
        expect(failures, isEmpty, reason: 'below 4.5 : 1:\n${failures.join('\n')}');
      } finally {
        gameService.dispose();
      }
    });
  });
}
