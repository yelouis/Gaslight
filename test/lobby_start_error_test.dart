// The host used to get "Something went wrong. Try again." for every startGame
// failure, which is what made a real incident undiagnosable: the server was
// returning a precise, actionable refusal ("At least 3 players are required")
// and the UI threw it away.
//
// These assert the message the host actually reads. Falsified against the old
// handler — every case below returned the generic string.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;

  GameState lobby() => GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        currentRound: 1,
        totalRounds: 1,
        totalPlayers: 3,
        sabotageAnswersCount: 1,
        forgeriesPerCard: 1,
        selectedDeckId: PromptDecks.fallbackDeckId,
      );

  PlayerState host() => PlayerState(id: 'p_host', name: 'Alice', isHost: true, joinedAt: 100, lobbyReady: false);
  PlayerState bob({bool ready = true}) =>
      PlayerState(id: 'p_g1', name: 'Bob', isHost: false, joinedAt: 200, lobbyReady: ready);
  PlayerState charlie({bool ready = true}) =>
      PlayerState(id: 'p_g2', name: 'Charlie', isHost: false, joinedAt: 300, lobbyReady: ready);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    gameService = GameService(db: mockDb, functions: fakeFns);
  });

  /// The message the host actually reads, scoped to the SnackBar: when the
  /// roster genuinely changed, the same sentence also renders inline under the
  /// button, and an unscoped finder would trip over both.
  Finder snackText(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  /// Starts from a lobby the host may legitimately start, then makes startGame
  /// fail with [code]. [onFail] runs just before the throw, so a test can model
  /// the room changing underneath the host — which is the real-world case.
  Future<void> pumpAndFailStart(
    WidgetTester tester, {
    required String code,
    void Function()? onFail,
  }) async {
    gameService.debugSetState(lobby(), [host(), bob(), charlie()], 'p_host');
    fakeFns.overrideCallable('startGame', (params) async {
      onFail?.call();
      throw FirebaseFunctionsException(code: code, message: 'server side detail, deliberately not shown');
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<GameService>.value(
        value: gameService,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(accessibleNavigation: true),
            child: LobbyScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final btn = find.widgetWithText(PrimaryButton, 'START GAME');
    expect(tester.widget<PrimaryButton>(btn).onPressed, isNotNull,
        reason: 'the lobby must look startable, or the test is not exercising the failure path');
    await tester.tap(btn);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a player dropping is named, not hidden behind "something went wrong"', (tester) async {
    try {
      await pumpAndFailStart(
        tester,
        code: 'failed-precondition',
        // The room lost a player between the tap and the refusal — exactly the
        // incident this was written for.
        onFail: () => gameService.debugSetState(lobby(), [host(), bob()], 'p_host'),
      );
      expect(snackText('Need at least 3 active players to start.'), findsOneWidget);
      expect(snackText('Something went wrong. Try again.'), findsNothing);
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('an unready player is named', (tester) async {
    try {
      await pumpAndFailStart(
        tester,
        code: 'failed-precondition',
        onFail: () => gameService.debugSetState(
            lobby(), [host(), bob(), charlie(ready: false)], 'p_host'),
      );
      expect(snackText('Waiting on 1 of 2 players to ready up.'), findsOneWidget);
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('a refusal the client cannot re-derive still says something useful', (tester) async {
    try {
      // Server refused but local state already looks fine again: say so plainly
      // rather than pretending to know which condition it was.
      await pumpAndFailStart(tester, code: 'failed-precondition');
      expect(
        snackText('The lobby changed just as the game started. Check everyone is still here and ready, then try again.'),
        findsOneWidget,
      );
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('a lost session tells the host to reload', (tester) async {
    try {
      await pumpAndFailStart(tester, code: 'unauthenticated');
      expect(snackText('You have been signed out. Reload the page and rejoin.'), findsOneWidget);
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('an unrecognised code still falls back to the generic message', (tester) async {
    try {
      // Over-reach guard: this must NOT invent a specific reason it cannot know.
      await pumpAndFailStart(tester, code: 'internal');
      expect(snackText('Something went wrong. Try again.'), findsOneWidget);
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('server-supplied text is never shown to the player', (tester) async {
    try {
      await pumpAndFailStart(tester, code: 'failed-precondition');
      expect(find.textContaining('server side detail'), findsNothing,
          reason: 'design_ui_direction.md 6 - never interpolate an exception into user-facing text');
    } finally {
      gameService.dispose();
    }
  });
}
