import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../magic_manager.dart';
import '../services/magic_processing_service.dart';

/// Service for exporting magic cube projects to various formats
class ExportService {
  /// Export processed slices as a PDF document
  static Future<ExportResult> exportToPDF({
    required String projectPath,
    required String templatePath,
    required String projectName,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Checking processed slices...');

      // Check if project is processed
      final status = await MagicProcessingService.getProcessingStatus(
          projectPath, templatePath);
      if (!status.isProcessed) {
        return ExportResult.error(
            'Project must be processed before exporting. Please process your images first.');
      }

      onProgress?.call('Loading template metadata...');

      // Load template metadata
      final templateMeta = await _loadTemplateMeta(templatePath);
      if (templateMeta == null) {
        return ExportResult.error('Failed to load template metadata');
      }

      onProgress?.call('Creating PDF document...');

      // Create PDF document
      final pdf = pw.Document();
      final sources = templateMeta['sources'] as List<dynamic>;

      // Add title page
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.SizedBox(height: 50),
                pw.Text(
                  'Magic Cube Export',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Project: $projectName',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.Text(
                  'Template: ${templateMeta['name'] ?? templatePath}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Assembly Instructions',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '1. Cut out each slice carefully along the edges',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  '2. Follow the assembly pattern for your template',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  '3. Use glue or double-sided tape to attach pieces',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  '4. Allow to dry completely before handling',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Total Slices: ${status.processedSlices}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      );

      int processedSlices = 0;

      // Process each source
      for (int sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        final sourceSpec = sources[sourceIndex] as Map<String, dynamic>;
        final sourceId = sourceSpec['id'] as int;
        final slices = sourceSpec['slices'] as List<dynamic>;

        onProgress?.call(
            'Exporting source $sourceId (${sourceIndex + 1}/${sources.length})...');

        // Create a page for this source
        final sourceSlices = <pw.Widget>[];

        for (final sliceSpec in slices) {
          final sliceId = sliceSpec['id'] as int;

          try {
            // Load the processed slice
            final sliceImage = await MagicManager.instance
                .loadSlice(projectPath, sourceId, sliceId);
            if (sliceImage != null) {
              // Convert to PDF image
              final pdfImage = await _convertImageToPDF(sliceImage);
              if (pdfImage != null) {
                sourceSlices.add(
                  pw.Container(
                    margin: const pw.EdgeInsets.all(5),
                    child: pw.Column(
                      children: [
                        pw.Container(
                          width: 150,
                          height: 150,
                          child: pw.Image(pdfImage),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Source $sourceId - Slice $sliceId',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
                processedSlices++;
              }
            }
          } catch (e) {
            debugPrint('Error loading slice $sourceId/$sliceId: $e');
          }
        }

        // Add source page if we have slices
        if (sourceSlices.isNotEmpty) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Source $sourceId Slices',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    pw.Wrap(
                      children: sourceSlices,
                    ),
                  ],
                );
              },
            ),
          );
        }
      }

      if (processedSlices == 0) {
        return ExportResult.error('No processed slices found to export');
      }

      onProgress?.call('Saving PDF file...');

      // Save PDF to device
      final output = await getApplicationDocumentsDirectory();
      final file = File('${output.path}/${projectName}_magic_cube.pdf');
      await file.writeAsBytes(await pdf.save());

      onProgress?.call('Export completed!');

      return ExportResult.success(
        filePath: file.path,
        exportedSlices: processedSlices,
        fileSize: await file.length(),
      );
    } catch (e) {
      debugPrint('Error exporting to PDF: $e');
      return ExportResult.error('Export failed: $e');
    }
  }

  /// Export processed slices as individual PNG files
  static Future<ExportResult> exportToImages({
    required String projectPath,
    required String templatePath,
    required String projectName,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Checking processed slices...');

      // Check if project is processed
      final status = await MagicProcessingService.getProcessingStatus(
          projectPath, templatePath);
      if (!status.isProcessed) {
        return ExportResult.error(
            'Project must be processed before exporting. Please process your images first.');
      }

      onProgress?.call('Loading template metadata...');

      // Load template metadata
      final templateMeta = await _loadTemplateMeta(templatePath);
      if (templateMeta == null) {
        return ExportResult.error('Failed to load template metadata');
      }

      // Create export directory
      final output = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${output.path}/${projectName}_slices');
      if (!exportDir.existsSync()) {
        exportDir.createSync(recursive: true);
      }

      final sources = templateMeta['sources'] as List<dynamic>;
      int exportedSlices = 0;

      // Export each slice
      for (int sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        final sourceSpec = sources[sourceIndex] as Map<String, dynamic>;
        final sourceId = sourceSpec['id'] as int;
        final slices = sourceSpec['slices'] as List<dynamic>;

        onProgress?.call(
            'Exporting source $sourceId (${sourceIndex + 1}/${sources.length})...');

        for (final sliceSpec in slices) {
          final sliceId = sliceSpec['id'] as int;

          try {
            // Load the processed slice
            final sliceImage = await MagicManager.instance
                .loadSlice(projectPath, sourceId, sliceId);
            if (sliceImage != null) {
              // Convert to bytes
              final byteData =
                  await sliceImage.toByteData(format: ui.ImageByteFormat.png);
              if (byteData != null) {
                final bytes = byteData.buffer.asUint8List();

                // Save as PNG file
                final sliceFile = File(
                    '${exportDir.path}/source_${sourceId}_slice_$sliceId.png');
                await sliceFile.writeAsBytes(bytes);
                exportedSlices++;
              }
            }
          } catch (e) {
            debugPrint('Error exporting slice $sourceId/$sliceId: $e');
          }
        }
      }

      if (exportedSlices == 0) {
        return ExportResult.error('No processed slices found to export');
      }

      onProgress?.call('Export completed!');

      return ExportResult.success(
        filePath: exportDir.path,
        exportedSlices: exportedSlices,
        fileSize: await _calculateDirectorySize(exportDir),
      );
    } catch (e) {
      debugPrint('Error exporting images: $e');
      return ExportResult.error('Export failed: $e');
    }
  }

  /// Share the exported PDF file
  static Future<bool> sharePDF(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return false;
      }

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Magic Cube Export - Ready to print and assemble!',
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      return false;
    }
  }

  /// Share multiple files (e.g. exported images)
  static Future<bool> shareFiles(List<String> filePaths, {String? text}) async {
    try {
      final files = <XFile>[];
      for (final path in filePaths) {
        final file = File(path);
        if (file.existsSync()) {
          files.add(XFile(path));
        }
      }

      if (files.isEmpty) return false;

      await Share.shareXFiles(
        files,
        text: text ?? 'Magic Cube Export',
      );

      return true;
    } catch (e) {
      debugPrint('Error sharing files: $e');
      return false;
    }
  }

  /// Load template metadata
  static Future<Map<String, dynamic>?> _loadTemplateMeta(
      String templatePath) async {
    try {
      final metaData =
          await rootBundle.loadString('assets/magics/$templatePath/meta.json');
      return json.decode(metaData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading template meta: $e');
      return null;
    }
  }

  /// Convert ui.Image to PDF image
  static Future<pw.ImageProvider?> _convertImageToPDF(ui.Image image) async {
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return pw.MemoryImage(bytes);
    } catch (e) {
      debugPrint('Error converting image to PDF: $e');
      return null;
    }
  }

  /// Calculate total size of a directory
  static Future<int> _calculateDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      final files = directory.listSync(recursive: true).whereType<File>();
      for (final file in files) {
        totalSize += await file.length();
      }
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
    }
    return totalSize;
  }
}

/// Result of an export operation
class ExportResult {
  final bool success;
  final String? error;
  final String? filePath;
  final int exportedSlices;
  final int fileSize;

  ExportResult.success({
    required this.filePath,
    required this.exportedSlices,
    required this.fileSize,
  })  : success = true,
        error = null;

  ExportResult.error(this.error)
      : success = false,
        filePath = null,
        exportedSlices = 0,
        fileSize = 0;

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
