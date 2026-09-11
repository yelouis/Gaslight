import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/models/game_state.dart';
import 'package:gaslight/models/player_state.dart';
import 'package:gaslight/models/card_model.dart';
import 'package:gaslight/screens/phase4_reveal.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AA11 (Issue 169): Phase 4 Reveal Itemised Breakdown Rendering', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    });

    Future<void> settleReveal(WidgetTester tester, int millis) async {
      final end = DateTime.now().millisecondsSinceEpoch + millis;
      while (DateTime.now().millisecondsSinceEpoch < end) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('renders named lines per rule and preserves visible totals for each player', (WidgetTester tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      try {
        final localPlayer = PlayerState(id: 'local_player_id', name: 'Alice', joinedAt: 100);
        final guest1Player = PlayerState(id: 'guest_1', name: 'Bob', joinedAt: 200);
        final guest2Player = PlayerState(id: 'guest_2', name: 'Charlie', joinedAt: 300);

        final card = CardModel(
          targetPlayerId: 'guest_2',
          promptText: 'Whose secret is this?',
          truthAnswer: 'I love cats',
          sabotageAnswers: {'guest_1': 'I love dogs'},
          votes: {'local_player_id': 'guest_1', 'guest_1': 'guest_2'},
          scoreDeltas: {
            'local_player_id': -1,
            'guest_1': 3,
            'guest_2': 6,
          },
          scoreBreakdown: {
            'guest_1': const [
              ScoreBreakdownItem(rule: 'truth_found', points: 2),
              ScoreBreakdownItem(rule: 'sharp_eye', points: 1),
            ],
            'local_player_id': const [
              ScoreBreakdownItem(rule: 'revenge_guess', points: -1),
            ],
            'guest_2': const [
              ScoreBreakdownItem(rule: 'believable_target', points: 2),
              ScoreBreakdownItem(rule: 'round_multiplier', points: 4),
            ],
          },
        );

        final gameState = GameState(
          roomCode: 'TEST',
          currentPhase: GamePhase.reveal,
          totalPlayers: 3,
          currentReaderId: 'guest_2',
          cards: [card],
          readyPlayers: {'local_player_id': true, 'guest_1': true, 'guest_2': true},
          resolutionOrder: ['guest_2'],
          unmaskDeadline: 0,
        );

        await mockDb.collection('rooms').doc('TEST').set(gameState.toMap());
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('local_player_id').set(
          localPlayer.toMap()..['authUid'] = 'local_auth_uid',
        );
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_1').set(
          guest1Player.toMap()..['authUid'] = 'guest_1_auth_uid',
        );
        await mockDb.collection('rooms').doc('TEST').collection('players').doc('guest_2').set(
          guest2Player.toMap()..['authUid'] = 'guest_2_auth_uid',
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('room_code', 'TEST');
        await prefs.setString('player_id', 'local_player_id');
        await gameService.tryRejoinSession();
        gameService.listenToRoom('TEST');
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        tester.view.physicalSize = const Size(1200, 2000);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ChangeNotifierProvider<GameService>.value(
            value: gameService,
            child: const MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(accessibleNavigation: true),
                child: Phase4RevealScreen(),
              ),
            ),
          ),
        );

        await settleReveal(tester, 10000);

        // Assert player totals remain strictly visible
        expect(find.text('Bob: +3'), findsOneWidget);
        expect(find.text('Alice: -1'), findsOneWidget);
        expect(find.text('Charlie: +6'), findsOneWidget);

        // Assert named lines per rule are rendered
        expect(find.text('Truth Found: +2'), findsOneWidget);
        expect(find.text('Sharp Eye: +1'), findsOneWidget);
        expect(find.text('Revenge Guess: -1'), findsOneWidget);
        expect(find.text('Believable Target: +2'), findsOneWidget);
        expect(find.text('Round Multiplier: +4'), findsOneWidget);
      } finally {
        gameService.dispose();
      }
    });
  });
}
