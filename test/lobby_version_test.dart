import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lobby Title Screen Version Display Tests (Wave Y1, Issue 151)', () {
    late FakeFirestore mockDb;
    late GameService gameService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
      gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
      appVersionDisplay = '';
    });

    tearDown(() {
      gameService.dispose();
      appVersionDisplay = '';
    });

    Future<void> setupAndPumpLobby(
      WidgetTester tester, {
      double textScale = 1.0,
      Size size = const Size(390, 844),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      // First pump - no gesture, no tap, no scroll, no long press
      await tester.pump();
    }

    testWidgets('falsifying: entry screen displays runtime bundle version in vX.Y.Z (B) format on first pump without gestures', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Gaslight',
        packageName: 'com.whylabs.gaslight',
        version: '9.9.9',
        buildNumber: '42',
        buildSignature: '',
      );
      await initAppVersion();
      expect(appVersionDisplay, 'v9.9.9 (42)');

      await setupAndPumpLobby(tester);

      // Over-reach guard 1: plain readable text found on first pump with zero gestures
      expect(find.text('v9.9.9 (42)'), findsOneWidget);
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);
      expect(find.text('READ MANUAL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('over-reach guard: entry screen renders all controls at 320x568 with textScale 2.0 without overflow', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'Gaslight',
        packageName: 'com.whylabs.gaslight',
        version: '1.0.0',
        buildNumber: '6',
        buildSignature: '',
      );
      await initAppVersion();

      await setupAndPumpLobby(tester, textScale: 2.0, size: const Size(320, 568));

      // Core actions still present and rendering
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);
      expect(find.text('READ MANUAL'), findsOneWidget);
      expect(find.text('v1.0.0 (6)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('graceful fallback: empty version string renders no line and app starts cleanly', (tester) async {
      // Simulate failed PackageInfo resolution
      appVersionDisplay = '';

      await setupAndPumpLobby(tester);

      // App starts and renders guest ledger panel completely
      expect(find.text('THE GUEST LEDGER'), findsOneWidget);
      expect(find.text('CREATE ROOM'), findsOneWidget);
      expect(find.text('JOIN ROOM'), findsOneWidget);
      expect(find.text('READ MANUAL'), findsOneWidget);
      // No version label rendered
      expect(find.textContaining('v'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
