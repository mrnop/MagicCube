import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../magic_manager.dart';

/// Service that handles the magic cube processing workflow:
/// 1. Load source images from a project
/// 2. Extract slices from each source using polygon coordinates
/// 3. Apply transformations (perspective, rotation, etc.) to each slice
/// 4. Save processed slices for final assembly
class MagicProcessingService {
  /// Process all images in a project according to the template specifications
  static Future<ProcessingResult> processProject({
    required String projectPath,
    required String templatePath,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Loading template metadata...');

      // Load template metadata
      final templateMeta = await _loadTemplateMeta(templatePath);
      if (templateMeta == null) {
        return ProcessingResult.error('Failed to load template metadata');
      }

      onProgress?.call('Loading source images...');

      // Load all source images from the project
      final sourceImages = await _loadProjectSourceImages(projectPath);
      if (sourceImages.isEmpty) {
        return ProcessingResult.error('No source images found in project');
      }

      final sources = templateMeta['sources'] as List<dynamic>;
      final totalSlices = sources.fold<int>(
          0, (sum, source) => sum + (source['slices'] as List).length);

      int processedSlices = 0;

      onProgress?.call(
          'Processing ${sources.length} sources with $totalSlices total slices...');

      // Process each source
      for (int sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        final sourceSpec = sources[sourceIndex] as Map<String, dynamic>;
        final sourceId = sourceSpec['id'] as int;

        // Find corresponding source image
        ui.Image? sourceImage;
        if (sourceIndex < sourceImages.length) {
          sourceImage = sourceImages[sourceIndex];
        } else if (sourceImages.isNotEmpty) {
          // If we have fewer images than sources, reuse the first image
          sourceImage = sourceImages[0];
        }

        if (sourceImage == null) continue;

        onProgress?.call(
            'Processing source $sourceId (${sourceIndex + 1}/${sources.length})...');

        // Process all slices for this source
        final slices = sourceSpec['slices'] as List<dynamic>;
        for (final sliceSpec in slices) {
          final sliceResult = await _processSlice(
            sourceImage: sourceImage,
            sliceSpec: sliceSpec as Map<String, dynamic>,
            sourceSpec: sourceSpec,
            projectPath: projectPath,
            sourceId: sourceId,
          );

          if (sliceResult) {
            processedSlices++;
            onProgress?.call('Processed slice ${processedSlices}/$totalSlices');
          }
        }
      }

      onProgress
          ?.call('Processing completed! Generated $processedSlices slices.');

      return ProcessingResult.success(
        processedSlices: processedSlices,
        totalSlices: totalSlices,
      );
    } catch (e) {
      debugPrint('Error processing project: $e');
      return ProcessingResult.error('Processing failed: $e');
    }
  }

  /// Load template metadata from assets
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

  /// Load all source images from a project directory
  static Future<List<ui.Image>> _loadProjectSourceImages(
      String projectPath) async {
    final images = <ui.Image>[];
    final projectDir =
        Directory('${MagicManager.instance.workDir.path}/$projectPath');

    if (!projectDir.existsSync()) return images;

    try {
      // Look for source images in the project directory
      final files = projectDir.listSync().whereType<File>().toList();

      // Sort files to ensure consistent ordering
      files
          .sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      for (final file in files) {
        final fileName = file.path.split('/').last.toLowerCase();

        // Check if this is a source image file
        if (fileName.startsWith('source_image') &&
            (fileName.endsWith('.png') ||
                fileName.endsWith('.jpg') ||
                fileName.endsWith('.jpeg'))) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          images.add(frame.image);
        }
      }

      debugPrint(
          'Loaded ${images.length} source images from project $projectPath');
      return images;
    } catch (e) {
      debugPrint('Error loading source images: $e');
      return images;
    }
  }

  /// Process a single slice from a source image
  static Future<bool> _processSlice({
    required ui.Image sourceImage,
    required Map<String, dynamic> sliceSpec,
    required Map<String, dynamic> sourceSpec,
    required String projectPath,
    required int sourceId,
  }) async {
    try {
      final sliceId = sliceSpec['id'] as int;
      final polygon = sliceSpec['polygon'] as List<dynamic>;
      final transforms = sliceSpec['transforms'] as List<dynamic>?;

      // Get expected source dimensions from meta.json
      final expectedWidth = (sourceSpec['width'] as num).toDouble();
      final expectedHeight = (sourceSpec['height'] as num).toDouble();

      // Calculate scaling factors to match actual source image dimensions
      final scaleX = sourceImage.width / expectedWidth;
      final scaleY = sourceImage.height / expectedHeight;

      // Extract and scale polygon coordinates
      final points = polygon
          .map((point) => Offset((point['x'] as num).toDouble() * scaleX,
              (point['y'] as num).toDouble() * scaleY))
          .toList();

      if (points.length < 3) {
        debugPrint(
            'Invalid polygon for slice $sliceId: needs at least 3 points');
        return false;
      }

      // Extract the slice from the source image using the polygon
      final sliceImage = await _extractPolygonSlice(sourceImage, points);
      if (sliceImage == null) {
        debugPrint('Failed to extract slice $sliceId');
        return false;
      }

      // Apply transformations if specified
      ui.Image processedImage = sliceImage;
      if (transforms != null && transforms.isNotEmpty) {
        for (final transform in transforms) {
          final transformMap = transform as Map<String, dynamic>;
          processedImage =
              await _applyTransform(processedImage, transformMap) ??
                  processedImage;
        }
      }

      // Convert to PNG bytes
      final byteData =
          await processedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        debugPrint('Failed to convert slice $sliceId to bytes');
        return false;
      }

      // Save the processed slice
      await MagicManager.instance.saveSlice(
        projectPath,
        sourceId,
        sliceId,
        byteData.buffer.asUint8List(),
      );

      debugPrint('Successfully processed slice $sliceId for source $sourceId');
      return true;
    } catch (e) {
      debugPrint('Error processing slice: $e');
      return false;
    }
  }

  /// Extract a polygonal slice from an image
  static Future<ui.Image?> _extractPolygonSlice(
      ui.Image sourceImage, List<Offset> polygon) async {
    try {
      // Calculate bounding rectangle
      final bounds = _getBoundingRect(polygon);

      // Create a new image with the bounding rectangle dimensions
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, bounds);

      // Clear with transparent background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        Paint()..color = Colors.transparent,
      );

      // Create clipping path from polygon
      final path = Path();
      if (polygon.isNotEmpty) {
        // Adjust polygon points relative to bounds
        final adjustedPolygon = polygon
            .map((point) =>
                Offset(point.dx - bounds.left, point.dy - bounds.top))
            .toList();

        // Build path - ensure correct winding order for proper clipping
        path.moveTo(adjustedPolygon[0].dx, adjustedPolygon[0].dy);
        for (int i = 1; i < adjustedPolygon.length; i++) {
          path.lineTo(adjustedPolygon[i].dx, adjustedPolygon[i].dy);
        }
        path.close();

        // Set fill type to ensure proper clipping behavior
        path.fillType = PathFillType.nonZero;
      }

      // Save canvas state before clipping
      canvas.save();

      // Apply clipping path
      canvas.clipPath(path);

      // Draw the source image, properly positioned within the bounds
      canvas.drawImageRect(
        sourceImage,
        Rect.fromLTWH(
            0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        Rect.fromLTWH(-bounds.left, -bounds.top, sourceImage.width.toDouble(),
            sourceImage.height.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      // Restore canvas state
      canvas.restore();

      final picture = recorder.endRecording();
      return await picture.toImage(bounds.width.toInt(), bounds.height.toInt());
    } catch (e) {
      debugPrint('Error extracting polygon slice: $e');
      return null;
    }
  }

  /// Calculate bounding rectangle for a list of points
  static Rect _getBoundingRect(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = points[0].dx;
    double maxX = points[0].dx;
    double minY = points[0].dy;
    double maxY = points[0].dy;

    for (final point in points) {
      minX = minX < point.dx ? minX : point.dx;
      maxX = maxX > point.dx ? maxX : point.dx;
      minY = minY < point.dy ? minY : point.dy;
      maxY = maxY > point.dy ? maxY : point.dy;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Apply a transformation to an image
  static Future<ui.Image?> _applyTransform(
      ui.Image image, Map<String, dynamic> transform) async {
    try {
      final transformType = transform['type'] as String;
      final params = transform['params'] as Map<String, dynamic>?;

      switch (transformType) {
        case 'perspective':
          return await _applyPerspectiveTransform(image, params);
        case 'rotate':
          return await _applyRotationTransform(image, params);
        case 'scale':
          return await _applyScaleTransform(image, params);
        default:
          debugPrint('Unknown transform type: $transformType');
          return image;
      }
    } catch (e) {
      debugPrint('Error applying transform: $e');
      return null;
    }
  }

  /// Apply perspective transformation to an image
  static Future<ui.Image?> _applyPerspectiveTransform(
      ui.Image image, Map<String, dynamic>? params) async {
    if (params == null || !params.containsKey('dest')) return image;

    try {
      final destPoints = params['dest'] as List<dynamic>;
      if (destPoints.length != 4) return image;

      // Parse destination points
      final dest = destPoints
          .map((point) => Offset(
              (point['x'] as num).toDouble(), (point['y'] as num).toDouble()))
          .toList();

      // Calculate output size
      final bounds = _getBoundingRect(dest);
      final outputWidth = bounds.width.toInt();
      final outputHeight = bounds.height.toInt();

      if (outputWidth <= 0 || outputHeight <= 0) return image;

      // Create transformed image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()));

      // Clear background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outputWidth.toDouble(), outputHeight.toDouble()),
        Paint()..color = Colors.transparent,
      );

      // Create transformation matrix (simplified perspective)
      // For now, we'll scale and position the image to fit the destination bounds
      final scaleX = outputWidth / image.width;
      final scaleY = outputHeight / image.height;

      canvas.save();
      canvas.scale(scaleX, scaleY);
      canvas.drawImage(image, Offset.zero, Paint());
      canvas.restore();

      final picture = recorder.endRecording();
      return await picture.toImage(outputWidth, outputHeight);
    } catch (e) {
      debugPrint('Error applying perspective transform: $e');
      return null;
    }
  }

  /// Apply rotation transformation to an image
  static Future<ui.Image?> _applyRotationTransform(
      ui.Image image, Map<String, dynamic>? params) async {
    if (params == null || !params.containsKey('angle')) return image;

    try {
      final angle = (params['angle'] as num).toDouble();
      final radians = angle * (3.14159 / 180.0); // Convert to radians

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));

      canvas.translate(image.width / 2, image.height / 2);
      canvas.rotate(radians);
      canvas.translate(-image.width / 2, -image.height / 2);
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      return await picture.toImage(image.width, image.height);
    } catch (e) {
      debugPrint('Error applying rotation transform: $e');
      return null;
    }
  }

  /// Apply scale transformation to an image
  static Future<ui.Image?> _applyScaleTransform(
      ui.Image image, Map<String, dynamic>? params) async {
    if (params == null) return image;

    try {
      final scaleX = (params['scaleX'] as num?)?.toDouble() ?? 1.0;
      final scaleY = (params['scaleY'] as num?)?.toDouble() ?? scaleX;

      final newWidth = (image.width * scaleX).toInt();
      final newHeight = (image.height * scaleY).toInt();

      if (newWidth <= 0 || newHeight <= 0) return image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()));

      canvas.scale(scaleX, scaleY);
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      return await picture.toImage(newWidth, newHeight);
    } catch (e) {
      debugPrint('Error applying scale transform: $e');
      return null;
    }
  }

  /// Check if a project has source images ready for processing
  static Future<bool> hasSourceImages(String projectPath) async {
    final sourceImages = await _loadProjectSourceImages(projectPath);
    return sourceImages.isNotEmpty;
  }

  /// Get processing status for a project
  static Future<ProcessingStatus> getProcessingStatus(
      String projectPath, String templatePath) async {
    try {
      final templateMeta = await _loadTemplateMeta(templatePath);
      if (templateMeta == null) {
        return ProcessingStatus(
            isProcessed: false, error: 'Template not found');
      }

      final sources = templateMeta['sources'] as List<dynamic>;
      int totalSlices = 0;
      int processedSlices = 0;

      for (final source in sources) {
        final sourceId = source['id'] as int;
        final slices = source['slices'] as List<dynamic>;

        for (final slice in slices) {
          final sliceId = slice['id'] as int;
          totalSlices++;

          // Check if slice exists
          try {
            final sliceImage = await MagicManager.instance
                .loadSlice(projectPath, sourceId, sliceId);
            if (sliceImage != null) {
              processedSlices++;
            }
          } catch (e) {
            // Slice doesn't exist
          }
        }
      }

      return ProcessingStatus(
        isProcessed: processedSlices == totalSlices && totalSlices > 0,
        processedSlices: processedSlices,
        totalSlices: totalSlices,
      );
    } catch (e) {
      return ProcessingStatus(
          isProcessed: false, error: 'Error checking status: $e');
    }
  }
}

/// Result of magic processing operation
class ProcessingResult {
  final bool success;
  final String? error;
  final int processedSlices;
  final int totalSlices;

  ProcessingResult.success({
    required this.processedSlices,
    required this.totalSlices,
  })  : success = true,
        error = null;

  ProcessingResult.error(this.error)
      : success = false,
        processedSlices = 0,
        totalSlices = 0;
}

/// Status of processing for a project
class ProcessingStatus {
  final bool isProcessed;
  final int processedSlices;
  final int totalSlices;
  final String? error;

  ProcessingStatus({
    required this.isProcessed,
    this.processedSlices = 0,
    this.totalSlices = 0,
    this.error,
  });

  double get progress => totalSlices > 0 ? processedSlices / totalSlices : 0.0;
}
