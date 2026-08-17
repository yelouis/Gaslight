import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/screens/lobby_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LobbyScreen join error mapping tests (Issue 93 / Y2)', () {
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

    testWidgets('falsification: join non-existent room displays mapped readable sentence and no raw exception/stack trace', (WidgetTester tester) async {
      /*
       * Falsification run against unmodified lobby_screen.dart:206 (Text('Error: $e')):
       * Observed failure on pre-Y2 code:
       *   Expected: exactly one matching candidate with text "No room with that code. Check the four letters and try again."
       *     Actual: Found 0 matching candidates (displayed "Error: [firebase_functions/not-found] Game room not found.")
       */
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await pumpLobbyScreen(tester);

      // Enter name and room code
      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'NONO');
      await tester.pump();

      // Tap JOIN ROOM
      await tester.tap(find.text('JOIN ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Assert SnackBar shows the mapped sentence
      expect(
        find.text('No room with that code. Check the four letters and try again.'),
        findsOneWidget,
        reason: 'Should show mapped sentence for not-found error',
      );

      // 2. Assert rendered text does not contain pigeon or #0 or raw exception tags
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      final hasTraceOrRawError = allTextWidgets.any((text) =>
          text.contains('pigeon') ||
          text.contains('#0') ||
          text.contains('firebase_functions') ||
          text.startsWith('Error: ['));

      expect(
        hasTraceOrRawError,
        isFalse,
        reason: 'Rendered text must not contain stack traces or raw exception stringification',
      );
    });

    testWidgets('over-reach guard 1: invalid-argument code maps to name and room code prompt', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final errorFunctions = ErrorFakeFirebaseFunctions(
        mockDb,
        joinException: FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Invalid arguments',
        ),
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

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'TEST');
      await tester.pump();

      await tester.tap(find.text('JOIN ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Enter your name and a four-letter room code.'),
        findsOneWidget,
      );

      errorGameService.dispose();
    });

    testWidgets('over-reach guard 2: unauthenticated code maps to connection prompt', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final errorFunctions = ErrorFakeFirebaseFunctions(
        mockDb,
        joinException: FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        ),
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

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'TEST');
      await tester.pump();

      await tester.tap(find.text('JOIN ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not sign in. Check your connection and try again.'),
        findsOneWidget,
      );

      errorGameService.dispose();
    });

    testWidgets('over-reach guard 3: unmapped code (internal) produces generic message', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final errorFunctions = ErrorFakeFirebaseFunctions(
        mockDb,
        joinException: FirebaseFunctionsException(
          code: 'internal',
          message: 'Internal server failure',
        ),
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

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'TEST');
      await tester.pump();

      await tester.tap(find.text('JOIN ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Something went wrong. Try again.'),
        findsOneWidget,
      );

      final allTextWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      final hasTraceOrRawError = allTextWidgets.any((text) =>
          text.contains('pigeon') ||
          text.contains('#0') ||
          text.contains('firebase_functions') ||
          text.startsWith('Error: ['));

      expect(hasTraceOrRawError, isFalse);

      errorGameService.dispose();
    });
  });
}

class ErrorFakeFirebaseFunctions extends FakeFirebaseFunctions {
  final FirebaseFunctionsException? joinException;
  ErrorFakeFirebaseFunctions(super.db, {this.joinException});

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    if (name == 'joinRoom' && joinException != null) {
      return ErrorFakeHttpsCallable(joinException!);
    }
    return super.httpsCallable(name, options: options);
  }
}

class ErrorFakeHttpsCallable extends FakeHttpsCallable {
  final FirebaseFunctionsException exception;
  ErrorFakeHttpsCallable(this.exception) : super(FakeFirestore(), 'errorCallable');

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    throw exception;
  }
}
