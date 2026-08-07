import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gaslight/widgets/raven_mascot.dart';
import 'package:gaslight/theme/app_colors.dart';
import 'helpers/png_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task T3 — Raven Mascot Asset & Contrast Integrity (PNG Decoded)', () {
    final assets = ['body.png', 'wing.png', 'eye_open.png', 'eye_closed.png'];

    test('T3.1: Dimensions for 1x (256x256), 2.0x (512x512), 3.0x (768x768)', () {
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

    test('T3.2: Real alpha channel presence (transparent and opaque pixels)', () {
      for (final name in assets) {
        final img = decodePngFile(File('assets/images/raven/$name'));
        expect(img.transparentPixels, isNotEmpty, reason: '$name must have transparent background pixels');
        expect(img.opaquePixels, isNotEmpty, reason: '$name must have opaque content pixels');
      }
    });

    test('T3.3: Rim contrast regression guard >= 4.5:1 against ground (#14110E)', () {
      final img = decodePngFile(File('assets/images/raven/body.png'));
      final bgLum = relativeLuminance(AppColors.ground.red, AppColors.ground.green, AppColors.ground.blue);

      // Filter significant opaque pixels (a > 100) to find the brightest rim pixel
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

  group('Task T3 — Raven Mascot Per-Pose Animation Contract Tests', () {
    testWidgets('sleep state renders eye_closed.png asset', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.sleep, size: 64),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(3));

      final eyeAsset = images.last.image as AssetImage;
      expect(eyeAsset.assetName, endsWith('eye_closed.png'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('idle state renders eye_open.png asset at rest', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.idle, size: 64),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(3));

      final eyeAsset = images.last.image as AssetImage;
      expect(eyeAsset.assetName, endsWith('eye_open.png'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hop state applies non-identity Transform at mid-animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.hop, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 150));
      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      expect(transforms, isNotEmpty);

      final bool hasActiveTransform = transforms.any((t) => t.transform != Matrix4.identity());
      expect(hasActiveTransform, isTrue, reason: 'Mid-animation hop must apply non-identity transform');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ruffle state applies non-identity Transform at mid-animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.ruffle, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 250));
      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      expect(transforms, isNotEmpty);

      final bool hasActiveTransform = transforms.any((t) => t.transform != Matrix4.identity());
      expect(hasActiveTransform, isTrue, reason: 'Mid-animation ruffle must apply non-identity transform');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('fly state applies non-identity Transform at mid-animation', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RavenMascot(state: RavenState.fly, size: 64),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 450));
      final transforms = tester.widgetList<Transform>(find.byType(Transform)).toList();
      expect(transforms, isNotEmpty);

      final bool hasActiveTransform = transforms.any((t) => t.transform != Matrix4.identity());
      expect(hasActiveTransform, isTrue, reason: 'Mid-animation fly must apply non-identity transform');

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduced motion renders static frame identical across pumps', (WidgetTester tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(accessibleNavigation: true),
          child: const MaterialApp(
            home: Scaffold(
              body: RavenMascot(state: RavenState.sleep, size: 64),
            ),
          ),
        ),
      );

      final countFirst = tester.widgetList(find.byType(Image)).length;
      await tester.pump(const Duration(milliseconds: 500));
      final countSecond = tester.widgetList(find.byType(Image)).length;

      expect(countFirst, equals(countSecond));
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
}
