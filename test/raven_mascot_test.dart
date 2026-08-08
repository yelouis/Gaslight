import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/raven_mascot.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'helpers/png_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task T3 & T5 — Raven Mascot Asset & Contrast Integrity (PNG Decoded)', () {
    final assets = ['body.png', 'wing.png', 'eye_open.png', 'eye_closed.png', 'beak_open.png', 'wing_up.png'];

    test('T3.1/T5.1: Dimensions for 1x (256x256), 2.0x (512x512), 3.0x (768x768)', () {
      for (final name in assets) {
        final f1x = File('assets/images/raven/$name');
        final f2x = File('assets/images/raven/2.0x/$name');
        final f3x = File('assets/images/raven/3.0x/$name');

        expect(f1x.existsSync(), isTrue, reason: '1x $name must exist');
        expect(f2x.existsSync(), isTrue, reason: '2x $name must exist');
        expect(f3x.existsSync(), isTrue, reason: '3x $name must exist');

        final img1x = decodePngFile(f1x);
        final img2x = decodePngFile(f2x);
        final img3x = decodePngFile(f3x);

        expect(img1x.width, equals(256), reason: '1x $name width must be 256');
        expect(img1x.height, equals(256), reason: '1x $name height must be 256');
        expect(img2x.width, equals(512), reason: '2x $name width must be 512');
        expect(img2x.height, equals(512), reason: '2x $name height must be 512');
        expect(img3x.width, equals(768), reason: '3x $name width must be 768');
        expect(img3x.height, equals(768), reason: '3x $name height must be 768');
      }
    });

    test('T3.2/T5.2: Real alpha channel presence (transparent and opaque pixels)', () {
      for (final name in assets) {
        final img = decodePngFile(File('assets/images/raven/$name'));
        expect(img.transparentPixels, isNotEmpty, reason: '$name must have transparent background pixels');
        expect(img.opaquePixels, isNotEmpty, reason: '$name must have opaque content pixels');
      }
    });

    test('T3.3: Rim contrast regression guard >= 4.5:1 against ground (#14110E)', () {
      final img = decodePngFile(File('assets/images/raven/body.png'));
      final bgLum = relativeLuminance(AppColors.ground.red, AppColors.ground.green, AppColors.ground.blue);

      final significantPixels = img.pixels.where((p) => p.a > 100).toList();
      expect(significantPixels, isNotEmpty);

      final maxLum = significantPixels
          .map((p) => relativeLuminance(p.r, p.g, p.b))
          .reduce((a, b) => a > b ? a : b);

      final contrast = contrastRatio(maxLum, bgLum);
      expect(contrast, greaterThanOrEqualTo(4.5),
          reason: 'Body rim contrast vs #14110E must be >= 4.5:1 (measured: $contrast)');
    });

    test('T3.4: Shared-canvas alignment (body bounding box contains eye bounding box)', () {
      final bodyImg = decodePngFile(File('assets/images/raven/body.png'));
      final eyeImg = decodePngFile(File('assets/images/raven/eye_open.png'));

      final bodyBox = bodyImg.alphaBoundingBox;
      final eyeBox = eyeImg.alphaBoundingBox;

      expect(bodyBox, isNotNull);
      expect(eyeBox, isNotNull);

      expect(bodyBox!.left, lessThanOrEqualTo(eyeBox!.left),
          reason: 'Body box left (${bodyBox.left}) must be <= eye box left (${eyeBox.left})');
      expect(bodyBox.top, lessThanOrEqualTo(eyeBox.top),
          reason: 'Body box top (${bodyBox.top}) must be <= eye box top (${eyeBox.top})');
      expect(bodyBox.right, greaterThanOrEqualTo(eyeBox.right),
          reason: 'Body box right (${bodyBox.right}) must be >= eye box right (${eyeBox.right})');
      expect(bodyBox.bottom, greaterThanOrEqualTo(eyeBox.bottom),
          reason: 'Body box bottom (${bodyBox.bottom}) must be >= eye box bottom (${eyeBox.bottom})');
    });
  });

  group('Task T5 — Raven Mascot Pose Contract & Animation Tests', () {
    testWidgets('Every RavenState value renders without exception', (WidgetTester tester) async {
      for (final state in RavenState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RavenMascot(state: state, size: 64),
            ),
          ),
        );
        expect(find.byType(RavenMascot), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Pose $state must render without throwing');
      }
    });

    for (final state in RavenState.values) {
      testWidgets('Reduced motion static frame stability for pose: ${state.name}', (WidgetTester tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: MaterialApp(
              home: Scaffold(
                body: RavenMascot(state: state, size: 64),
              ),
            ),
          ),
        );

        final countFirst = tester.widgetList(find.byType(Image)).length;
        await tester.pump(const Duration(milliseconds: 500));
        final countSecond = tester.widgetList(find.byType(Image)).length;

        expect(countFirst, equals(countSecond), reason: 'Pose ${state.name} must remain static under reduced motion');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('caw state renders beak_open.png asset', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.caw, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final hasBeakOpen = images.any((img) => (img.image as AssetImage).assetName.contains('beak_open.png'));
      expect(hasBeakOpen, isTrue, reason: 'Mid-animation caw must render beak_open.png');
      expect(tester.takeException(), isNull);
    });

    testWidgets('flap state renders wing_up.png asset during flap cycle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.flap, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 160));
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final hasWingUp = images.any((img) => (img.image as AssetImage).assetName.contains('wing_up.png'));
      expect(hasWingUp, isTrue, reason: 'Mid-flap state must render wing_up.png');
      expect(tester.takeException(), isNull);
    });

    testWidgets('disposal cleans up controllers without throwing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.idle, size: 64),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
      expect(tester.takeException(), isNull);
    });
  });

  group('Task T6 — Frame Index Math & Sprite Sheet Integrity', () {
    test('T6.1: Frame index calculation math and round() off-by-one guard', () {
      const int frames = 8;
      int calcIndex(double t) => (t * frames).floor().clamp(0, frames - 1);
      int faultyRoundIndex(double t) => (t * frames).round();

      expect(calcIndex(0.0), equals(0));
      expect(calcIndex(1.0), equals(7));

      for (int i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final idx = calcIndex(t);
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(frames), reason: 'Frame index at t=$t must be < $frames');
      }

      // Falsifying assertion: prove round() produces out-of-bounds index 8 at t = 1.0
      expect(faultyRoundIndex(1.0), equals(8), reason: 'round() at t=1.0 produces 8 (one past end of 8-frame sheet)');
    });

    test('T6.2: Sheet integrity (ruffle.png geometry, alpha channel, frame 0 contrast)', () {
      final ruffleFile = File('assets/images/raven/frames/ruffle.png');
      expect(ruffleFile.existsSync(), isTrue, reason: 'assets/images/raven/frames/ruffle.png must exist');

      final img = decodePngFile(ruffleFile);
      expect(img.width, equals(1024), reason: 'Ruffle sheet width must be 4 * 256 = 1024');
      expect(img.height, equals(512), reason: 'Ruffle sheet height must be 2 * 256 = 512');
      expect(img.transparentPixels, isNotEmpty, reason: 'Sheet must have transparent background');
      expect(img.opaquePixels, isNotEmpty, reason: 'Sheet must have opaque character content');

      // Rim contrast on frame 0 (top-left 256x256 cell)
      final bgLum = relativeLuminance(AppColors.ground.red, AppColors.ground.green, AppColors.ground.blue);
      final frame0Pixels = img.pixels.where((p) => p.x < 256 && p.y < 256 && p.a > 100).toList();
      expect(frame0Pixels, isNotEmpty);

      final maxLum = frame0Pixels
          .map((p) => relativeLuminance(p.r, p.g, p.b))
          .reduce((a, b) => a > b ? a : b);

      final contrast = contrastRatio(maxLum, bgLum);
      expect(contrast, greaterThanOrEqualTo(4.5),
          reason: 'Frame 0 rim contrast vs #14110E must be >= 4.5:1 (measured: $contrast)');
    });

    test('T6.3: Decoded memory budget assertion < 12 MB', () {
      final sheetFiles = Directory('assets/images/raven/frames')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'));

      int totalBytes = 0;
      for (final file in sheetFiles) {
        final img = decodePngFile(file);
        totalBytes += img.width * img.height * 4;
      }

      final totalMb = totalBytes / (1024 * 1024);
      expect(totalMb, lessThan(12.0),
          reason: 'Total decoded sheet memory must be < 12 MB (measured: ${totalMb.toStringAsFixed(2)} MB)');
    });
  });
}

