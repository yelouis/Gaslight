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

  group('LobbyScreen room code input hardening (AA7 / Issue 153)', () {
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
      tester.view.physicalSize = const Size(800, 1000);
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
              data: const MediaQueryData(accessibleNavigation: true),
              child: const Scaffold(body: LobbyScreen()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Test 1: autocorrect and enableSuggestions on room code TextField are both false', (WidgetTester tester) async {
      await pumpLobbyScreen(tester);

      final textFieldFinder = find.byKey(const ValueKey('room_code_field'));
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.autocorrect, isFalse, reason: 'autocorrect must be false to prevent OS misspelling suggestions');
      expect(textField.enableSuggestions, isFalse, reason: 'enableSuggestions must be false for room codes');
      expect(textField.keyboardType, TextInputType.text);
      expect(textField.inputFormatters, isNotNull);
      expect(textField.inputFormatters!.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Test 2: entering ab1c!d leaves controller holding ABCD', (WidgetTester tester) async {
      await pumpLobbyScreen(tester);

      final textFieldFinder = find.byKey(const ValueKey('room_code_field'));
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, 'ab1c!d');
      await tester.pump();

      final editableText = tester.widget<EditableText>(
        find.descendant(of: textFieldFinder, matching: find.byType(EditableText)),
      );
      expect(editableText.controller.text, 'ABCD');
    });

    testWidgets('Test 3: type into the middle of an existing value and assert the caret does not jump', (WidgetTester tester) async {
      await pumpLobbyScreen(tester);

      final textFieldFinder = find.byKey(const ValueKey('room_code_field'));
      expect(textFieldFinder, findsOneWidget);

      // Enter initial text "AC"
      await tester.enterText(textFieldFinder, 'AC');
      await tester.pump();

      final editableFinder = find.descendant(of: textFieldFinder, matching: find.byType(EditableText));
      var editableText = tester.widget<EditableText>(editableFinder);
      expect(editableText.controller.text, 'AC');

      // Move caret to offset 1 (between A and C)
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'AC',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      // Type 'b' into middle: text becomes 'AbC', caret is at offset 2
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'AbC',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      editableText = tester.widget<EditableText>(editableFinder);
      expect(editableText.controller.text, 'ABC');
      expect(editableText.controller.selection.baseOffset, 2, reason: 'Caret must stay at offset 2 and not jump to 0');
      expect(editableText.controller.selection.extentOffset, 2);
    });

    test('UpperCaseTextFormatter unit test: preserves selection when capitalizing', () {
      const formatter = UpperCaseTextFormatter();
      const oldValue = TextEditingValue(
        text: 'AC',
        selection: TextSelection.collapsed(offset: 1),
      );
      const newValue = TextEditingValue(
        text: 'AbC',
        selection: TextSelection.collapsed(offset: 2),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, 'ABC');
      expect(result.selection.baseOffset, 2);
      expect(result.selection.extentOffset, 2);
    });
  });
}
