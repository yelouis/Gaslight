import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lobby Entry Form Viewport Fits Tests', () {
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

    Future<void> setupAndPumpEntryForm(WidgetTester tester, {double textScale = 1.0}) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                accessibleNavigation: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: const LobbyScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('entry form fits 360x640 portrait without scrolling', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await setupAndPumpEntryForm(tester);

      // FALSIFYING ASSERTION — maxScrollExtent must be 0.0
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      expect(scrollable.controller?.position.maxScrollExtent ?? 0.0, 0.0);

      // Prove the point of the exercise: the below-the-fold controls are on screen.
      expect(find.text('JOIN ROOM'), findsOneWidget);
      expect(tester.getBottomRight(find.text('JOIN ROOM')).dy, lessThanOrEqualTo(640.0));

      expect(tester.takeException(), isNull);
    });

    testWidgets('entry form survives text scale 1.3 without overflow exceptions', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await setupAndPumpEntryForm(tester, textScale: 1.3);

      expect(find.text('JOIN ROOM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
