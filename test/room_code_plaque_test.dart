import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/room_code_plaque.dart';
import 'package:gaslight/theme/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RoomCodePlaque copy-to-clipboard, share icon, and typography styles', (WidgetTester tester) async {
    final List<MethodCall> log = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'Clipboard.setData') {
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoomCodePlaque(code: 'ABCD'),
        ),
      ),
    );

    // Verify typography styles
    final codeText = tester.widget<Text>(find.text('ABCD'));
    expect(codeText.style?.fontFamily, 'CormorantGaramond');
    expect(codeText.style?.fontWeight, FontWeight.w900);
    expect(codeText.style?.fontSize, 40);

    // Verify envelope share icon is present
    expect(find.byType(ThematicIcon), findsOneWidget);
    final thematicIcon = tester.widget<ThematicIcon>(find.byType(ThematicIcon));
    expect(thematicIcon.type, ThematicIconType.envelope);

    // Tap plaque to copy to clipboard
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Verify clipboard was set
    expect(log.any((call) => call.method == 'Clipboard.setData'), isTrue);
    final clipCall = log.firstWhere((call) => call.method == 'Clipboard.setData');
    expect(clipCall.arguments['text'], 'ABCD');

    // Verify SnackBar appeared
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Code ABCD copied — summon your suspects.'), findsOneWidget);
  });
}
