import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';

class JsonExportService {
  static Future<void> exportToJson(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    try {
      final json = provider.exportJson();
      final bytes = utf8.encode(json);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'genogram_$timestamp.json';

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
