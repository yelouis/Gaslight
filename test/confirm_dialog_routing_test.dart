import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:gaslight/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 181 / AI4 twin guard. Five confirmation dialogs had unstyled
/// `TextButton`s (oxblood on near-black, 1.78 : 1) while the sixth, the lobby
/// leave dialog, was already styled: the fix existed on one twin and not the
/// others. Every confirmation now goes through `GaslightConfirmDialog`; this file
/// fails if a dialog stops doing so, or if a new `AlertDialog` is copy-pasted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('every confirmation dialog is a GaslightConfirmDialog (Issue 181)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final host = PlayerState(id: 'p_host', name: 'Alice', isHost: true, joinedAt: 100, lobbyReady: true);
    final guest1 = PlayerState(id: 'p_g1', name: 'Bob', isHost: false, joinedAt: 200, lobbyReady: true);
    final guest2 = PlayerState(id: 'p_g2', name: 'Charlie', isHost: false, joinedAt: 300, lobbyReady: true);

    final card1 = CardModel(targetPlayerId: 'p_host', promptText: 'What is your secret?', truthAnswer: 'I love cats');
    final card2 = CardModel(targetPlayerId: 'p_g1', promptText: 'What is your hobby?', truthAnswer: 'Chess');
    final card3 = CardModel(targetPlayerId: 'p_g2', promptText: 'What is your fear?', truthAnswer: 'Spiders');

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() => gameService.dispose());

    /// [settle]: the lobby tests `pumpAndSettle`; the phase screens do not (their
    /// auto-advance ticker never goes idle), so they pump a fixed 300 ms instead.
    Future<void> pump(WidgetTester tester, Widget screen, {bool settle = false}) async {
      // 800 x 600, as in lobby_host_kick_test and in_game_leave_test.
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: screen,
            ),
          ),
        ),
      );
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    /// Taps [trigger], then asserts exactly one GaslightConfirmDialog with [title]
    /// and no bare AlertDialog beside it.
    Future<void> expectRouted(WidgetTester tester, Finder trigger, String title) async {
      expect(trigger, findsOneWidget, reason: 'the real entry point for "$title" must be on screen');
      await tester.tap(trigger);
      await tester.pumpAndSettle();

      expect(find.byType(GaslightConfirmDialog), findsOneWidget, reason: '"$title" is not a GaslightConfirmDialog');
      expect(tester.widget<GaslightConfirmDialog>(find.byType(GaslightConfirmDialog)).title, title);
      expect(find.descendant(of: find.byType(GaslightConfirmDialog), matching: find.text(title)), findsOneWidget);
      // The shared widget builds exactly one AlertDialog; a second would be a stray copy.
      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('lobby leave as host -> "Close this room?"', (tester) async {
      gameService.debugSetState(_lobbyState(), [host, guest1, guest2], 'p_host');
      await pump(tester, const LobbyScreen(), settle: true);
      await expectRouted(tester, find.byTooltip('Leave room'), 'Close this room?');
    });

    testWidgets('lobby leave as guest -> "Leave this room?"', (tester) async {
      gameService.debugSetState(_lobbyState(), [host, guest1, guest2], 'p_g1');
      await pump(tester, const LobbyScreen(), settle: true);
      await expectRouted(tester, find.byTooltip('Leave room'), 'Leave this room?');
    });

    testWidgets('host kick -> "Remove player?"', (tester) async {
      gameService.debugSetState(_lobbyState(), [host, guest1, guest2], 'p_host');
      await pump(tester, const LobbyScreen(), settle: true);
      await expectRouted(tester, find.byKey(const ValueKey('kick_p_g1')), 'Remove player?');
    });

    testWidgets('craft leave -> "Leave this game?"', (tester) async {
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentCardAssignments: {'p_host': 'p_host', 'p_g1': 'p_g1', 'p_g2': 'p_g2'},
      );
      gameService.debugSetState(state, [host, guest1, guest2], 'p_host');
      await pump(tester, const Phase2CraftScreen());
      await expectRouted(tester, find.byTooltip('Leave game'), 'Leave this game?');
    });

    testWidgets('vote leave -> "Leave this game?"', (tester) async {
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );
      gameService.debugSetState(state, [host, guest1, guest2], 'p_g1');
      await pump(tester, const Phase3VoteScreen());
      await expectRouted(tester, find.byTooltip('Leave game'), 'Leave this game?');
    });

    testWidgets('reveal leave -> "Leave this game?"', (tester) async {
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        cards: [card1, card2, card3],
        currentReaderId: 'p_host',
        resolutionOrder: ['p_host', 'p_g1', 'p_g2'],
      );
      gameService.debugSetState(state, [host, guest1, guest2], 'p_g2');
      await pump(tester, const Phase4RevealScreen());
      await expectRouted(tester, find.byTooltip('Leave game'), 'Leave this game?');
    });

    testWidgets('end voting as host -> "End Voting?"', (tester) async {
      final card = CardModel(
        targetPlayerId: 'p_g1',
        promptText: 'What is your secret?',
        truthAnswer: 'Real answer',
        sabotageAnswers: {'p_host': 'Fake answer'},
        options: [
          CardAnswerOption(id: 'opt_1', text: 'Real answer'),
          CardAnswerOption(id: 'opt_2', text: 'Fake answer'),
        ],
      );
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        currentReaderId: 'p_host',
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 3,
        selectedDeckId: PromptDecks.fallbackDeckId,
        cards: [card],
        readyPlayers: {'p_host': true},
      );
      gameService.debugSetState(state, [host, guest1, guest2], 'p_host');
      await pump(tester, const Phase3VoteScreen());
      await expectRouted(tester, find.text('PROCEED TO REVEAL (HOST)'), 'End Voting?');
    });

    // The six entry points above cannot see a SEVENTH dialog added somewhere they
    // do not open, so scan the source too: `AlertDialog(` may be constructed in
    // exactly one place. The positive control makes an empty scan impossible to
    // mistake for a clean one (lesson 2.44).
    test('no AlertDialog is constructed outside confirm_dialog.dart', () {
      final offenders = <String>[];
      var scanned = 0;
      var constructionsInSharedWidget = 0;
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        scanned++;
        final constructions = RegExp(r'(?<![A-Za-z_])AlertDialog\(').allMatches(entity.readAsStringSync()).length;
        if (entity.path.endsWith('widgets/confirm_dialog.dart')) {
          constructionsInSharedWidget = constructions;
        } else if (constructions > 0) {
          offenders.add('${entity.path} ($constructions)');
        }
      }

      expect(scanned, greaterThan(20), reason: 'the scan walked too few files to mean anything');
      expect(constructionsInSharedWidget, 1,
          reason: 'positive control: the shared widget must be found constructing its one AlertDialog');
      expect(offenders, isEmpty,
          reason: 'confirmations must use GaslightConfirmDialog; bare AlertDialog( found in: $offenders');
    });
  });
}

GameState _lobbyState() => GameState(
      roomCode: 'TEST',
      currentPhase: GamePhase.lobby,
      currentRound: 1,
      totalRounds: 3,
      totalPlayers: 3,
      sabotageAnswersCount: 1,
      forgeriesPerCard: 1,
      selectedDeckId: PromptDecks.fallbackDeckId,
    );
