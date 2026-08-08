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

    testWidgets('caw state renders sprite sheet sequence with beak open composite', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.caw, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(RavenMascot), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'caw sprite sheet sequence must render without throwing');
    });

    testWidgets('flap state renders sprite sheet sequence during flap cycle', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.flap, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byType(RavenMascot), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'flap sprite sheet sequence must render without throwing');
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

    test('T6.2: Sheet integrity across all 10 transient pose sprite sheets (geometry, alpha, rim contrast)', () {
      final poseSpecs = <String, List<int>>{
        'ruffle': [1024, 512],
        'startle': [768, 512],
        'hop': [1024, 512],
        'peck': [768, 512],
        'bow': [1024, 512],
        'alert': [768, 512],
        'preen': [1024, 512],
        'fly': [1024, 512],
        'flap': [768, 512],
        'caw': [768, 512],
      };

      final bgLum = relativeLuminance(AppColors.ground.red, AppColors.ground.green, AppColors.ground.blue);

      for (final entry in poseSpecs.entries) {
        final poseName = entry.key;
        final expectedW = entry.value[0];
        final expectedH = entry.value[1];

        final sheetFile = File('assets/images/raven/frames/$poseName.png');
        expect(sheetFile.existsSync(), isTrue, reason: 'assets/images/raven/frames/$poseName.png must exist');

        final img = decodePngFile(sheetFile);
        expect(img.width, equals(expectedW), reason: '$poseName sheet width must be $expectedW');
        expect(img.height, equals(expectedH), reason: '$poseName sheet height must be $expectedH');
        expect(img.transparentPixels, isNotEmpty, reason: '$poseName sheet must have transparent background');
        expect(img.opaquePixels, isNotEmpty, reason: '$poseName sheet must have opaque character content');

        // Rim contrast on frame 0 (top-left 256x256 cell)
        final frame0Pixels = img.pixels.where((p) => p.x < 256 && p.y < 256 && p.a > 100).toList();
        expect(frame0Pixels, isNotEmpty);

        final maxLum = frame0Pixels
            .map((p) => relativeLuminance(p.r, p.g, p.b))
            .reduce((a, b) => a > b ? a : b);

        final contrast = contrastRatio(maxLum, bgLum);
        expect(contrast, greaterThanOrEqualTo(4.5),
            reason: '$poseName frame 0 rim contrast vs #14110E must be >= 4.5:1 (measured: $contrast)');
      }
    });

    test('T6.3: Decoded memory budget assertion < 20 MB for all 10 sheets (< 12 MB active screen set)', () {
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
      expect(totalMb, lessThan(20.0),
          reason: 'Total decoded sheet memory across all 10 sheets must be < 20 MB (measured: ${totalMb.toStringAsFixed(2)} MB)');
    });
  });

  group('Task T7 — Mascot Pose Re-authoring Validation Set', () {
    test('T7.1: Wing rotation cap assertion (|wing_rot| <= 0.12 rad)', () {
      final script = File('scripts/build_sprite_sheets.py').readAsStringSync();
      expect(script, contains('assert abs(wing_rot) <= 0.12001'),
          reason: 'build_sprite_sheets.py must enforce wing_rot <= 0.12 rad assertion');
    });

    test('T7.2: Silhouette cell boundary containment (no opaque pixel touches cell border)', () {
      final poseSpecs = ['preen', 'fly', 'flap', 'caw'];
      for (final pose in poseSpecs) {
        final img = decodePngFile(File('assets/images/raven/frames/$pose.png'));
        final cols = img.width ~/ 256;
        final rows = img.height ~/ 256;
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            final cellPixels = img.pixels.where((p) =>
                p.x >= c * 256 && p.x < (c + 1) * 256 &&
                p.y >= r * 256 && p.y < (r + 1) * 256 &&
                p.a > 100);
            final touchesBorder = cellPixels.any((p) {
              final localX = p.x % 256;
              final localY = p.y % 256;
              return localX == 0 || localX == 255 || localY == 0 || localY == 255;
            });
            expect(touchesBorder, isFalse, reason: '$pose cell ($c, $r) opaque pixels must not touch cell border');
          }
        }
      }
    });

    test('T7.3: Beak open lower mandible structure assertion (beak_open contains dropped lower mandible & mouth cavity)', () {
      final beakImg = decodePngFile(File('assets/images/raven/beak_open.png'));
      final mouthPixels = beakImg.pixels.where((p) => p.a > 100 && p.x >= 144 && p.y >= 78).toList();
      expect(mouthPixels, isNotEmpty,
          reason: 'beak_open.png must contain dropped lower mandible pixels (y >= 78, x >= 144)');
      final hasBrassRim = mouthPixels.any((p) => p.r > 180 && p.g > 140);
      expect(hasBrassRim, isTrue, reason: 'beak_open lower mandible must have brass outline (#C9A24B)');
    });
  });
}


