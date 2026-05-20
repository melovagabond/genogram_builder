import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../providers/genogram_provider.dart';
import '../constants/app_theme.dart';

class ImportService {
  static Future<void> importFromJson(
    BuildContext context,
    GenogramProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _snack(context, 'Could not read file');
        return;
      }

      final jsonString = String.fromCharCodes(file.bytes!);
      provider.importJson(jsonString);

      if (context.mounted) {
        _snack(context, 'Imported successfully');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Import failed: $e');
      }
    }
  }

  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: kText)),
        backgroundColor: kSurface2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
