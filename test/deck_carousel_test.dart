import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/deck_carousel.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue 52: Non-host Deck Carousel Read-Only Tests', () {
    late FakeFirestore mockDb;
    late FakeFirebaseFunctions fakeFunctions;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      fakeFunctions = FakeFirebaseFunctions(mockDb);
      gameService = GameService(db: mockDb, functions: fakeFunctions);
    });

    tearDown(() {
      gameService.dispose();
    });

    final availableDecks = [
      'the_daily_grind',
      'deep_fears_and_phobias',
      'unhinged_quirks',
      'romantic_disasters',
      'rated_r_nsfw',
      'cah_dark_humor',
      'custom',
    ];

    Future<void> pumpDeckCarousel(
      WidgetTester tester, {
      required bool isHost,
      String selectedDeckId = 'the_daily_grind',
      bool reduceMotion = true,
    }) async {
      await tester.runAsync(() async {
        await gameService.createRoom(isHost ? 'Host' : 'Guest', isHost ? 'p_host' : 'p_guest');
        gameService.stopHeartbeat();
        if (!isHost) {
          await mockDb.collection('rooms').doc('TEST').collection('players').doc('p_guest').update({'isHost': false});
        }
        await Future.delayed(const Duration(milliseconds: 100));
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(accessibleNavigation: reduceMotion),
              child: Scaffold(
                body: DeckCarousel(
                  selectedDeckId: selectedDeckId,
                  availableDecks: availableDecks,
                  onDeckSelected: (val) => gameService.updateLobbySettings(selectedDeckId: val),
                  isHost: isHost,
                  gameService: gameService,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('non-host sees every deck', (tester) async {
      await pumpDeckCarousel(tester, isHost: false);

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      final pageView = tester.widget<PageView>(pageViewFinder);
      final builderDelegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
      expect(builderDelegate.childCount, equals(7));
      expect(find.text('THE CHOSEN FILE'), findsOneWidget);
    });

    testWidgets('non-host cannot select a deck', (tester) async {
      await pumpDeckCarousel(tester, isHost: false);

      final pageViewFinder = find.byType(PageView);
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(fakeFunctions.callableInvocations['updateLobbySettings'] ?? 0, equals(0));
    });

    testWidgets('non-host can still see which deck is chosen', (tester) async {
      await pumpDeckCarousel(tester, isHost: false, selectedDeckId: 'the_daily_grind');

      expect(find.text('CHOSEN'), findsOneWidget);
    });

    testWidgets('host selection still works', (tester) async {
      await pumpDeckCarousel(tester, isHost: true, selectedDeckId: 'the_daily_grind');

      expect(find.text('THE CHOSEN FILE'), findsNothing);

      final pageViewFinder = find.byType(PageView);
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(fakeFunctions.callableInvocations['updateLobbySettings'], equals(1));
      expect(fakeFunctions.lastCallParams?['selectedDeckId'], equals('deep_fears_and_phobias'));
    });

    testWidgets('360x640 portrait layout fits non-host carousel without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpDeckCarousel(tester, isHost: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not yank page when selectedDeckId changes within 3 seconds of swipe', (tester) async {
      String currentSelected = 'the_daily_grind';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: DeckCarousel(
                  selectedDeckId: currentSelected,
                  availableDecks: availableDecks,
                  onDeckSelected: (_) {},
                  isHost: false,
                  gameService: gameService,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final pageViewFinder = find.byType(PageView);
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Trigger didUpdateWidget with new selectedDeckId right after swipe
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: DeckCarousel(
                  selectedDeckId: 'unhinged_quirks',
                  availableDecks: availableDecks,
                  onDeckSelected: (_) {},
                  isHost: false,
                  gameService: gameService,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(pageViewFinder);
      expect(pageView.controller?.page, closeTo(1.0, 0.1));
    });
  });
}
