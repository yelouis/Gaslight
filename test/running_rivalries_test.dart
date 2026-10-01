import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase2_craft.dart';
import 'package:gaslight/screens/phase3_vote.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'package:gaslight/screens/game_over_screen.dart';
import 'package:gaslight/widgets/parlour_ledger.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';
import 'helpers/png_decoder.dart';

double _getContrastRatio(Color fg, Color bg) {
  final fgR = (fg.r * 255.0).round().clamp(0, 255);
  final fgG = (fg.g * 255.0).round().clamp(0, 255);
  final fgB = (fg.b * 255.0).round().clamp(0, 255);
  final bgR = (bg.r * 255.0).round().clamp(0, 255);
  final bgG = (bg.g * 255.0).round().clamp(0, 255);
  final bgB = (bg.b * 255.0).round().clamp(0, 255);

  final l1 = relativeLuminance(fgR, fgG, fgB);
  final l2 = relativeLuminance(bgR, bgG, bgB);
  return contrastRatio(l1, l2);
}

Color _resolveBackgroundForElement(Element textElement) {
  Color? bg;
  textElement.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is Container && widget.decoration is BoxDecoration) {
      final dec = widget.decoration as BoxDecoration;
      if (dec.color != null && dec.color!.a > 0) {
        bg = dec.color;
        return false;
      }
    }
    if (widget is DecoratedBox && widget.decoration is BoxDecoration) {
      final dec = widget.decoration as BoxDecoration;
      if (dec.color != null && dec.color!.a > 0) {
        bg = dec.color;
        return false;
      }
    }
    return true;
  });
  if (bg != null) {
    return Color.alphaBlend(bg!, AppColors.ground);
  }
  return AppColors.ground;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Running Rivalries (Wave AG / AG3, Issue 177 Option B)', () {
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

    Future<void> settleReveal(WidgetTester tester, int ms) async {
      final steps = ms ~/ 200;
      for (int i = 0; i < steps; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('Validation 9: ParlourLedger renders nothing when empty; renders groups, spotted copy, and top read once with CLOSEST badge', (WidgetTester tester) async {
      // 1. When empty, renders nothing
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParlourLedger(runningRivalries: {'fools': [], 'reads': []}),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('parlour_ledger')), findsNothing);
      expect(find.text('THE PARLOUR REMEMBERS'), findsNothing);

      // When null, renders nothing
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ParlourLedger(runningRivalries: null),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('parlour_ledger')), findsNothing);

      // 2. When both have entries
      final fixture = {
        'fools': [
          {
            'deceiverId': 'p2',
            'deceiverName': 'Bob',
            'victimId': 'p1',
            'victimName': 'Alice',
            'count': 2,
            'occurrences': [
              {
                'round': 1,
                'cardOwnerId': 'p3',
                'cardOwnerName': 'Charlie',
                'promptText': 'Secret of the parlour',
                'lieText': 'Bob fake secret',
              },
            ],
          },
        ],
        'reads': [
          {
            'readerId': 'p1',
            'readerName': 'Alice',
            'forgerId': 'p2',
            'forgerName': 'Bob',
            'count': 1,
            'occurrences': [
              {
                'round': 1,
                'cardOwnerId': 'p1',
                'cardOwnerName': 'Alice',
                'promptText': 'Alice own secret',
                'lieText': 'Bob sneaky lie',
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParlourLedger(runningRivalries: fixture),
          ),
        ),
      );

      // Renders heading and both group titles + subtitles
      expect(find.text('THE PARLOUR REMEMBERS'), findsOneWidget);
      expect(find.text('FOOLED'), findsOneWidget);
      expect(find.text('picked their lie as the truth'), findsOneWidget);
      expect(find.text('SPOTTED'), findsOneWidget);
      expect(find.text('named the liar on their own card'), findsOneWidget);

      // Fool row copy
      expect(find.text('Bob fooled Alice'), findsOneWidget);
      expect(find.text('×2'), findsOneWidget);

      // Spotted row copy - finds the top read line EXACTLY ONCE with CLOSEST badge
      expect(find.text("Alice spotted Bob's lie"), findsOneWidget);
      expect(find.text('CLOSEST'), findsOneWidget);

      // 3. When reads is empty: no CLOSEST badge
      final fixtureNoReads = {
        'fools': [
          {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'count': 1},
        ],
        'reads': <Map<String, dynamic>>[],
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParlourLedger(runningRivalries: fixtureNoReads),
          ),
        ),
      );
      expect(find.text('Bob fooled Alice'), findsOneWidget);
      expect(find.text('CLOSEST'), findsNothing);
      expect(find.text('SPOTTED'), findsNothing);
    });

    testWidgets('Validation 10: Expanding a row shows occurrence meta, prompt, lie; stays open on reorder', (WidgetTester tester) async {
      final pair1 = {
        'deceiverId': 'p2',
        'deceiverName': 'Bob',
        'victimId': 'p1',
        'victimName': 'Alice',
        'count': 2,
        'occurrences': [
          {
            'round': 1,
            'cardOwnerId': 'p3',
            'cardOwnerName': 'Charlie',
            'promptText': 'What happened at midnight?',
            'lieText': 'A clandestine meeting',
          },
        ],
      };
      final pair2 = {
        'deceiverId': 'p3',
        'deceiverName': 'Charlie',
        'victimId': 'p2',
        'victimName': 'Bob',
        'count': 1,
        'occurrences': [
          {
            'round': 2,
            'cardOwnerId': 'p1',
            'cardOwnerName': 'Alice',
            'promptText': 'Where is the silver key?',
            'lieText': 'Under the floorboards',
          },
        ],
      };

      Map<String, dynamic> rivalries = {
        'fools': [pair1, pair2],
        'reads': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: ParlourLedger(runningRivalries: rivalries),
                );
              },
            ),
          ),
        ),
      );

      // Initially collapsed
      expect(find.text("ROUND 1 · Charlie's card"), findsNothing);
      expect(find.text('What happened at midnight?'), findsNothing);
      expect(find.text('“A clandestine meeting”'), findsNothing);

      // Tap pair1 row (Bob fooled Alice)
      await tester.tap(find.byKey(const ValueKey('fools:p2:p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Expanded
      expect(find.text("ROUND 1 · Charlie's card"), findsOneWidget);
      expect(find.text('What happened at midnight?'), findsOneWidget);
      expect(find.text('“A clandestine meeting”'), findsOneWidget);

      // Reorder the list: pair2 is now first, pair1 is second
      rivalries = {
        'fools': [pair2, pair1],
        'reads': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: ParlourLedger(runningRivalries: rivalries),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The open row is still pair1 (Bob fooled Alice), NOT pair2!
      expect(find.text("ROUND 1 · Charlie's card"), findsOneWidget);
      expect(find.text('What happened at midnight?'), findsOneWidget);
      expect(find.text('“A clandestine meeting”'), findsOneWidget);
      // pair2 is still collapsed
      expect(find.text("ROUND 2 · Alice's card"), findsNothing);
      expect(find.text('“Under the floorboards”'), findsNothing);
    });

    testWidgets('Validation 11: Vote waiting screen at 320x568: no overflow with expanded row, and centered when empty', (WidgetTester tester) async {
      try {
        final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
        final p2 = PlayerState(id: 'p2', name: 'Bob');
        final p3 = PlayerState(id: 'p3', name: 'Charlie');

        final card = CardModel(
          targetPlayerId: 'p1',
          promptText: 'Grand question',
          truthAnswer: 'The truth',
        );

        final fullRivalries = {
          'fools': [
            {
              'deceiverId': 'p2',
              'deceiverName': 'Bartholomew Montgomery',
              'victimId': 'p1',
              'victimName': 'Archibald Constantine',
              'count': 3,
              'occurrences': [
                {
                  'round': 1,
                  'cardOwnerId': 'p3',
                  'cardOwnerName': 'Cordelia Ravenscroft',
                  'promptText': 'What was in the trunk?',
                  'lieText': 'An exquisite collection of forged letters',
                },
              ],
            },
            {
              'deceiverId': 'p3',
              'deceiverName': 'Cordelia Ravenscroft',
              'victimId': 'p2',
              'victimName': 'Bartholomew Montgomery',
              'count': 2,
            },
            {
              'deceiverId': 'p1',
              'deceiverName': 'Archibald Constantine',
              'victimId': 'p3',
              'victimName': 'Cordelia Ravenscroft',
              'count': 1,
            },
          ],
          'reads': [
            {
              'readerId': 'p1',
              'readerName': 'Archibald Constantine',
              'forgerId': 'p2',
              'forgerName': 'Bartholomew Montgomery',
              'count': 3,
            },
            {
              'readerId': 'p2',
              'readerName': 'Bartholomew Montgomery',
              'forgerId': 'p3',
              'forgerName': 'Cordelia Ravenscroft',
              'count': 2,
            },
            {
              'readerId': 'p3',
              'readerName': 'Cordelia Ravenscroft',
              'forgerId': 'p1',
              'forgerName': 'Archibald Constantine',
              'count': 1,
            },
          ],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.vote,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p2': true}, // p2 is ready (ballot sealed)
          resolutionOrder: ['p1'],
          runningRivalries: fullRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        for (final p in [p1, p2, p3]) {
          await mockDb.collection('rooms').doc('TEST').collection('players').doc(p.id).set(p.toMap()..['authUid'] = 'uid_${p.id}');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p2');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        // Strict 320 x 568 iPhone SE 1st gen size
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Phase3VoteScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('YOUR BALLOT IS SEALED'), findsOneWidget);
        expect(find.byKey(const ValueKey('parlour_ledger')), findsOneWidget);

        // Scroll until row is visible, then expand it
        await tester.scrollUntilVisible(find.byKey(const ValueKey('fools:p2:p1')), 100);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('fools:p2:p1')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Assert NO overflow exception!
        expect(tester.takeException(), isNull);
        expect(find.text('“An exquisite collection of forged letters”'), findsOneWidget);

        // Now test with ledger empty: YOUR BALLOT IS SEALED is still vertically centred
        final emptyState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.vote,
          totalPlayers: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p2': true},
          resolutionOrder: ['p1'],
          runningRivalries: null,
        );
        await mockDb.collection('rooms').doc('TEST').set(emptyState.toMap());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final ballotCenter = tester.getCenter(find.text('YOUR BALLOT IS SEALED'));
        // In a 568 pt height viewport with Column(mainAxisAlignment: center), the ballot text sits near the middle (~280 pt +/- 50 pt)
        expect(ballotCenter.dy, greaterThan(200));
        expect(ballotCenter.dy, lessThan(360));
      } finally {
        await gameService.leaveRoom();
      }
    });

    testWidgets('Validation 12: Craft waiting screen renders ParlourLedger below AA6 recap', (WidgetTester tester) async {
      final p1 = PlayerState(id: 'p1', name: 'Alice', isHost: true);
      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'Cult question',
        truthAnswer: 'The truth',
      );

      final rivalries = {
        'fools': [
          {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'count': 1},
        ],
        'reads': <Map<String, dynamic>>[],
      };

      final state = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.truth,
        totalPlayers: 2,
        isTimerDisabled: true,
        cards: [card],
        currentCardAssignments: {'p1': 'p1'},
        readyPlayers: {'p1': false},
        resolutionOrder: ['p1'],
        runningRivalries: rivalries,
      );

      final fakeFns = FakeFirebaseFunctions(mockDb);
      fakeFns.overrideCallable('submitAnswer', (params) async => {'success': true});
      final craftService = GameService(db: mockDb, functions: fakeFns);

      try {
        craftService.debugSetState(state, [p1], p1.id);

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: craftService,
            child: const MaterialApp(
              home: Phase2CraftScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Submit answer using answer_field to trigger recap
        final fieldFinder = find.byKey(const ValueKey('answer_field'));
        expect(fieldFinder, findsOneWidget);

        await tester.enterText(fieldFinder, 'My submitted secret answer');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Advance to waiting screen with recap
        final waitingState = state.copyWith(readyPlayers: {'p1': true});
        craftService.debugSetState(waitingState, [p1], p1.id);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify recap and ledger are both present
        final recapFinder = find.byKey(const ValueKey('submitted_answer_recap'));
        final ledgerFinder = find.byKey(const ValueKey('parlour_ledger'));
        expect(recapFinder, findsOneWidget);
        expect(ledgerFinder, findsOneWidget);

        // Ledger is positioned BELOW the recap
        final recapBottom = tester.getBottomLeft(recapFinder).dy;
        final ledgerTop = tester.getTopLeft(ledgerFinder).dy;
        expect(ledgerTop, greaterThanOrEqualTo(recapBottom));
      } finally {
        craftService.dispose();
      }
    });

    testWidgets('Validation 13: Reveal teaser timing, identity check, and match final card footer suppression', (WidgetTester tester) async {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        final localPlayer = PlayerState(id: 'p1', name: 'Alice', joinedAt: 100);
        final p2 = PlayerState(id: 'p2', name: 'Bob', joinedAt: 200);
        final p3 = PlayerState(id: 'p3', name: 'Charlie', joinedAt: 300);

        final card = CardModel(
          targetPlayerId: 'p1',
          promptText: 'What is the secret?',
          truthAnswer: 'The real secret',
          sabotageAnswers: {'p2': 'A fake secret'},
          votes: {'p1': 'p2', 'p2': 'p1', 'p3': 'p2'},
        );

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'count': 2},
          ],
          'reads': [
            {'readerId': 'p1', 'readerName': 'Alice', 'forgerId': 'p2', 'forgerName': 'Bob', 'count': 1},
          ],
          'thisCard': {
            'round': 1,
            'cardOwnerId': 'p1',
            'fools': [
              {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'total': 2},
            ],
            'reads': [
              {'readerId': 'p1', 'readerName': 'Alice', 'forgerId': 'p2', 'forgerName': 'Bob', 'total': 1},
            ],
          },
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentRound: 1,
          totalRounds: 3,
          currentReaderId: 'p1',
          cards: [card],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1', 'p2'],
          unmaskDeadline: now + 15000, // active unmask window
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(localPlayer.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p3').set(p3.toMap()..['authUid'] = 'uid3');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: Phase4RevealScreen(),
            ),
          ),
        );
        await tester.pump();

        // 1. Stage 3 (before flip, unmask window): NO teaser, NO Parlour Remembers
        await settleReveal(tester, 4000);
        expect(find.byKey(const ValueKey('rivalry_teaser')), findsNothing);
        expect(find.text('THE PARLOUR REMEMBERS'), findsNothing);

        // 2. Advance past flip to stage 4: teaser appears
        await settleReveal(tester, 14000);
        expect(find.byKey(const ValueKey('rivalry_teaser')), findsOneWidget);
        // THE PARLOUR REMEMBERS no longer appears on reveal
        expect(find.text('THE PARLOUR REMEMBERS'), findsNothing);

        // Teaser copy
        expect(find.text('Bob fooled Alice again'), findsOneWidget);
        expect(find.text("Alice spotted Bob's lie"), findsOneWidget);
        expect(find.text('The full ledger opens while you wait for the next card.'), findsOneWidget);

        // 3. Stale card identity check: if thisCard cardOwnerId does not match currentReaderId
        final staleRivalries = Map<String, dynamic>.from(runningRivalries);
        staleRivalries['thisCard'] = {
          'round': 1,
          'cardOwnerId': 'p2', // stale reader!
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'total': 2},
          ],
          'reads': [],
        };
        await mockDb.collection('rooms').doc('TEST').update({'runningRivalries': staleRivalries});
        await settleReveal(tester, 1000);
        expect(find.byKey(const ValueKey('rivalry_teaser')), findsNothing);

        // 4. Final card of match: currentRound == totalRounds and currentReaderId == resolutionOrder.last
        final finalCardState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentRound: 3,
          totalRounds: 3,
          currentReaderId: 'p2',
          cards: [card.copyWith(targetPlayerId: 'p2')],
          readyPlayers: {'p1': true, 'p2': true, 'p3': true},
          resolutionOrder: ['p1', 'p2'], // p2 is last!
          unmaskDeadline: 0, // already flipped
          runningRivalries: {
            'fools': [],
            'reads': [],
            'thisCard': {
              'round': 3,
              'cardOwnerId': 'p2',
              'fools': [
                {'deceiverId': 'p1', 'deceiverName': 'Alice', 'victimId': 'p3', 'victimName': 'Charlie', 'total': 1},
              ],
              'reads': [],
            },
          },
        );
        await mockDb.collection('rooms').doc('TEST').set(finalCardState.toMap());
        await settleReveal(tester, 4000);

        expect(find.byKey(const ValueKey('rivalry_teaser')), findsOneWidget);
        expect(find.text('Alice fooled Charlie'), findsOneWidget);
        // Footer MUST be omitted on final card!
        expect(find.text('The full ledger opens while you wait for the next card.'), findsNothing);
      } finally {
        await gameService.leaveRoom();
      }
    });

    testWidgets('Validation 14: Rendered contrast: every Text in expanded ParlourLedger and teaser has contrast >= 4.5:1', (WidgetTester tester) async {
      final fixture = {
        'fools': [
          {
            'deceiverId': 'p2',
            'deceiverName': 'Bob',
            'victimId': 'p1',
            'victimName': 'Alice',
            'count': 2,
            'occurrences': [
              {
                'round': 1,
                'cardOwnerId': 'p3',
                'cardOwnerName': 'Charlie',
                'promptText': 'Secret prompt text',
                'lieText': 'Bob deceptive lie',
              },
            ],
          },
        ],
        'reads': [
          {
            'readerId': 'p1',
            'readerName': 'Alice',
            'forgerId': 'p2',
            'forgerName': 'Bob',
            'count': 1,
            'occurrences': [
              {
                'round': 1,
                'cardOwnerId': 'p1',
                'cardOwnerName': 'Alice',
                'promptText': 'Alice own card prompt',
                'lieText': 'Bob caught forgery',
              },
            ],
          },
        ],
      };

      // 1. Check ParlourLedger
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.ground,
            body: Center(
              child: SingleChildScrollView(
                child: ParlourLedger(runningRivalries: fixture),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Expand both rows
      await tester.tap(find.byKey(const ValueKey('fools:p2:p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('reads:p1:p2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final ledgerFinder = find.byKey(const ValueKey('parlour_ledger'));
      expect(ledgerFinder, findsOneWidget);

      final ledgerTextElements = find.descendant(of: ledgerFinder, matching: find.byType(Text)).evaluate().toList();
      expect(ledgerTextElements.isNotEmpty, isTrue);

      for (final element in ledgerTextElements) {
        final text = element.widget as Text;
        final bg = _resolveBackgroundForElement(element);

        final List<(String, Color)> colors = [];
        if (text.style?.color != null) {
          colors.add((text.data ?? 'plain', text.style!.color!));
        }
        if (text.textSpan != null) {
          text.textSpan!.visitChildren((span) {
            if (span is TextSpan && span.style?.color != null) {
              colors.add((span.text ?? 'span', span.style!.color!));
            }
            return true;
          });
        }

        for (final entry in colors) {
          final label = entry.$1;
          final color = entry.$2;
          final fg = Color.alphaBlend(color, bg);
          final ratio = _getContrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'ParlourLedger text "$label" with color $color on background $bg must have contrast >= 4.5:1. Got $ratio',
          );
        }
      }

      // 2. Check Reveal Teaser
      final card = CardModel(
        targetPlayerId: 'p1',
        promptText: 'What is the secret?',
        truthAnswer: 'The real secret',
      );
      final teaserRivalries = {
        'fools': [],
        'reads': [],
        'thisCard': {
          'round': 1,
          'cardOwnerId': 'p1',
          'fools': [
            {'deceiverId': 'p2', 'deceiverName': 'Bob', 'victimId': 'p1', 'victimName': 'Alice', 'total': 2},
          ],
          'reads': [
            {'readerId': 'p1', 'readerName': 'Alice', 'forgerId': 'p2', 'forgerName': 'Bob', 'total': 1},
          ],
        },
      };

      final gameState = GameState(
        roomCode: 'TEST',
        currentPhase: GamePhase.reveal,
        totalPlayers: 2,
        currentRound: 1,
        totalRounds: 3,
        currentReaderId: 'p1',
        cards: [card],
        readyPlayers: {'p1': true, 'p2': true},
        resolutionOrder: ['p1', 'p2'],
        unmaskDeadline: 0, // flipped
        runningRivalries: teaserRivalries,
      );

      final p1 = PlayerState(id: 'p1', name: 'Alice');
      final p2 = PlayerState(id: 'p2', name: 'Bob');
      gameService.debugSetState(gameState, [p1, p2], 'p1');

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: const MaterialApp(
            home: Phase4RevealScreen(),
          ),
        ),
      );
      await settleReveal(tester, 4000);

      final teaserFinder = find.byKey(const ValueKey('rivalry_teaser'));
      expect(teaserFinder, findsOneWidget);

      final teaserTextElements = find.descendant(of: teaserFinder, matching: find.byType(Text)).evaluate().toList();
      expect(teaserTextElements.isNotEmpty, isTrue);

      for (final element in teaserTextElements) {
        final text = element.widget as Text;
        final bg = _resolveBackgroundForElement(element);

        final List<(String, Color)> colors = [];
        if (text.style?.color != null) {
          colors.add((text.data ?? 'plain', text.style!.color!));
        }
        if (text.textSpan != null) {
          text.textSpan!.visitChildren((span) {
            if (span is TextSpan && span.style?.color != null) {
              colors.add((span.text ?? 'span', span.style!.color!));
            }
            return true;
          });
        }

        for (final entry in colors) {
          final label = entry.$1;
          final color = entry.$2;
          final fg = Color.alphaBlend(color, bg);
          final ratio = _getContrastRatio(fg, bg);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'Teaser text "$label" with color $color on background $bg must have contrast >= 4.5:1. Got $ratio',
          );
        }
      }
    });

    testWidgets('Validation 15: Game over screen renders spotted copy', (WidgetTester tester) async {
      try {
        final p1 = PlayerState(id: 'p1', name: 'Alice', totalScore: 10, playersDeceived: 2, timesFooled: 1, role: PlayerRole.voter);
        final p2 = PlayerState(id: 'p2', name: 'Bob', totalScore: 8, playersDeceived: 1, timesFooled: 2, role: PlayerRole.voter);

        final summaryPayload = <String, dynamic>{
          'bestLie': null,
          'cleanestTruth': null,
          'theSting': null,
          'headToHead': [
            {'deceiverName': 'Alice', 'victimName': 'Bob', 'count': 2},
          ],
        };

        final runningRivalries = {
          'fools': [
            {'deceiverId': 'p1', 'deceiverName': 'Alice', 'victimId': 'p2', 'victimName': 'Bob', 'count': 2},
          ],
          'reads': [
            {'readerId': 'p2', 'readerName': 'Bob', 'forgerId': 'p1', 'forgerName': 'Alice', 'count': 1},
          ],
        };

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.gameOver,
          totalPlayers: 2,
          cards: [],
          currentCardAssignments: {},
          readyPlayers: {},
          matchSummary: summaryPayload,
          runningRivalries: runningRivalries,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p1').set(p1.toMap()..['authUid'] = 'uid1');
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('p2').set(p2.toMap()..['authUid'] = 'uid2');

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'p1');
        gameService.listenToRoom('TEST');
        await gameService.tryRejoinSession();

        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: GameOverScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));

        expect(find.text('RIVALRIES'), findsOneWidget);
        expect(find.text('Alice fooled Bob 2 times'), findsOneWidget);
        expect(find.text("Bob spotted Alice's lie ×1"), findsOneWidget);
      } finally {
        await gameService.leaveRoom();
      }
    });
  });
}
