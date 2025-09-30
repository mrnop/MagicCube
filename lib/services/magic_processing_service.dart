import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../magic_manager.dart';
import '../utils/image_utils.dart';

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
    bool forceReprocess = false,
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
          final sliceId = sliceSpec['id'] as int;

          // Check if slice already exists and we're not forcing reprocess
          if (!forceReprocess) {
            try {
              final existingSlice = await MagicManager.instance
                  .loadSlice(projectPath, sourceId, sliceId);
              if (existingSlice != null) {
                processedSlices++;
                onProgress?.call(
                    'Slice $sliceId already exists - skipped ($processedSlices/$totalSlices)');
                continue;
              }
            } catch (e) {
              // Slice doesn't exist, continue with processing
            }
          }

          final sliceResult = await _processSlice(
            sourceImage: sourceImage,
            sliceSpec: sliceSpec as Map<String, dynamic>,
            sourceSpec: sourceSpec,
            projectPath: projectPath,
            sourceId: sourceId,
          );

          if (sliceResult) {
            processedSlices++;
            final action = forceReprocess ? 'Reprocessed' : 'Processed';
            onProgress?.call('$action slice $processedSlices/$totalSlices');
          }
        }
      }

      final action = forceReprocess ? 'Reprocessing' : 'Processing';
      onProgress?.call('$action completed! Generated $processedSlices slices.');

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
      final expectedWidth = (sourceSpec['width'] as num).toInt();
      final expectedHeight = (sourceSpec['height'] as num).toInt();

      debugPrint('Processing slice $sliceId for source $sourceId:');
      debugPrint(
          '  Expected dimensions from meta.json: ${expectedWidth}x$expectedHeight');
      debugPrint(
          '  Actual source image dimensions: ${sourceImage.width}x${sourceImage.height}');
      debugPrint('  Original polygon from meta.json: $polygon');

      // Scale source image to fit the defined dimensions from meta.json
      ui.Image workingImage = sourceImage;
      final needsScaling = (sourceImage.width != expectedWidth) ||
          (sourceImage.height != expectedHeight);

      if (needsScaling) {
        debugPrint(
            '  Scaling source image from ${sourceImage.width}x${sourceImage.height} to ${expectedWidth}x$expectedHeight');

        // Scale the source image to match meta.json dimensions
        workingImage = await ImageUtils.scaleBitmap(
                sourceImage, expectedWidth, expectedHeight) ??
            sourceImage;

        debugPrint(
            '  Source scaled to: ${workingImage.width}x${workingImage.height}');
      } else {
        debugPrint(
            '  No image scaling needed - source matches meta.json dimensions');
      }

      // Use original polygon coordinates (designed for meta.json dimensions)
      final points = polygon
          .map((point) => Offset(
              (point['x'] as num).toDouble(), (point['y'] as num).toDouble()))
          .toList();

      debugPrint('  Using original polygon coordinates: $points');

      if (points.length < 3) {
        debugPrint(
            'Invalid polygon for slice $sliceId: needs at least 3 points');
        return false;
      }

      // Extract the slice from the scaled source image using the original polygon coordinates
      final sliceImage = await _extractPolygonSlice(workingImage, points);
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
  /// Following the exact logic from Java MagicManager.cropPolygon()
  static Future<ui.Image?> _extractPolygonSlice(
      ui.Image sourceImage, List<Offset> polygon) async {
    try {
      if (polygon.isEmpty) return null;

      // Calculate bounding rectangle (like Java minX, maxX, minY, maxY)
      final bounds = _getBoundingRect(polygon);

      debugPrint('Extracting polygon slice:');
      debugPrint('  Bounds: $bounds');
      debugPrint('  Image size: ${sourceImage.width}x${sourceImage.height}');
      debugPrint('  Polygon: $polygon');

      // Step 1: Create a full-size image with clipping path applied
      // Following Java: canvas.drawPath(path, paint) then paint.setXfermode(SRC_IN) then canvas.drawBitmap
      final fullRecorder = ui.PictureRecorder();
      final fullCanvas = Canvas(
          fullRecorder,
          Rect.fromLTWH(0, 0, sourceImage.width.toDouble(),
              sourceImage.height.toDouble()));

      // Create clipping path using original polygon coordinates
      final path = Path();
      path.moveTo(polygon[0].dx, polygon[0].dy);
      for (int i = 1; i < polygon.length; i++) {
        path.lineTo(polygon[i].dx, polygon[i].dy);
      }
      path.close();
      path.fillType = PathFillType.nonZero;

      // Clear the canvas first
      fullCanvas.drawRect(
          Rect.fromLTWH(0, 0, sourceImage.width.toDouble(),
              sourceImage.height.toDouble()),
          Paint()..color = Colors.transparent);

      // Step 1a: Draw the path as a white mask (like Java: canvas.drawPath(path, paint))
      final maskPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      fullCanvas.drawPath(path, maskPaint);

      // Step 1b: Draw the source image with SRC_IN blend mode
      // (like Java: paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN)))
      final srcInPaint = Paint()
        ..blendMode = BlendMode.srcIn
        ..filterQuality = FilterQuality.high;
      fullCanvas.drawImage(sourceImage, Offset.zero, srcInPaint);

      final fullPicture = fullRecorder.endRecording();
      final fullImage =
          await fullPicture.toImage(sourceImage.width, sourceImage.height);

      // Step 2: Crop to bounding rectangle
      // (Like Java: resultCanvas.drawBitmap(cropImage, -minX, -minY, new Paint()))
      final resultRecorder = ui.PictureRecorder();
      final resultCanvas = Canvas(
          resultRecorder, Rect.fromLTWH(0, 0, bounds.width, bounds.height));

      // Clear background
      resultCanvas.drawRect(Rect.fromLTWH(0, 0, bounds.width, bounds.height),
          Paint()..color = Colors.transparent);

      // Draw the full masked image at offset (-minX, -minY) like Java
      // This crops the image by positioning it so the bounding rect becomes visible at (0,0)
      resultCanvas.drawImage(
        fullImage,
        Offset(-bounds.left,
            -bounds.top), // This is the (-minX, -minY) offset from Java
        Paint()..filterQuality = FilterQuality.high,
      );

      final resultPicture = resultRecorder.endRecording();
      final result = await resultPicture.toImage(
          bounds.width.toInt(), bounds.height.toInt());

      debugPrint('  Generated slice: ${result.width}x${result.height}');

      // Clean up intermediate image
      fullImage.dispose();

      return result;
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

      // Calculate output size based on bounding rectangle
      final bounds = _getBoundingRect(dest);
      final outputWidth = bounds.width.toInt();
      final outputHeight = bounds.height.toInt();

      if (outputWidth <= 0 || outputHeight <= 0) return image;

      // Create transformed image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, bounds);

      // Clear background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        Paint()..color = Colors.transparent,
      );

      // Adjust destination points relative to bounds
      final adjustedDest = dest
          .map((point) => Offset(point.dx - bounds.left, point.dy - bounds.top))
          .toList();

      // Apply perspective transformation using a path and clipping
      // This is a simplified approach - for true perspective mapping,
      // we'd need matrix transformation which is complex in Flutter's canvas
      final path = Path();
      path.moveTo(adjustedDest[0].dx, adjustedDest[0].dy);
      for (int i = 1; i < adjustedDest.length; i++) {
        path.lineTo(adjustedDest[i].dx, adjustedDest[i].dy);
      }
      path.close();

      canvas.save();
      canvas.clipPath(path);

      // For now, use a simple scaling approach that fits the image to the dest bounds
      final destBounds = _getBoundingRect(adjustedDest);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destBounds,
        Paint()..filterQuality = FilterQuality.high,
      );

      canvas.restore();

      final picture = recorder.endRecording();
      return await picture.toImage(outputWidth, outputHeight);
    } catch (e) {
      debugPrint('Error applying perspective transform: $e');
      return null;
    }
  }

  /// Apply rotation transformation to an image
  /// Uses ImageUtils.rotateBitmap for consistency with Java implementation
  static Future<ui.Image?> _applyRotationTransform(
      ui.Image image, Map<String, dynamic>? params) async {
    if (params == null || !params.containsKey('angle')) return image;

    try {
      final angle = (params['angle'] as num).toDouble();

      // Use ImageUtils for consistent rotation with Java implementation
      // Note: ImageUtils.rotateBitmap handles dimension calculation and trimming
      return await ImageUtils.rotateBitmap(image, angle, recycle: false);
    } catch (e) {
      debugPrint('Error applying rotation transform: $e');
      return null;
    }
  }

  /// Apply scale transformation to an image
  /// Uses ImageUtils.scaleBitmap for consistency with Java implementation
  static Future<ui.Image?> _applyScaleTransform(
      ui.Image image, Map<String, dynamic>? params) async {
    if (params == null) return image;

    try {
      final scaleX = (params['scaleX'] as num?)?.toDouble() ?? 1.0;
      final scaleY = (params['scaleY'] as num?)?.toDouble() ?? scaleX;

      final newWidth = (image.width * scaleX).toInt();
      final newHeight = (image.height * scaleY).toInt();

      if (newWidth <= 0 || newHeight <= 0) return image;

      // Use ImageUtils for consistent scaling with Java implementation
      return await ImageUtils.scaleBitmap(image, newWidth, newHeight);
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

  /// Check if a project can be reprocessed (has existing processed slices)
  static Future<bool> canReprocess(
      String projectPath, String templatePath) async {
    final status = await getProcessingStatus(projectPath, templatePath);
    return status.isProcessed && status.processedSlices > 0;
  }

  /// Get a simple boolean indicating if any slices exist for a project
  static Future<bool> hasProcessedSlices(String projectPath) async {
    try {
      final projectDir =
          Directory('${MagicManager.instance.workDir.path}/$projectPath');
      if (!projectDir.existsSync()) return false;

      // Check if any subdirectories contain .png files
      final subdirs = projectDir.listSync().whereType<Directory>();
      for (final subdir in subdirs) {
        final pngFiles = subdir.listSync().where(
            (file) => file is File && file.path.toLowerCase().endsWith('.png'));
        if (pngFiles.isNotEmpty) return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking for processed slices: $e');
      return false;
    }
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

  /// Apply simple rotation by angle (used for page layout rotations)
  /// Uses ImageUtils.rotateBitmap for consistency with Java implementation
  static Future<ui.Image?> rotateImage(
      ui.Image image, double angleDegrees) async {
    if (angleDegrees == 0) return image;

    try {
      // Use ImageUtils for consistent rotation with Java implementation
      return await ImageUtils.rotateBitmap(image, angleDegrees, recycle: false);
    } catch (e) {
      debugPrint('Error rotating image: $e');
      return null;
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
