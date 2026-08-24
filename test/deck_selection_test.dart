// Regression cover for Issue 106 — the chosen deck was ignored and every game
// played The Daily Grind.
//
// These assert the PAYLOAD and the ROOM, never the outcome. That distinction is
// the whole point: `test/fake_functions.dart` resolves the deck from the room
// document, so a test that only checked which prompts came back would have
// passed against the bug. The defect lived in the value the client handed to
// the callable, and only a payload assertion can see it.
//
// Falsified before the fix: with `startGame(_selectedDeck)` still in place, the
// first test failed with
//   Expected: 'rated_r_nsfw'
//     Actual: 'the_daily_grind'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;

  GameState lobbyWithDeck(String deckId) => GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        currentRound: 1,
        totalRounds: 1,
        totalPlayers: 3,
        sabotageAnswersCount: 1,
        forgeriesPerCard: 1,
        selectedDeckId: deckId,
      );

  List<PlayerState> readyTable() => [
        PlayerState(id: 'p_host', name: 'Alice', isHost: true, joinedAt: 100, lobbyReady: false),
        PlayerState(id: 'p_g1', name: 'Bob', isHost: false, joinedAt: 200, lobbyReady: true),
        PlayerState(id: 'p_g2', name: 'Charlie', isHost: false, joinedAt: 300, lobbyReady: true),
      ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    gameService = GameService(db: mockDb, functions: fakeFns);
  });

  Future<void> pumpLobby(WidgetTester tester) async {
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
  }

  group('Issue 106 — the started deck is the chosen deck', () {
    for (final deckId in const ['rated_r_nsfw', 'cah_dark_humor', 'deep_fears_and_phobias', 'custom']) {
      testWidgets('START GAME sends "$deckId" when the room has it selected', (tester) async {
        // Seed the fake Firestore room too, not just GameService's in-memory
        // state: the fake callable resolves the deck from the room document,
        // exactly as the real server now does.
        await tester.runAsync(() async {
          await mockDb.collection('rooms').doc('TEST').set(lobbyWithDeck(deckId).toMap());
          for (final p in readyTable()) {
            await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(p.toMap());
          }
        });
        gameService.debugSetState(lobbyWithDeck(deckId), readyTable(), 'p_host');
        await pumpLobby(tester);

        final btn = find.widgetWithText(PrimaryButton, 'START GAME');
        expect(tester.widget<PrimaryButton>(btn).onPressed, isNotNull);

        await tester.tap(btn);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(fakeFns.lastCallName, 'startGame');
        expect(
          fakeFns.lastCallParams?['selectedDeckId'],
          deckId,
          reason: 'the room has $deckId selected, so that is what must be started',
        );
      });
    }
  });
}
