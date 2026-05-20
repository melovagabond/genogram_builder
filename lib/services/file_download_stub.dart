// Default (non-web) implementation. The web build uses `file_download_web.dart`
// via conditional import.
import 'dart:typed_data';

Future<bool> downloadBytesInBrowser(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  // Not running on web; signal that the caller should use the native share
  // path instead.
  return false;
}
