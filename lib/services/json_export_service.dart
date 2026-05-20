import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';

class JsonExportService {
  static Future<void> exportToJson(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    try {
      final json = provider.exportJson();
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/genogram_$timestamp.json');
      await file.writeAsString(json);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Genogram Export',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e', style: const TextStyle(color: kText)),
            backgroundColor: kSurface2,
          ),
        );
      }
    }
  }
}
