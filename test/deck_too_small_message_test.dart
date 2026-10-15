import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

/// Issue 196 / AM1: the host's "deck too small" warning. The plural sentence is unchanged and pinned
/// on the real lobby; every count in it takes the matching noun. The singular cases cannot be reached
/// in the app today (the smallest deck holds 25 prompts and a room holds at most 8 players), so they
/// are asserted on the function itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deckTooSmallMessage gives every count its own noun (Issue 196 / AM1)', () {
    test('one round reads "1 round", two read "2 rounds"', () {
      expect(
        deckTooSmallMessage(5, 6, 6, 1),
        'Deck too small: selected deck has 5 prompts but you need 6 prompts (6 players × 1 round).',
      );
      expect(
        deckTooSmallMessage(5, 12, 6, 2),
        'Deck too small: selected deck has 5 prompts but you need 12 prompts (6 players × 2 rounds).',
      );
    });

    test('a deck of one prompt reads "1 prompt", a deck of two reads "2 prompts"', () {
      expect(
        deckTooSmallMessage(1, 3, 3, 1),
        'Deck too small: selected deck has 1 prompt but you need 3 prompts (3 players × 1 round).',
      );
      expect(
        deckTooSmallMessage(2, 3, 3, 1),
        'Deck too small: selected deck has 2 prompts but you need 3 prompts (3 players × 1 round).',
      );
    });

    test('the needed count and the player count follow their own numbers too', () {
      expect(
        deckTooSmallMessage(0, 1, 1, 1),
        'Deck too small: selected deck has 0 prompts but you need 1 prompt (1 player × 1 round).',
      );
    });

    test('the plural sentence is the one the lobby always showed', () {
      expect(
        deckTooSmallMessage(25, 30, 6, 5),
        'Deck too small: selected deck has 25 prompts but you need 30 prompts (6 players × 5 rounds).',
      );
    });
  });

  group('the deck-too-small warning on the real lobby (Issue 196 / AM1)', () {
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

    testWidgets('six players, five rounds and a 25-prompt deck read exactly as they always did', (tester) async {
      // "Real Life" holds 25 prompts; six players over five rounds need 30.
      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        totalRounds: 5,
        totalPlayers: 6,
        selectedDeckId: 'real_life',
      );
      final players = [
        PlayerState(id: 'p1', name: 'Alice', isHost: true, joinedAt: 100),
        for (var i = 2; i <= 6; i++) PlayerState(id: 'p$i', name: 'Player $i', joinedAt: 100 + i, lobbyReady: true),
      ];
      gameService.debugSetState(state, players, 'p1');

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

      expect(
        find.text('Deck too small: selected deck has 25 prompts but you need 30 prompts (6 players × 5 rounds).'),
        findsOneWidget,
      );
    });
  });
}
