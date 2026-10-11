import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'png_decoder.dart' show contrastRatio, relativeLuminance;

/// What [measureRenderedContrast] found painted inside a target's rectangle.
typedef ContrastSample = ({
  double ratio,
  Color background,
  Color foreground,
  int foregroundPixels,
});

/// Measures the contrast actually painted inside [target]'s rect.
///
/// The caller wraps the whole pumped app in `RepaintBoundary(key: rootBoundary)`
/// and sets `tester.view.physicalSize` / `devicePixelRatio = 1.0`, so logical
/// pixels equal image pixels. The boundary is rasterised and the pixels inside
/// the target's rect (inflated by [inflate]) are read back, so what is measured
/// is what a player sees, including a Material component's own fill. Do NOT
/// replace this with a walk up the widget tree: that resolves the nearest
/// decorated ancestor and cannot see a component's own fill, which is how an
/// ivory label on a parchment chip (1.02 : 1) would have passed (Issue 179).
///
/// Background is the modal opaque colour in the rect. Foreground is, among the
/// colours with at least [minPixels] pixels, the one whose relative luminance
/// is furthest from the background's. The ratio is symmetric, so it does not
/// matter which of the two is the larger region.
///
/// Aim at a leaf (a `Text`, an icon) whose rect lies inside ONE painted region.
/// If the rect also covers a neighbouring surface, that surface becomes the
/// "foreground" and an invisible label passes: measure a chip through its label
/// `Text`, not through the chip.
///
/// Fails loudly instead of passing vacuously (lesson 2.21): if fewer than two
/// colours reach [minPixels], or the target has no area on screen, the test
/// fails with `measured nothing`.
Future<ContrastSample> measureRenderedContrast(
  WidgetTester tester,
  GlobalKey rootBoundary,
  Finder target, {
  int minPixels = 20,
  double inflate = 4,
}) async {
  final boundary = rootBoundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final ui.Image? image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1.0));
  if (image == null) fail('measured nothing: the root boundary could not be rasterised');
  final ByteData? data =
      await tester.runAsync<ByteData?>(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
  if (data == null) fail('measured nothing: the rasterised image has no pixel data');

  // Global rect -> the boundary's own coordinate space, clamped to the image.
  final Rect wanted = tester.getRect(target).inflate(inflate).shift(-boundary.localToGlobal(Offset.zero));
  final Rect rect = wanted.intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
  if (rect.isEmpty) {
    fail('measured nothing in $wanted: the target has no area inside the ${image.width}x${image.height} image');
  }

  final int left = rect.left.floor();
  final int top = rect.top.floor();
  final int right = rect.right.ceil().clamp(0, image.width);
  final int bottom = rect.bottom.ceil().clamp(0, image.height);

  final Map<int, int> counts = {};
  for (int y = top; y < bottom; y++) {
    for (int x = left; x < right; x++) {
      final int i = (y * image.width + x) * 4;
      if (data.getUint8(i + 3) < 128) continue;
      final int rgb = (data.getUint8(i) << 16) | (data.getUint8(i + 1) << 8) | data.getUint8(i + 2);
      counts[rgb] = (counts[rgb] ?? 0) + 1;
    }
  }

  final candidates = counts.entries.where((e) => e.value >= minPixels).toList();
  if (candidates.length < 2) {
    fail('measured nothing in $rect: ${candidates.length} colour(s) reach $minPixels pixels '
        '(${counts.length} distinct colours, ${counts.values.fold<int>(0, (a, b) => a + b)} opaque pixels). '
        'A contrast needs a background and a foreground.');
  }

  double luminanceOf(int rgb) =>
      relativeLuminance((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
  Color colorOf(int rgb) => Color.fromARGB(255, (rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

  final background = candidates.reduce((a, b) => b.value > a.value ? b : a);
  final double backgroundLuminance = luminanceOf(background.key);
  final foreground = candidates
      .where((e) => e.key != background.key)
      .reduce((a, b) {
    final double da = (luminanceOf(a.key) - backgroundLuminance).abs();
    final double db = (luminanceOf(b.key) - backgroundLuminance).abs();
    return db > da ? b : a;
  });

  return (
    ratio: contrastRatio(luminanceOf(foreground.key), backgroundLuminance),
    background: colorOf(background.key),
    foreground: colorOf(foreground.key),
    foregroundPixels: foreground.value,
  );
}
