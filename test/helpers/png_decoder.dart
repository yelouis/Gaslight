import 'dart:io';
import 'dart:math';

class PngPixel {
  final int r;
  final int g;
  final int b;
  final int a;
  final int x;
  final int y;

  const PngPixel(this.r, this.g, this.b, this.a, this.x, this.y);
}

class PngImageInfo {
  final int width;
  final int height;
  final List<PngPixel> pixels;

  PngImageInfo(this.width, this.height, this.pixels);

  List<PngPixel> get opaquePixels => pixels.where((p) => p.a > 0).toList();
  List<PngPixel> get transparentPixels => pixels.where((p) => p.a == 0).toList();

  Rectangle<int>? get alphaBoundingBox {
    final op = opaquePixels;
    if (op.isEmpty) return null;
    int minX = op.first.x;
    int maxX = op.first.x;
    int minY = op.first.y;
    int maxY = op.first.y;
    for (final p in op) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return Rectangle(minX, minY, maxX - minX + 1, maxY - minY + 1);
  }
}

/// Area of transparent space that the artwork encloses vertically -- for each
/// column, the transparent pixels lying between that column's topmost and
/// bottommost opaque pixel.
///
/// This is how "the beak is open" is measured. Rotating the upper mandible about
/// its hinge hardly changes the beak's mass or how far it protrudes, so those
/// numbers cannot tell open from closed; the gap between the mandibles is the
/// thing that actually changes, and the thing a viewer actually sees.
///
/// Pass [originX]/[originY]/[size] to measure one cell of a sprite sheet.
int enclosedCavity(
  PngImageInfo img, {
  int originX = 0,
  int originY = 0,
  int? size,
  int alphaThreshold = 0,
}) {
  final int x0 = originX;
  final int y0 = originY;
  final int x1 = size == null ? img.width : originX + size;
  final int y1 = size == null ? img.height : originY + size;

  // Column-major lookup of alpha, so the scan below stays O(pixels).
  final alpha = List<int>.filled((x1 - x0) * (y1 - y0), 0);
  for (final p in img.pixels) {
    if (p.x < x0 || p.x >= x1 || p.y < y0 || p.y >= y1) continue;
    alpha[(p.x - x0) * (y1 - y0) + (p.y - y0)] = p.a;
  }

  int total = 0;
  final height = y1 - y0;
  for (int cx = 0; cx < x1 - x0; cx++) {
    int top = -1;
    int bottom = -1;
    for (int cy = 0; cy < height; cy++) {
      if (alpha[cx * height + cy] > alphaThreshold) {
        if (top < 0) top = cy;
        bottom = cy;
      }
    }
    if (top < 0 || bottom <= top) continue;
    for (int cy = top; cy <= bottom; cy++) {
      if (alpha[cx * height + cy] <= alphaThreshold) total++;
    }
  }
  return total;
}

int _paethPredictor(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

PngImageInfo decodePngFile(File file) {
  final data = file.readAsBytesSync();
  return decodePngBytes(data);
}

PngImageInfo decodePngBytes(List<int> data) {
  if (data.length < 8 ||
      data[0] != 0x89 ||
      data[1] != 0x50 ||
      data[2] != 0x4E ||
      data[3] != 0x47) {
    throw FormatException('Invalid PNG header');
  }

  int offset = 8;
  int width = 0;
  int height = 0;
  int colorType = 3;
  List<List<int>> palette = [];
  List<int> trns = [];
  List<int> idatBytes = [];

  while (offset < data.length) {
    if (offset + 8 > data.length) break;
    final length = (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    final type = String.fromCharCodes(data.sublist(offset + 4, offset + 8));
    final chunkData = data.sublist(offset + 8, offset + 8 + length);
    offset += 8 + length + 4; // Length + Type + Data + CRC

    if (type == 'IHDR') {
      width = (chunkData[0] << 24) |
          (chunkData[1] << 16) |
          (chunkData[2] << 8) |
          chunkData[3];
      height = (chunkData[4] << 24) |
          (chunkData[5] << 16) |
          (chunkData[6] << 8) |
          chunkData[7];
      colorType = chunkData[9];
    } else if (type == 'PLTE') {
      for (int i = 0; i < chunkData.length; i += 3) {
        palette.add([chunkData[i], chunkData[i + 1], chunkData[i + 2]]);
      }
    } else if (type == 'tRNS') {
      trns = List<int>.from(chunkData);
    } else if (type == 'IDAT') {
      idatBytes.addAll(chunkData);
    }
  }

  final decompressed = zlib.decode(idatBytes);
  final List<PngPixel> pixels = [];

  if (colorType == 6) {
    // Truecolor with Alpha (RGBA, 4 bytes per pixel)
    final bpp = 4;
    List<int> prevRow = List<int>.filled(width * bpp, 0);
    int decompIdx = 0;

    for (int y = 0; y < height; y++) {
      final filterType = decompressed[decompIdx++];
      final rawRow = decompressed.sublist(decompIdx, decompIdx + width * bpp);
      decompIdx += width * bpp;

      final reconRow = List<int>.filled(width * bpp, 0);
      for (int i = 0; i < width * bpp; i++) {
        final filt = rawRow[i];
        final a = i >= bpp ? reconRow[i - bpp] : 0;
        final b = y > 0 ? prevRow[i] : 0;
        final c = (y > 0 && i >= bpp) ? prevRow[i - bpp] : 0;

        int val;
        if (filterType == 0) {
          val = filt;
        } else if (filterType == 1) {
          val = (filt + a) & 0xFF;
        } else if (filterType == 2) {
          val = (filt + b) & 0xFF;
        } else if (filterType == 3) {
          val = (filt + ((a + b) ~/ 2)) & 0xFF;
        } else if (filterType == 4) {
          val = (filt + _paethPredictor(a, b, c)) & 0xFF;
        } else {
          throw FormatException('Unknown PNG filter type: $filterType');
        }
        reconRow[i] = val;
      }

      for (int x = 0; x < width; x++) {
        final r = reconRow[x * bpp];
        final g = reconRow[x * bpp + 1];
        final bCol = reconRow[x * bpp + 2];
        final aVal = reconRow[x * bpp + 3];
        pixels.add(PngPixel(r, g, bCol, aVal, x, y));
      }
      prevRow = reconRow;
    }
  } else {
    // Indexed-color (Palette, 1 byte per pixel)
    List<int> prevRow = List<int>.filled(width, 0);
    int decompIdx = 0;

    for (int y = 0; y < height; y++) {
      final filterType = decompressed[decompIdx++];
      final rawRow = decompressed.sublist(decompIdx, decompIdx + width);
      decompIdx += width;

      final reconRow = List<int>.filled(width, 0);
      for (int x = 0; x < width; x++) {
        final filt = rawRow[x];
        final a = x > 0 ? reconRow[x - 1] : 0;
        final b = y > 0 ? prevRow[x] : 0;
        final c = (y > 0 && x > 0) ? prevRow[x - 1] : 0;

        int val;
        if (filterType == 0) {
          val = filt;
        } else if (filterType == 1) {
          val = (filt + a) & 0xFF;
        } else if (filterType == 2) {
          val = (filt + b) & 0xFF;
        } else if (filterType == 3) {
          val = (filt + ((a + b) ~/ 2)) & 0xFF;
        } else if (filterType == 4) {
          val = (filt + _paethPredictor(a, b, c)) & 0xFF;
        } else {
          throw FormatException('Unknown PNG filter type: $filterType');
        }

        reconRow[x] = val;
        final palIdx = val;
        final r = palette[palIdx][0];
        final g = palette[palIdx][1];
        final bCol = palette[palIdx][2];
        final aVal = palIdx < trns.length ? trns[palIdx] : 255;
        pixels.add(PngPixel(r, g, bCol, aVal, x, y));
      }
      prevRow = reconRow;
    }
  }

  return PngImageInfo(width, height, pixels);
}

double relativeLuminance(int r, int g, int b) {
  double linearize(int channel) {
    final c = channel / 255.0;
    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b);
}

double contrastRatio(double lum1, double lum2) {
  final lHi = max(lum1, lum2);
  final lLo = min(lum1, lum2);
  return (lHi + 0.05) / (lLo + 0.05);
}
