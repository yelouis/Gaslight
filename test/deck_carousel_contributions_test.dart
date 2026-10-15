import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/deck_carousel.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 196 / AM1: the custom deck's folder says how many prompts the players have written and how
/// many of them wrote them. It read "1 prompts from 1 players" for the first contribution.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the custom deck folder agrees with its numbers (Issue 196 / AM1)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    tearDown(() {
      gameService.dispose();
    });

    /// The carousel with only the custom folder in it, over a room whose players wrote [prompts].
    /// One entry per player; a spectator's prompts do not count, as in the app.
    Future<void> pumpCustomFolder(WidgetTester tester, List<List<String>> prompts) async {
      final players = [
        for (var i = 0; i < prompts.length; i++)
          PlayerState(id: 'p${i + 1}', name: 'Player ${i + 1}', isHost: i == 0, customPrompts: prompts[i]),
      ];
      gameService.debugSetState(
        GameState(roomCode: 'TEST', currentPhase: GamePhase.lobby, totalPlayers: players.length, selectedDeckId: 'custom'),
        players,
        'p1',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: Scaffold(
                body: DeckCarousel(
                  selectedDeckId: 'custom',
                  availableDecks: const ['custom'],
                  onDeckSelected: (_) {},
                  isHost: false,
                  gameService: gameService,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CUSTOM DECK'), findsOneWidget, reason: 'the folder under test must be on screen');
    }

    testWidgets('one prompt from one player reads "1 prompt from 1 player"', (tester) async {
      await pumpCustomFolder(tester, [
        ['Only prompt'],
      ]);

      expect(find.text('1 prompt from 1 player'), findsOneWidget);
      expect(find.text('1 prompts from 1 players'), findsNothing);
    });

    testWidgets('two prompts from two players read "2 prompts from 2 players"', (tester) async {
      await pumpCustomFolder(tester, [
        ['First prompt'],
        ['Second prompt'],
      ]);

      expect(find.text('2 prompts from 2 players'), findsOneWidget);
    });

    testWidgets('each noun follows its own number: three prompts from one player', (tester) async {
      await pumpCustomFolder(tester, [
        ['One', 'Two', 'Three'],
        const [],
      ]);

      expect(find.text('3 prompts from 1 player'), findsOneWidget);
    });
  });
}
