import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/main.dart';
import 'package:gaslight/services/game_service.dart';
import 'package:gaslight/widgets/confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fake_functions.dart';
import 'simulation_test.dart';
import 'helpers/png_decoder.dart';
import 'helpers/rendered_contrast.dart';

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

  /// Pumps the real GaslightApp (production theme) at 375 x 667 inside a root
  /// RepaintBoundary, so rendered pixels can be measured (Issue 181 / AI4).
  Future<GlobalKey> pumpRealApp(WidgetTester tester, GameService gameService) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final rootBoundary = GlobalKey(debugLabel: 'rootBoundary');
    await tester.pumpWidget(
      ChangeNotifierProvider<GameService>.value(
        value: gameService,
        child: RepaintBoundary(key: rootBoundary, child: const GaslightApp()),
      ),
    );
    await tester.pumpAndSettle();
    return rootBoundary;
  }

  testWidgets('GaslightConfirmDialog: title, body and both action labels clear the contrast floors as rendered (Issue 181)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDb = FakeFirestore();
    final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    try {
      final rootBoundary = await pumpRealApp(tester, gameService);

      showDialog<void>(
        context: tester.element(find.byType(Navigator)),
        builder: (_) => GaslightConfirmDialog(
          title: 'Remove player?',
          body: 'Remove Bob from this room? They can rejoin with the room code.',
          cancelLabel: 'CANCEL',
          confirmLabel: 'REMOVE',
          onConfirm: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      // Measured from pixels, never the widget-tree walk: unstyled TextButtons took
      // colorScheme.primary (oxblood) from the theme, which the walk cannot see.
      Finder label(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text));
      final title = await measureRenderedContrast(tester, rootBoundary, find.text('Remove player?'));
      final body = await measureRenderedContrast(
          tester, rootBoundary, find.text('Remove Bob from this room? They can rejoin with the room code.'));
      final cancel = await measureRenderedContrast(tester, rootBoundary, label('confirm_dialog_cancel'));
      final confirm = await measureRenderedContrast(tester, rootBoundary, label('confirm_dialog_confirm'));

      debugPrint('GaslightConfirmDialog rendered contrast: title ${title.ratio.toStringAsFixed(2)}, '
          'body ${body.ratio.toStringAsFixed(2)}, cancel ${cancel.ratio.toStringAsFixed(2)}, '
          'confirm ${confirm.ratio.toStringAsFixed(2)}');
      expect(title.ratio, greaterThanOrEqualTo(3.0), reason: 'dialog title (large text, 3.0 : 1 floor) was ${title.ratio}');
      expect(body.ratio, greaterThanOrEqualTo(4.5), reason: 'dialog body was ${body.ratio}');
      expect(cancel.ratio, greaterThanOrEqualTo(4.5), reason: 'cancel label was ${cancel.ratio}');
      expect(confirm.ratio, greaterThanOrEqualTo(4.5),
          reason: 'confirm label was ${confirm.ratio} (oxblood on groundRaised measured 1.78 : 1)');
    } finally {
      gameService.dispose();
    }
  });

  testWidgets('entry-screen headings THE GUEST LEDGER and Select Character Token clear 4.5 : 1 as rendered (Issue 181)', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockDb = FakeFirestore();
    final gameService = GameService(db: mockDb, functions: FakeFirebaseFunctions(mockDb));
    try {
      final rootBoundary = await pumpRealApp(tester, gameService);

      for (final heading in ['THE GUEST LEDGER', 'Select Character Token']) {
        final sample = await measureRenderedContrast(tester, rootBoundary, find.text(heading));
        expect(sample.ratio, greaterThanOrEqualTo(4.5),
            reason: '"$heading" measured ${sample.ratio.toStringAsFixed(2)} : 1 '
                '(${sample.foreground} on ${sample.background}); oxblood measured 1.78 : 1');
      }
    } finally {
      gameService.dispose();
    }
  });
}
