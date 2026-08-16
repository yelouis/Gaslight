import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';
import 'helpers/png_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('default AlertDialog theme satisfies WCAG contrast floors on title and content', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDb = FakeFirestore();
    final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));

    await tester.pumpWidget(
      ChangeNotifierProvider<GameService>.value(
        value: gameService,
        child: const MediaQuery(
          data: MediaQueryData(accessibleNavigation: true),
          child: GaslightApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext navigatorContext = tester.element(find.byType(Navigator));
    showDialog(
      context: navigatorContext,
      builder: (context) {
        return const AlertDialog(
          title: Text('End Voting?'),
          content: Text('End voting now? Players who have not voted will score nothing on this card, and their vote cannot be cast later.'),
        );
      },
    );
    await tester.pumpAndSettle();

    final titleFinder = find.text('End Voting?');
    final contentFinder = find.byWidgetPredicate((w) => w is Text && (w.data?.startsWith('End voting') ?? false));

    final theme = Theme.of(tester.element(titleFinder));
    final Color bgColor = theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    final titleWidget = tester.widget<Text>(titleFinder);
    final titleStyle = DefaultTextStyle.of(tester.element(titleFinder)).style.merge(titleWidget.style);
    final Color titleColor = titleStyle.color!;

    final contentWidget = tester.widget<Text>(contentFinder);
    final contentStyle = DefaultTextStyle.of(tester.element(contentFinder)).style.merge(contentWidget.style);
    final Color contentColor = contentStyle.color!;

    final double bgLum = relativeLuminance(
      (bgColor.r * 255.0).round().clamp(0, 255),
      (bgColor.g * 255.0).round().clamp(0, 255),
      (bgColor.b * 255.0).round().clamp(0, 255),
    );
    final double contentLum = relativeLuminance(
      (contentColor.r * 255.0).round().clamp(0, 255),
      (contentColor.g * 255.0).round().clamp(0, 255),
      (contentColor.b * 255.0).round().clamp(0, 255),
    );
    final double titleLum = relativeLuminance(
      (titleColor.r * 255.0).round().clamp(0, 255),
      (titleColor.g * 255.0).round().clamp(0, 255),
      (titleColor.b * 255.0).round().clamp(0, 255),
    );

    final double contentContrast = contrastRatio(contentLum, bgLum);
    final double titleContrast = contrastRatio(titleLum, bgLum);

    // Output measured ratios for logging
    debugPrint('Measured dialog content contrast: $contentContrast (needs >= 4.5)');
    debugPrint('Measured dialog title contrast: $titleContrast (needs >= 3.0)');

    expect(contentContrast, greaterThanOrEqualTo(4.5),
        reason: 'Dialog content text on dialog background must meet WCAG AA (4.5:1). Got $contentContrast');
    expect(titleContrast, greaterThanOrEqualTo(3.0),
        reason: 'Dialog title text on dialog background must meet WCAG AA large text (3.0:1). Got $titleContrast');
  });
}
