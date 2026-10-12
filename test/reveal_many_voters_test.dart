import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/player_avatar.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 180 / AI6: a reveal answer must stay readable when many players found it.
///
/// The option card is a `Row` of `Expanded(answer)` and a non-flex
/// `Column(VOTES, Wrap(voters))`. A `Row` gives a non-flex child unbounded width, so
/// the `Wrap` never wrapped: the voters column was 32n - 4 pt wide. On a 375-pt phone
/// the card row is 289 pt, so 9 voters left the answer 0 pt and raised
/// `A RenderFlex overflowed by 7.0 pixels on the right`; rooms hold 10 players.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reveal answer stays readable with many voters (Issue 180 / AI6)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    // Long enough that its Text fills whatever width the Expanded gives it: with the
    // Ahem test font every glyph is a full em wide, so a short string would measure
    // the string, not the layout.
    const answer = 'The truth is that I once spent an entire weekend teaching my cat to high five '
        'because I was lonely and the cat was not impressed at all';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    /// Alice (the target) plus [voterCount] players who all voted the TRUTH, plus the
    /// padding players needed to reach 10 so the room looks like a full table.
    Future<void> pumpReveal(
      WidgetTester tester, {
      required int voterCount,
      required Size size,
      required double textScale,
    }) async {
      final alice = PlayerState(id: 'alice', name: 'Alice', joinedAt: 100);
      final others = [
        for (var i = 1; i <= 9; i++) PlayerState(id: 'v$i', name: 'Voter $i', joinedAt: 100 + i),
      ];
      final players = [alice, ...others];
      final voters = others.take(voterCount).toList();

      final card = CardModel(
        targetPlayerId: 'alice',
        promptText: 'What did Alice do one weekend?',
        truthAnswer: answer,
        sabotageAnswers: {'v1': 'Forgery by one', 'v2': 'Forgery by two'},
        votes: {for (final v in voters) v.id: 'alice'},
      );
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: players.length,
        currentReaderId: 'alice',
        cards: [card],
        readyPlayers: {for (final p in players) p.id: true},
        resolutionOrder: ['alice'],
        unmaskDeadline: 0,
      );
      gameService.debugSetState(state, players, 'alice');

      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: true, textScaler: TextScaler.linear(textScale)),
              child: const Phase4RevealScreen(),
            ),
          ),
        ),
      );
      // Past the truth flip (reveal stage >= 4); pump(Duration), not pumpAndSettle.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// The card [Row] that contains the VOTES column, and the pieces inside it.
    Finder cardRow() => find.ancestor(of: find.text('VOTES'), matching: find.byType(Row)).first;
    Finder votersColumn() => find.ancestor(of: find.text('VOTES'), matching: find.byType(Column)).first;
    Finder cardContainer() => find.ancestor(of: find.text('VOTES'), matching: find.byType(Container)).first;

    for (final size in const [Size(320, 640), Size(375, 667)]) {
      for (final scale in const [1.0, 1.3]) {
        testWidgets('9 voters on the truth at ${size.width.toInt()} x ${size.height.toInt()}, text scale $scale', (tester) async {
          try {
            await pumpReveal(tester, voterCount: 9, size: size, textScale: scale);

            // Every check is evaluated and reported together, so a regression shows
            // BOTH the overflow and the starved answer, not just the first.
            final failures = <String>[];

            // No overflow anywhere on the screen.
            final exception = tester.takeException();
            if (exception != null) failures.add('overflow: ${exception.toString().split('\n').first}');

            // Non-vacuity: the card really holds all 9 voter avatars (28 pt tokens).
            final voterAvatars = find.descendant(
              of: cardContainer(),
              matching: find.byWidgetPredicate((w) => w is PlayerAvatar && w.size == 28),
            );
            expect(voterAvatars, findsNWidgets(9), reason: 'the fixture must put 9 voters on the truth card');
            expect(find.text(answer), findsOneWidget);

            // The answer keeps at least half of the card row.
            final answerWidth = tester.getSize(find.text(answer)).width;
            final rowWidth = tester.getSize(cardRow()).width;
            if (answerWidth < 0.5 * rowWidth) {
              failures.add('answer width: ${answerWidth.toStringAsFixed(1)} pt of a ${rowWidth.toStringAsFixed(1)} pt row '
                  '(needs >= ${(0.5 * rowWidth).toStringAsFixed(1)}; voters column ${tester.getSize(votersColumn()).width.toStringAsFixed(1)} pt)');
            }

            expect(failures, isEmpty, reason: failures.join('\n'));
          } finally {
            gameService.dispose();
          }
        });
      }
    }

    testWidgets('one voter: the voters column is narrower than 92 pt, so the common case is unchanged', (tester) async {
      try {
        await pumpReveal(tester, voterCount: 1, size: const Size(375, 667), textScale: 1.0);

        expect(tester.takeException(), isNull);
        expect(find.descendant(
          of: cardContainer(),
          matching: find.byWidgetPredicate((w) => w is PlayerAvatar && w.size == 28),
        ), findsOneWidget);
        expect(tester.getSize(votersColumn()).width, lessThan(92));
      } finally {
        gameService.dispose();
      }
    });

    testWidgets('nine voters: the voters column is exactly 92 pt (3 tokens of 28 + 2 gaps of 4), in rows of at most three', (tester) async {
      try {
        await pumpReveal(tester, voterCount: 9, size: const Size(375, 667), textScale: 1.0);

        expect(tester.takeException(), isNull);
        expect(tester.getSize(votersColumn()).width, 92.0);

        // Rows of at most three: no token starts further right than the third slot.
        final avatars = find.descendant(
          of: cardContainer(),
          matching: find.byWidgetPredicate((w) => w is PlayerAvatar && w.size == 28),
        );
        final columnLeft = tester.getTopLeft(votersColumn()).dx;
        for (var i = 0; i < 9; i++) {
          final dx = tester.getTopLeft(avatars.at(i)).dx - columnLeft;
          expect(dx, lessThanOrEqualTo(2 * (28 + 4) + 0.01), reason: 'token $i starts at $dx pt: more than three per row');
        }
      } finally {
        gameService.dispose();
      }
    });
  });
}
