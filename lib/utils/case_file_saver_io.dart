import 'dart:typed_data';

/// Mobile/Desktop fallback. Throws [UnsupportedError] because native platforms
/// use the native sharing sheet via `SharePlus` instead.
void saveCaseFilePng(Uint8List bytes, String fileName) {
  throw UnsupportedError('saveCaseFilePng is only supported on web platforms.');
}
