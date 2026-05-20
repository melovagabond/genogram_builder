import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';
import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';

class JsonExportService {
  static Future<void> exportToJson(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    try {
      final json = provider.exportJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'genogram_$timestamp.json';

      if (kIsWeb) {
        // Browser: trigger a direct download via Blob + <a download>. This
        // avoids navigator.share() which is gated by HTTPS + user-gesture
        // permission and fails on localhost / desktop Chrome.
        await downloadBytesInBrowser(bytes, filename, 'application/json');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded $filename',
                  style: const TextStyle(color: kText)),
              backgroundColor: kSurface2,
            ),
          );
        }
        return;
      }

      // Native: use the OS share sheet.
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: 'application/json',
          ),
        ],
        subject: 'Genogram Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Export failed: $e', style: const TextStyle(color: kText)),
            backgroundColor: kSurface2,
          ),
        );
      }
    }
  }
}
