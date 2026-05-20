// Web-only implementation: builds a Blob and triggers a browser download.
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<bool> downloadBytesInBrowser(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  // Wrap the bytes in a JS array of BlobParts and construct a Blob.
  final blobParts = [bytes.toJS].toJS;
  final blob = web.Blob(
    blobParts,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  // Synthesize an <a download> click.
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Defer revoke a tick so the browser has time to start the download.
  Future.delayed(const Duration(seconds: 1), () {
    web.URL.revokeObjectURL(url);
  });

  return true;
}
