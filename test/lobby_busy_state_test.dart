import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:gaslight/widgets/shared_ui.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LobbyScreen busy state tests (Issue 95 / Y3)', () {
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

    Future<void> pumpLobbyScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: gameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: const Scaffold(body: LobbyScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('falsification: CREATE ROOM shows loading state and disables onPressed during in-flight callable', (WidgetTester tester) async {
      /*
       * Falsification run against unmodified lobby_screen.dart:
       * Observed failure on pre-Y3 code:
       *   Expected: PrimaryButton with loading: true and onPressed: null while callable is in-flight
       *   Actual: PrimaryButton loading was false, and onPressed was non-null (_createRoom)
       */
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeFunctions.createRoomCompleter = Completer<void>();

      await pumpLobbyScreen(tester);

      // Enter player name
      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Host Alice');
      await tester.pump();

      // Tap CREATE ROOM
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();

      // Find PrimaryButton for CREATE ROOM
      final createButtonFinder = find.byType(PrimaryButton);
      expect(createButtonFinder, findsOneWidget);
      final inFlightButton = tester.widget<PrimaryButton>(createButtonFinder);

      // Assert loading is true and onPressed is null during in-flight request
      expect(inFlightButton.loading, isTrue, reason: 'PrimaryButton should report loading == true while in flight');
      expect(inFlightButton.onPressed, isNull, reason: 'PrimaryButton onPressed should be disabled (null) while in flight');

      // Complete the in-flight callable
      fakeFunctions.createRoomCompleter!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After completion / navigation or settled state
      expect(fakeFunctions.createRoomCallCount, 1);
      await gameService.leaveRoom();
    });

    testWidgets('over-reach guard 1: second tap during in-flight window does NOT issue a second createRoom call (idempotency)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeFunctions.createRoomCompleter = Completer<void>();

      await pumpLobbyScreen(tester);

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Host Alice');
      await tester.pump();

      // First tap
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();

      expect(fakeFunctions.createRoomCallCount, 1);

      // Second tap while still in-flight
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();

      // Invocations MUST strictly remain 1
      expect(fakeFunctions.createRoomCallCount, 1, reason: 'Second tap while in flight must not issue a second createRoom call');

      // Complete the callable
      fakeFunctions.createRoomCompleter!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await gameService.leaveRoom();
    });

    testWidgets('over-reach guard 2: button is re-enabled after callable exception (finally guard)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final errorCompleter = Completer<void>();
      final errorFunctions = ErrorFakeFirebaseFunctions(
        mockDb,
        createException: FirebaseFunctionsException(
          code: 'internal',
          message: 'Server error',
        ),
        createCompleter: errorCompleter,
      );
      final errorGameService = GameService(db: mockDb, functions: errorFunctions);

      await tester.pumpWidget(
        ChangeNotifierProvider<GameService>.value(
          value: errorGameService,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(accessibleNavigation: true),
              child: const Scaffold(body: LobbyScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Host Alice');
      await tester.pump();

      // Tap CREATE ROOM
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();

      // While in flight
      final inFlightFinder = find.byType(PrimaryButton);
      expect(tester.widget<PrimaryButton>(inFlightFinder).loading, isTrue);

      // Throw exception
      errorCompleter.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Button must be re-enabled after error
      final settledFinder = find.widgetWithText(PrimaryButton, 'CREATE ROOM');
      expect(settledFinder, findsOneWidget);
      final settledButton = tester.widget<PrimaryButton>(settledFinder);
      expect(settledButton.loading, isFalse, reason: 'Button must not be loading after error');
      expect(settledButton.onPressed, isNotNull, reason: 'Button must be re-enabled after error');

      errorGameService.dispose();
    });

    testWidgets('over-reach guard 3: JOIN ROOM shows busy state and guards against duplicate in-flight taps', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      fakeFunctions.joinRoomCompleter = Completer<void>();

      await pumpLobbyScreen(tester);

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Guest Bob');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'TEST');
      await tester.pump();

      // Tap JOIN ROOM
      await tester.tap(find.widgetWithText(ElevatedButton, 'JOIN ROOM'));
      await tester.pump();

      expect(fakeFunctions.joinRoomCallCount, 1);

      // In flight, the button renders CircularProgressIndicator and its onPressed is null
      final inFlightJoinFinder = find.ancestor(
        of: find.byType(CircularProgressIndicator),
        matching: find.byType(ElevatedButton),
      );
      expect(inFlightJoinFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(inFlightJoinFinder).onPressed, isNull);

      // Second tap while still in-flight
      await tester.tap(inFlightJoinFinder, warnIfMissed: false);
      await tester.pump();

      expect(fakeFunctions.joinRoomCallCount, 1, reason: 'Duplicate tap while join is in flight must be ignored');

      fakeFunctions.joinRoomCompleter!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await gameService.leaveRoom();
    });
  });
}

class ErrorFakeFirebaseFunctions extends FakeFirebaseFunctions {
  final FirebaseFunctionsException? createException;
  final Completer<void>? createCompleter;
  ErrorFakeFirebaseFunctions(super.db, {this.createException, this.createCompleter});

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    if (name == 'createRoom' && createException != null) {
      return ErrorFakeHttpsCallable(createException!, completer: createCompleter);
    }
    return super.httpsCallable(name, options: options);
  }
}

class ErrorFakeHttpsCallable extends FakeHttpsCallable {
  final FirebaseFunctionsException exception;
  final Completer<void>? completer;
  ErrorFakeHttpsCallable(this.exception, {this.completer}) : super(FakeFirestore(), 'errorCallable');

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    if (completer != null) {
      await completer!.future;
    }
    throw exception;
  }
}
