import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Issue 184 / AI7: instructions must not be truncated on a small phone.
///
/// On an iPhone SE (375 x 667) the vote button read "TAP A CARD TO CHOO…" and the
/// unmask heading "REVENGE UNMASKIN…" at the default text size, and at 1.3 every
/// game-over row hid "Fooled by N". `design_ui_direction.md` promises "Layouts must
/// still survive 1.3."
///
/// The real app fonts are loaded (as in highlight_card_truncation_test): under
/// `flutter test` text otherwise renders in Ahem, one em per glyph, which is far
/// wider than Lora and would make these thresholds measure the test font.
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
  });

  group('instructions are not truncated on a small phone (Issue 184 / AI7)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    /// The real app on whichever screen [state] routes to.
    Future<void> pumpApp(
      WidgetTester tester, {
      required GameState state,
      required List<PlayerState> players,
      required String localPlayerId,
      required Size size,
      required double textScale,
    }) async {
      gameService.debugSetState(state, players, localPlayerId);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(value: gameService, child: const GaslightApp()),
      );
      // The lobby routes itself to the right screen on the first frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // ---- (a) the vote screen, voter view, nothing selected ----------------------
    final alice = PlayerState(id: 'p1', name: 'Alice', isHost: true);
    final bob = PlayerState(id: 'p2', name: 'Bob');
    final charlie = PlayerState(id: 'p3', name: 'Charlie');
    final voteCard = CardModel(
      promptText: 'What is Alice secret truth?',
      targetPlayerId: 'p1',
      truthAnswer: 'Alice Real Truth',
      sabotageAnswers: {'p2': 'Bob Own Forgery Answer', 'p3': 'Charlie Forgery Answer'},
      options: [
        CardAnswerOption(id: 'opt1', text: 'Charlie Forgery Answer'),
        CardAnswerOption(id: 'opt2', text: 'Bob Own Forgery Answer'),
        CardAnswerOption(id: 'opt3', text: 'THE SOUL IS SILENT'),
      ],
    );

    Future<void> pumpVoteButton(WidgetTester tester, Size size, double scale) => pumpApp(
          tester,
          state: GameState(
            roomCode: 'TEST',
            currentPhase: GamePhase.vote,
            totalPlayers: 3,
            currentReaderId: 'p1',
            isTimerDisabled: true,
            cards: [voteCard],
          ),
          players: [alice, bob, charlie],
          localPlayerId: 'p2',
          size: size,
          textScale: scale,
        );

    // ---- (b) the reveal's unmask panel while the local player is fooled ---------
    Future<void> pumpUnmaskPanel(WidgetTester tester, Size size, double scale) async {
      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'What is Alice secret truth?',
        truthAnswer: 'Alice Real Truth',
        sabotageAnswers: {'p3': 'Charlie Forgery Answer'},
        votes: {'p2': 'p3'}, // Bob voted Charlie's forgery: he is fooled
      );
      await pumpApp(
        tester,
        state: GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1'],
          // A live unmask window, so the panel (and its countdown badge) is on screen.
          unmaskDeadline: DateTime.now().millisecondsSinceEpoch + 120000,
        ),
        players: [alice, bob, charlie],
        localPlayerId: 'p2',
        size: size,
        textScale: scale,
      );
      // The panel appears when the reveal reaches its unmask stage.
      for (var i = 0; i < 40 && find.text('REVENGE UNMASKING!').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    // ---- (c) a game-over standings row ------------------------------------------
    Future<void> pumpStandings(WidgetTester tester, Size size, double scale) => pumpApp(
          tester,
          state: GameState(
            roomCode: 'TEST',
            currentPhase: GamePhase.gameOver,
            totalPlayers: 3,
            cards: [],
            currentCardAssignments: {},
            readyPlayers: {},
          ),
          players: [
            PlayerState(id: 'p1', name: 'Alice', totalScore: 40, playersDeceived: 5, timesFooled: 1, role: PlayerRole.voter),
            PlayerState(id: 'p2', name: 'Bob', totalScore: 30, playersDeceived: 1, timesFooled: 2, role: PlayerRole.voter),
            PlayerState(id: 'p3', name: 'Charlie', totalScore: 20, playersDeceived: 3, timesFooled: 3, role: PlayerRole.voter),
          ],
          localPlayerId: 'p1',
          size: size,
          textScale: scale,
        );

    /// Fail text for [text] if its paragraph exceeded its max lines.
    String? truncationFailure(WidgetTester tester, String text) {
      expect(find.text(text), findsOneWidget, reason: '"$text" must be on screen for the check to mean anything');
      final para = tester.renderObject<RenderParagraph>(find.text(text));
      return para.didExceedMaxLines ? '"$text" exceeded its max lines' : null;
    }

    for (final size in const [Size(320, 640), Size(375, 667)]) {
      for (final scale in const [1.0, 1.3]) {
        final where = '${size.width.toInt()} x ${size.height.toInt()}, text scale $scale';

        testWidgets('(a) vote button "TAP A CARD TO CHOOSE" at $where', (tester) async {
          try {
            await pumpVoteButton(tester, size, scale);
            const label = 'TAP A CARD TO CHOOSE';
            final failures = <String>[];

            final truncated = truncationFailure(tester, label);
            if (truncated != null) failures.add(truncated);

            // Scale-down must stay legible: if 320 x 1.3 falls below 0.6 the label needs
            // a copy change, which was not selected, and this must be filed, not forced.
            final fitted = find.ancestor(of: find.text(label), matching: find.byType(FittedBox));
            if (fitted.evaluate().isEmpty) {
              failures.add('the label is not inside a FittedBox, so it cannot scale down');
            } else {
              final scaleFactor = tester.getSize(fitted.first).width / tester.getSize(find.text(label)).width;
              debugPrint('(a) $where: FittedBox scale ${scaleFactor.toStringAsFixed(3)}');
              if (scaleFactor < 0.6) failures.add('FittedBox scale ${scaleFactor.toStringAsFixed(3)} < 0.6');
            }
            expect(failures, isEmpty, reason: failures.join('\n'));
          } finally {
            gameService.dispose();
          }
        });

        testWidgets('(b) unmask heading "REVENGE UNMASKING!" at $where', (tester) async {
          try {
            await pumpUnmaskPanel(tester, size, scale);
            final truncated = truncationFailure(tester, 'REVENGE UNMASKING!');
            expect(truncated, isNull, reason: truncated);
          } finally {
            gameService.dispose();
          }
        });

        testWidgets('(c) game-over standings row "Fooled 1 · Fooled by 2" at $where', (tester) async {
          try {
            await pumpStandings(tester, size, scale);
            final truncated = truncationFailure(tester, 'Fooled 1 · Fooled by 2');
            expect(truncated, isNull, reason: truncated);
          } finally {
            gameService.dispose();
          }
        });
      }
    }
  });
}
