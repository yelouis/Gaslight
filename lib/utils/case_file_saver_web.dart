import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web implementation of Case File PNG downloader using blob URLs and synthetic anchor clicks.
void saveCaseFilePng(Uint8List bytes, String fileName) {
  final jsArray = bytes.toJS;
  final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
