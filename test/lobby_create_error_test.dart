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

  group('LobbyScreen create error mapping tests (Wave AG / AG1)', () {
    late FakeFirestore mockDb;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockDb = FakeFirestore();
    });

    Future<void> pumpLobbyWithFunctions(
      WidgetTester tester, {
      Object? createException,
      Object? joinException,
    }) async {
      final errorFunctions = ErrorFakeFirebaseFunctions(
        mockDb,
        createException: createException,
        joinException: joinException,
      );
      final errorGameService = GameService(db: mockDb, functions: errorFunctions);
      addTearDown(() => errorGameService.dispose());

      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('falsification: create throws unavailable displays mapped readable sentence and no raw exception/stack trace', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: FirebaseFunctionsException(
          code: 'unavailable',
          message: 'The service is unavailable (#0 _extractReplyValueOrThrow)',
        ),
      );

      // Enter name
      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      // Tap CREATE ROOM
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Assert SnackBar shows the mapped connection sentence
      expect(
        find.text('Could not reach the parlour. Check your connection and try again.'),
        findsOneWidget,
        reason: 'Should show mapped connection sentence for unavailable error',
      );

      // 2. Assert rendered text does not contain stack traces, pigeon, or raw exception tags
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').toList();
      final hasTraceOrRawError = allTextWidgets.any((text) =>
          text.contains('#0') ||
          text.contains('firebase_functions') ||
          text.contains('Exception') ||
          text.contains('pigeon') ||
          text.startsWith('Error: [') ||
          text.startsWith('Error: Instance of'));

      expect(
        hasTraceOrRawError,
        isFalse,
        reason: 'Rendered text must not contain stack traces or raw exception stringification',
      );
      expect(find.textContaining('#0'), findsNothing);
      expect(find.textContaining('firebase_functions'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
    });

    testWidgets('create throws invalid-argument maps to name prompt', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'Invalid arguments',
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Enter your name to open a room.'),
        findsOneWidget,
      );
    });

    testWidgets('create throws resource-exhausted maps to room code prompt', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'No available room codes',
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not find a free room code. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('create throws unauthenticated maps to sign in connection prompt', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'User is not authenticated',
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not sign in. Check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('create throws internal maps to generic sentence', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: FirebaseFunctionsException(
          code: 'internal',
          message: 'Internal server failure',
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Something went wrong. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('create throws plain Exception maps to generic sentence', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        createException: Exception('boom'),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.pump();

      await tester.tap(find.text('CREATE ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Something went wrong. Try again.'),
        findsOneWidget,
      );
    });

    testWidgets('join throws unavailable maps to connection sentence', (WidgetTester tester) async {
      await pumpLobbyWithFunctions(
        tester,
        joinException: FirebaseFunctionsException(
          code: 'unavailable',
          message: 'Network drop',
        ),
      );

      await tester.enterText(find.byKey(const ValueKey('player_name_field')), 'Alice');
      await tester.enterText(find.byKey(const ValueKey('room_code_field')), 'TEST');
      await tester.pump();

      await tester.tap(find.text('JOIN ROOM'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Could not reach the parlour. Check your connection and try again.'),
        findsOneWidget,
      );
    });

    test('lobbyCallableErrorMessage unit mapping completeness and symmetry', () {
      // create mapping checks
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'not-found', message: ''),
          action: LobbyAction.create,
        ),
        'Something went wrong. Try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'invalid-argument', message: ''),
          action: LobbyAction.create,
        ),
        'Enter your name to open a room.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'resource-exhausted', message: ''),
          action: LobbyAction.create,
        ),
        'Could not find a free room code. Try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'unauthenticated', message: ''),
          action: LobbyAction.create,
        ),
        'Could not sign in. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'unavailable', message: ''),
          action: LobbyAction.create,
        ),
        'Could not reach the parlour. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'deadline-exceeded', message: ''),
          action: LobbyAction.create,
        ),
        'Could not reach the parlour. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'internal', message: ''),
          action: LobbyAction.create,
        ),
        'Something went wrong. Try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          Exception('custom'),
          action: LobbyAction.create,
        ),
        'Something went wrong. Try again.',
      );

      // join mapping checks
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'not-found', message: ''),
          action: LobbyAction.join,
        ),
        'No room with that code. Check the four letters and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'invalid-argument', message: ''),
          action: LobbyAction.join,
        ),
        'Enter your name and a four-letter room code.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'resource-exhausted', message: ''),
          action: LobbyAction.join,
        ),
        'Something went wrong. Try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'unauthenticated', message: ''),
          action: LobbyAction.join,
        ),
        'Could not sign in. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'unavailable', message: ''),
          action: LobbyAction.join,
        ),
        'Could not reach the parlour. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'deadline-exceeded', message: ''),
          action: LobbyAction.join,
        ),
        'Could not reach the parlour. Check your connection and try again.',
      );
      expect(
        lobbyCallableErrorMessage(
          FirebaseFunctionsException(code: 'internal', message: ''),
          action: LobbyAction.join,
        ),
        'Something went wrong. Try again.',
      );
    });
  });
}

class ErrorFakeFirebaseFunctions extends FakeFirebaseFunctions {
  final Object? createException;
  final Object? joinException;
  ErrorFakeFirebaseFunctions(super.db, {this.createException, this.joinException});

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    if (name == 'createRoom' && createException != null) {
      return ErrorFakeHttpsCallable(createException!);
    }
    if (name == 'joinRoom' && joinException != null) {
      return ErrorFakeHttpsCallable(joinException!);
    }
    return super.httpsCallable(name, options: options);
  }
}

class ErrorFakeHttpsCallable extends FakeHttpsCallable {
  final Object exception;
  ErrorFakeHttpsCallable(this.exception) : super(FakeFirestore(), 'errorCallable');

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    throw exception;
  }
}
