import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F1: DEBUG buttons gating tests', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    final hostPlayer = PlayerState(
      id: 'p_host',
      name: 'Alice',
      isHost: true,
      joinedAt: 100,
      lobbyReady: true,
    );

    final guestPlayer = PlayerState(
      id: 'p_guest',
      name: 'Bob',
      isHost: false,
      joinedAt: 200,
      lobbyReady: true,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    testWidgets('LobbyScreen retains DEBUG: ADD 9 BOTS under kDebugMode (test environment)', (WidgetTester tester) async {
      final lobbyGameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 2,
        selectedDeckId: PromptDecks.fallbackDeckId,
      );

      gameService.debugSetState(lobbyGameState, [hostPlayer, guestPlayer], 'p_host');

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

      expect(kDebugMode, isTrue);
      // In test mode (kDebugMode is true), the button is present (proving it was gated, not deleted).
      expect(find.text('DEBUG: ADD 9 BOTS'), findsOneWidget);
    });

    testWidgets('Phase2CraftScreen retains DEBUG: BOTS SUBMIT for host under kDebugMode', (WidgetTester tester) async {
      final card = CardModel(
        targetPlayerId: 'p_host',
        promptText: 'What is your secret?',
        truthAnswer: '',
        sabotageAnswers: {},
      );

      final craftGameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 2,
        selectedDeckId: PromptDecks.fallbackDeckId,
        cards: [card],
      );

      gameService.debugSetState(craftGameState, [hostPlayer, guestPlayer], 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Scaffold(
              body: Phase2CraftScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(kDebugMode, isTrue);
      expect(find.text('DEBUG: BOTS SUBMIT'), findsOneWidget);
    });

    testWidgets('Phase3VoteScreen retains DEBUG: BOTS SUBMIT for host under kDebugMode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final card = CardModel(
        targetPlayerId: 'p_guest',
        promptText: 'What is your secret?',
        truthAnswer: 'Real answer',
        sabotageAnswers: {'p_host': 'Fake answer'},
        options: [
          CardAnswerOption(id: 'opt_1', text: 'Real answer'),
          CardAnswerOption(id: 'opt_2', text: 'Fake answer'),
        ],
      );

      final voteGameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.vote,
        currentReaderId: 'p_host',
        currentRound: 1,
        totalRounds: 3,
        totalPlayers: 2,
        selectedDeckId: PromptDecks.fallbackDeckId,
        cards: [card],
        readyPlayers: {'p_host': true},
      );

      gameService.debugSetState(voteGameState, [hostPlayer, guestPlayer], 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Scaffold(
              body: Phase3VoteScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(kDebugMode, isTrue);
      expect(find.text('DEBUG: BOTS SUBMIT'), findsOneWidget);
    });
  });
}
