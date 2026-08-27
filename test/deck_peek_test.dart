import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/utils/prompt_decks.dart';
import 'package:gaslight/widgets/deck_peek_sheet.dart';
import 'package:gaslight/widgets/deck_carousel.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirestore mockDb;
  late FakeFirebaseFunctions fakeFns;
  late GameService gameService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockDb = FakeFirestore();
    fakeFns = FakeFirebaseFunctions(mockDb);
    gameService = GameService(db: mockDb, functions: fakeFns);
  });

  tearDown(() {
    gameService.dispose();
  });

  GameState makeLobbyState(String deckId) => GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.lobby,
        selectedDeckId: deckId,
        totalPlayers: 3,
      );

  List<PlayerState> makePlayers() => [
        PlayerState(id: 'p_host', name: 'Alice', isHost: true),
        PlayerState(id: 'p_2', name: 'Bob', isHost: false),
        PlayerState(id: 'p_3', name: 'Charlie', isHost: false),
      ];

  group('Issue 126 (P8): Deck Peek Inside Tests', () {
    testWidgets('DeckPeekSheet displays exactly 8 prompt rows drawn from deck prompts list', (WidgetTester tester) async {
      final deckId = PromptDecks.allDecks.first.id;
      final deck = PromptDecks.getDeck(deckId)!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckPeekSheet(deckId: deckId),
          ),
        ),
      );
      await tester.pump();

      // Assert heading is present
      expect(find.text("A TASTE OF WHAT'S INSIDE"), findsOneWidget);

      // Assert deck display name and prompt count
      expect(find.text(deck.displayName), findsOneWidget);
      expect(find.text('${deck.prompts.length} PROMPTS'), findsOneWidget);

      // Assert exactly 8 prompt widgets
      final promptContainers = find.byWidgetPredicate(
        (widget) => widget.key is ValueKey<String> && (widget.key as ValueKey<String>).value.startsWith('peek_prompt_'),
      );
      expect(promptContainers, findsNWidgets(8));

      // Assert every rendered prompt is a member of the deck's prompts list
      for (int i = 0; i < 8; i++) {
        final itemFinder = find.byKey(ValueKey('peek_prompt_$i'));
        expect(itemFinder, findsOneWidget);
        final textWidgets = tester.widgetList<Text>(
          find.descendant(of: itemFinder, matching: find.byType(Text)),
        );
        // Second text widget is the prompt text
        final promptText = textWidgets.last.data!;
        expect(deck.prompts.contains(promptText), isTrue,
            reason: 'Prompt "$promptText" must be in ${deck.displayName} prompts');
      }
    });

    testWidgets('SHUFFLE button changes the rendered set of prompts within 5 attempts', (WidgetTester tester) async {
      final deckId = PromptDecks.allDecks.first.id;
      final deck = PromptDecks.getDeck(deckId)!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckPeekSheet(deckId: deckId),
          ),
        ),
      );
      await tester.pump();

      List<String> getRenderedPrompts() {
        final list = <String>[];
        for (int i = 0; i < 8; i++) {
          final itemFinder = find.byKey(ValueKey('peek_prompt_$i'));
          final textWidgets = tester.widgetList<Text>(
            find.descendant(of: itemFinder, matching: find.byType(Text)),
          );
          list.add(textWidgets.last.data!);
        }
        return list;
      }

      final initialPrompts = getRenderedPrompts();
      bool producedDifferentSet = false;

      final shuffleBtn = find.byKey(const ValueKey('deck_peek_shuffle'));
      expect(shuffleBtn, findsOneWidget);

      // Test over 5 shuffles that at least one differs from initial
      for (int attempt = 0; attempt < 5; attempt++) {
        await tester.tap(shuffleBtn);
        await tester.pump();
        final currentPrompts = getRenderedPrompts();
        if (currentPrompts.join('|') != initialPrompts.join('|')) {
          producedDifferentSet = true;
          break;
        }
      }

      expect(producedDifferentSet, isTrue,
          reason: 'At least one shuffle in 5 attempts must produce a different 8-prompt sample');
    });

    testWidgets('Peek Inside bottom sheet renders cleanly at 320 pt with no overflow', (WidgetTester tester) async {
      final deckId = PromptDecks.allDecks.first.id;

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeckPeekSheet(deckId: deckId),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('PEEK INSIDE button opens sheet from carousel and leaves selectedDeckId unchanged', (WidgetTester tester) async {
      final allDeckIds = PromptDecks.allDecks.map((d) => d.id).toList();
      final deckId = allDeckIds.first;
      final state = makeLobbyState(deckId);
      final players = makePlayers();
      gameService.debugSetState(state, players, 'p_host');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: Scaffold(
              body: DeckCarousel(
                selectedDeckId: deckId,
                availableDecks: allDeckIds,
                onDeckSelected: (_) {},
                isHost: true,
                gameService: gameService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Centred deck has PEEK INSIDE button
      final peekBtn = find.byKey(ValueKey('peek_inside_$deckId'));
      expect(peekBtn, findsOneWidget);

      // Tap PEEK INSIDE
      await tester.tap(peekBtn);
      await tester.pumpAndSettle();

      // Sheet is open
      expect(find.byType(DeckPeekSheet), findsOneWidget);
      expect(find.text("A TASTE OF WHAT'S INSIDE"), findsOneWidget);

      // Dismiss sheet
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(DeckPeekSheet), findsNothing);
      expect(gameService.gameState?.selectedDeckId, equals(deckId));
    });
  });
}
