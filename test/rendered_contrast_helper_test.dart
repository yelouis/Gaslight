import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'helpers/rendered_contrast.dart';

/// The pixel-contrast helper is what every rendered-contrast test stands on, so
/// it gets its own falsification: it must never pass vacuously (lesson 2.21),
/// and it must reproduce the palette's known ratios.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GlobalKey> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final key = GlobalKey(debugLabel: 'rootBoundary');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(key: key, child: Align(alignment: Alignment.topLeft, child: child)),
      ),
    );
    await tester.pump();
    return key;
  }

  testWidgets('a single-colour region fails with "measured nothing" instead of passing', (tester) async {
    final key = await pump(
      tester,
      Container(key: const ValueKey('flat'), width: 100, height: 40, color: const Color(0xFF123456)),
    );

    await expectLater(
      measureRenderedContrast(tester, key, find.byKey(const ValueKey('flat'))),
      throwsA(isA<TestFailure>().having((e) => e.message, 'message', contains('measured nothing'))),
    );
  });

  testWidgets('a target with no area on screen fails with "measured nothing"', (tester) async {
    final key = await pump(tester, const SizedBox(key: ValueKey('empty'), width: 0, height: 0));

    await expectLater(
      measureRenderedContrast(tester, key, find.byKey(const ValueKey('empty')), inflate: 0),
      throwsA(isA<TestFailure>().having((e) => e.message, 'message', contains('measured nothing'))),
    );
  });

  testWidgets('black on white measures 21 : 1, whichever colour covers more of the rect', (tester) async {
    Widget box({required Color fill, required Color mark}) => Container(
          key: const ValueKey('target'),
          width: 100,
          height: 40,
          color: fill,
          alignment: Alignment.center,
          child: Container(width: 40, height: 16, color: mark),
        );

    var key = await pump(tester, box(fill: const Color(0xFF000000), mark: const Color(0xFFFFFFFF)));
    var sample = await measureRenderedContrast(tester, key, find.byKey(const ValueKey('target')), inflate: 0);
    expect(sample.ratio, closeTo(21.0, 0.01));
    expect(sample.background, const Color(0xFF000000), reason: 'the larger region is the background');
    expect(sample.foreground, const Color(0xFFFFFFFF));
    expect(sample.foregroundPixels, 40 * 16);

    // Same two colours, roles swapped: the ratio is symmetric.
    key = await pump(tester, box(fill: const Color(0xFFFFFFFF), mark: const Color(0xFF000000)));
    sample = await measureRenderedContrast(tester, key, find.byKey(const ValueKey('target')), inflate: 0);
    expect(sample.ratio, closeTo(21.0, 0.01));
    expect(sample.background, const Color(0xFFFFFFFF));
  });

  testWidgets('ink on parchment reproduces the palette ratio the guide cites (13.59 : 1)', (tester) async {
    final key = await pump(
      tester,
      Container(
        key: const ValueKey('target'),
        width: 100,
        height: 40,
        color: AppColors.parchment,
        alignment: Alignment.center,
        child: Container(width: 40, height: 16, color: AppColors.ink),
      ),
    );

    final sample = await measureRenderedContrast(tester, key, find.byKey(const ValueKey('target')), inflate: 0);

    expect(sample.ratio, closeTo(13.59, 0.02));
  });

  testWidgets('with several colours present, the foreground is the one furthest in luminance from the background', (tester) async {
    // Parchment fill with a faint ivory mark AND a strong ink mark, both well over
    // the pixel floor. The rule is "largest luminance delta", so the ink wins and
    // the faint mark cannot be mistaken for the foreground.
    final key = await pump(
      tester,
      Container(
        key: const ValueKey('target'),
        width: 100,
        height: 40,
        color: AppColors.parchment,
        child: Row(
          children: [
            Container(width: 40, height: 16, color: AppColors.ivory),
            const SizedBox(width: 10),
            Container(width: 20, height: 16, color: AppColors.ink),
          ],
        ),
      ),
    );

    final sample = await measureRenderedContrast(tester, key, find.byKey(const ValueKey('target')), inflate: 0);

    expect(sample.foreground, AppColors.ink);
    expect(sample.foregroundPixels, 20 * 16);
    expect(sample.ratio, closeTo(13.59, 0.02));
  });

  testWidgets('ivory on parchment reproduces Issue 179 (1.02 : 1)', (tester) async {
    final key = await pump(
      tester,
      Container(
        key: const ValueKey('target'),
        width: 100,
        height: 40,
        color: AppColors.parchment,
        alignment: Alignment.center,
        child: Container(width: 40, height: 16, color: AppColors.ivory),
      ),
    );

    final sample = await measureRenderedContrast(tester, key, find.byKey(const ValueKey('target')), inflate: 0);

    expect(sample.ratio, closeTo(1.02, 0.01));
  });
}
