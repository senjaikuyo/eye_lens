import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:eye_lens/core/constants/app_strings.dart';
import 'package:eye_lens/features/ocr/models/ocr_element.dart';

/// Helper untuk menampilkan snackbar dan menyalin log diagnostik OCR pada mode debug.
class ScanDiagnosticHelper {
  const ScanDiagnosticHelper._();

  static void maybeShowDiagnosticSnackBar(
    BuildContext context,
    OcrResult ocrResult,
  ) {
    final json = ocrResult.diagnosticJson;
    if (json == null || !kDebugMode || !context.mounted) return;

    final strings = AppStrings.of(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        content: Text(
          strings.isIndonesian
              ? 'Log diagnostik OCR siap.'
              : 'OCR diagnostic log is ready.',
          style: const TextStyle(fontSize: 16),
        ),
        action: SnackBarAction(
          label: strings.isIndonesian ? 'Salin log' : 'Copy log',
          onPressed: () => _showDiagnosticCopySheet(context, json),
        ),
      ),
    );
  }

  static Future<void> _showDiagnosticCopySheet(
    BuildContext context,
    String withTextJson,
  ) async {
    if (!context.mounted) return;
    final strings = AppStrings.of(context, listen: false);

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(
                  strings.isIndonesian
                      ? 'Salin log + teks'
                      : 'Copy log with text',
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: withTextJson));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(
                  strings.isIndonesian
                      ? 'Salin log tanpa teks'
                      : 'Copy log without text',
                ),
                subtitle: Text(
                  strings.isIndonesian
                      ? 'Hanya metrik, isi teks disensor'
                      : 'Metrics only, text content redacted',
                ),
                onTap: () async {
                  final sanitized = stripTextFromDiagnosticJson(withTextJson);
                  await Clipboard.setData(ClipboardData(text: sanitized));
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Menghapus isi teks dari JSON diagnostik sambil mempertahankan panjangnya.
  static String stripTextFromDiagnosticJson(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final texts = decoded['texts'];
      if (texts is Map) {
        decoded['texts'] = {
          'rawLength': (texts['raw'] as String?)?.length ?? 0,
          'filteredLength': (texts['filtered'] as String?)?.length ?? 0,
          'formattedLength': (texts['formatted'] as String?)?.length ?? 0,
        };
      }
      for (final key in ['rejectedLines', 'doubtfulLines']) {
        final entries = decoded[key];
        if (entries is! List) continue;
        for (final item in entries) {
          if (item is Map) {
            item['text'] = '<disembunyikan>';
            item['explanation'] = '<disembunyikan>';
          }
        }
      }
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (e) {
      debugPrint('[ScanDiagnosticHelper] Gagal menyensor log diagnostik: $e');
      return '{"error":"diagnostic_redaction_failed"}';
    }
  }
}
