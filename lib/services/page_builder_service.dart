import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/magic.dart';
import '../models/page.dart';
import '../services/magic_manager.dart';

/// Result of page building operation
class PagePreview {
  final Page page;
  final ui.Image image;
  final String? fileName;

  PagePreview({
    required this.page,
    required this.image,
    this.fileName,
  });
}

/// Service for building page previews from magic templates
class PageBuilderService {
  /// Build page previews for a project with page selection dialog
  static Future<List<PagePreview>?> buildProjectPages({
    required String projectName,
    required String magicPath,
    required BuildContext context,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Loading available pages...');

      // Load all available pages for the magic template
      final availablePages = await MagicManager.instance.listPages(magicPath);

      if (availablePages.isEmpty) {
        // Try to create a default page if no pages are found
        onProgress?.call('No page templates found, creating default page...');
        return await _buildDefaultPage(
          projectName: projectName,
          magicPath: magicPath,
          onProgress: onProgress,
        );
      }

      // If more than one page, show selection dialog
      String? selectedPagePath;
      if (availablePages.length > 1) {
        selectedPagePath =
            await _showPageSelectionDialog(context, availablePages);
        if (selectedPagePath == null) {
          // User cancelled
          return null;
        }
      } else {
        selectedPagePath = availablePages.first.path!;
      }

      onProgress?.call('Building page preview for $selectedPagePath...');

      // Build the selected page
      return await _buildPagesForTemplate(
        projectName: projectName,
        magicPath: magicPath,
        selectedPagePath: selectedPagePath,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('Error building project pages: $e');
      rethrow;
    }
  }

  /// Show dialog to select page template when multiple pages are available
  static Future<String?> _showPageSelectionDialog(
    BuildContext context,
    List<PageHead> availablePages,
  ) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.article_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Choose Page Template'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availablePages.length,
            itemBuilder: (context, index) {
              final page = availablePages[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    page.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(page.description),
                      const SizedBox(height: 4),
                      Text(
                        '${page.pages.length} page(s) • ${page.width}x${page.height}px',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => Navigator.pop(context, page.path),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Build pages for specific template and page path
  static Future<List<PagePreview>> _buildPagesForTemplate({
    required String projectName,
    required String magicPath,
    required String selectedPagePath,
    void Function(String message)? onProgress,
  }) async {
    final List<PagePreview> previews = [];

    try {
      // Create build directory
      final workDir = MagicManager.instance.workDir;
      final buildDir = Directory(path.join(workDir.path, projectName, 'build'));
      if (!buildDir.existsSync()) {
        buildDir.createSync(recursive: true);
      }

      // Load page head and magic template
      final pageHead =
          await MagicManager.instance.loadPage(magicPath, selectedPagePath);
      final magic = await MagicManager.instance.loadMagic(magicPath);

      if (pageHead == null || magic == null) {
        throw Exception('Failed to load page or magic template');
      }

      onProgress?.call('Processing ${pageHead.pages.length} page(s)...');

      // Process each page in the page head
      for (int pageIndex = 0; pageIndex < pageHead.pages.length; pageIndex++) {
        final page = pageHead.pages[pageIndex];

        onProgress?.call(
            'Building page ${pageIndex + 1}/${pageHead.pages.length}...');

        try {
          final preview = await _buildSinglePage(
            page: page,
            pageHead: pageHead,
            magic: magic,
            magicPath: magicPath,
            selectedPagePath: selectedPagePath,
            projectName: projectName,
          );

          if (preview != null) {
            previews.add(preview);
          }
        } catch (e) {
          debugPrint('Error building page ${pageIndex + 1}: $e');
          // Continue with other pages
        }
      }

      onProgress?.call('Completed building ${previews.length} page preview(s)');
      return previews;
    } catch (e) {
      debugPrint('Error in _buildPagesForTemplate: $e');
      rethrow;
    }
  }

  /// Build a single page preview
  static Future<PagePreview?> _buildSinglePage({
    required Page page,
    required PageHead pageHead,
    required Magic magic,
    required String magicPath,
    required String selectedPagePath,
    required String projectName,
  }) async {
    try {
      // Load template image
      ui.Image? templateImage =
          await _loadTemplateImage(magicPath, selectedPagePath, page.file);
      if (templateImage == null) {
        debugPrint('Failed to load template image: ${page.file}');
        return null;
      }

      // Calculate scaling
      final templateHeight = templateImage.height.toDouble();
      final printScale =
          pageHead.width.toDouble() / templateImage.width.toDouble();

      // Scale template image
      templateImage = await _scaleImage(templateImage, printScale);
      if (templateImage == null) {
        debugPrint('Failed to scale template image');
        return null;
      }

      // Create work bitmap
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder,
          Rect.fromLTWH(
              0, 0, pageHead.width.toDouble(), pageHead.height.toDouble()));

      // Fill with white background
      canvas.drawRect(
        Rect.fromLTWH(
            0, 0, pageHead.width.toDouble(), pageHead.height.toDouble()),
        Paint()..color = Colors.white,
      );

      // Build faces on the page
      for (final face in page.faces) {
        await _buildFace(
          canvas: canvas,
          projectName: projectName,
          magic: magic,
          face: face,
          templateHeight: templateHeight,
          printScale: printScale,
          offsetX: page.offsetX,
          offsetY: page.offsetY,
          scale: pageHead.scale,
          dpi: pageHead.dpi.toDouble(),
          grid: pageHead.grid,
        );
      }

      // Build sections
      for (final section in page.sections) {
        for (final face in section.faces) {
          await _buildFace(
            canvas: canvas,
            projectName: projectName,
            magic: magic,
            face: face,
            templateHeight: templateHeight,
            printScale: printScale,
            offsetX: section.offsetX,
            offsetY: section.offsetY,
            scale: section.scale,
            dpi: section.dpi.toDouble(),
            grid: section.grid,
          );
        }
      }

      // Add text faces
      if (page.texts.isNotEmpty) {
        await _addTextFaces(
          canvas: canvas,
          magic: magic,
          textFaces: page.texts,
          pageHead: pageHead,
          page: page,
          templateHeight: templateHeight,
          printScale: printScale,
        );
      }

      // Add watermarks (only if not VIP)
      if (!MagicManager.instance.isVip && page.watermarks.isNotEmpty) {
        await _addWatermarks(
          canvas: canvas,
          watermarks: page.watermarks,
          magicPath: magicPath,
          selectedPagePath: selectedPagePath,
          pageHead: pageHead,
          page: page,
          templateHeight: templateHeight,
          printScale: printScale,
        );
      }

      // Draw template on top
      canvas.drawImage(templateImage, Offset.zero, Paint());

      // Convert to image
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(pageHead.width, pageHead.height);

      return PagePreview(
        page: page,
        image: finalImage,
        fileName: 'page_${page.id}.png',
      );
    } catch (e) {
      debugPrint('Error building single page: $e');
      return null;
    }
  }

  /// Build a face on the canvas
  static Future<void> _buildFace({
    required Canvas canvas,
    required String projectName,
    required Magic magic,
    required PageFace face,
    required double templateHeight,
    required double printScale,
    required double offsetX,
    required double offsetY,
    required double scale,
    required double dpi,
    required double grid,
  }) async {
    try {
      // Find the slice and source
      MagicSlice? slice;
      MagicSource? source;

      for (final src in magic.sources) {
        if (src.id == face.source) {
          source = src;
          for (final sl in src.slices) {
            if (sl.id == face.slice) {
              slice = sl;
              break;
            }
          }
          break;
        }
      }

      if (slice == null || source == null) {
        debugPrint(
            'Slice or source not found: source=${face.source}, slice=${face.slice}');
        return;
      }

      // Load slice bitmap
      ui.Image? sliceImage = await MagicManager.instance
          .loadSlice(projectName, source.id, slice.id);
      if (sliceImage == null) {
        debugPrint(
            'Failed to load slice image: source=${source.id}, slice=${slice.id}');
        return;
      }

      // Apply face transforms
      for (final transform in face.transforms) {
        if (sliceImage != null) {
          sliceImage = await _applyTransform(sliceImage, transform);
          if (sliceImage == null) break;
        }
      }

      if (sliceImage == null) return;

      // Apply face rotation
      if (face.angle != 0) {
        sliceImage = await _rotateImage(sliceImage, face.angle);
        if (sliceImage == null) return;
      }

      // Apply scaling
      final finalScale = scale != 1 ? scale * printScale : printScale;
      sliceImage = await _scaleImage(sliceImage, finalScale);
      if (sliceImage == null) return;

      // Calculate position
      double x, y;
      if (offsetY > 0) {
        x = (offsetX / 96 + (face.x * grid / 96)) * printScale * dpi;
        y = ((templateHeight - offsetY / 96 * dpi) +
                ((face.y * grid / 96) * dpi)) *
            printScale;
      } else if (offsetX > 0) {
        x = (offsetX / 96 + (face.x * grid / 96)) * printScale * dpi;
        y = (templateHeight - ((face.y / 96) * grid * dpi)) * printScale;
      } else {
        x = (face.x / 96) * grid * printScale * dpi;
        y = (templateHeight - ((face.y / 96) * grid * dpi)) * printScale;
      }

      // Draw the slice
      canvas.drawImage(sliceImage, Offset(x, y), Paint());
    } catch (e) {
      debugPrint('Error building face: $e');
    }
  }

  /// Add text faces to canvas
  static Future<void> _addTextFaces({
    required Canvas canvas,
    required Magic magic,
    required List<PageTextFace> textFaces,
    required PageHead pageHead,
    required Page page,
    required double templateHeight,
    required double printScale,
  }) async {
    for (final textFace in textFaces) {
      try {
        // Find magic text
        MagicText? text;
        for (final txt in magic.texts) {
          if (txt.id == textFace.text) {
            text = txt;
            break;
          }
        }

        if (text == null) continue;

        // Create text bitmap
        ui.Image? textImage = await _createTextImage(text);
        if (textImage == null) continue;

        // Apply rotation
        if (textFace.angle != 0) {
          textImage = await _rotateImage(textImage, textFace.angle);
          if (textImage == null) continue;
        }

        // Calculate position
        double x, y;
        if (page.offsetY > 0) {
          x = (page.offsetX / 96 + (textFace.x * pageHead.grid / 96)) *
              printScale *
              pageHead.dpi;
          y = ((templateHeight - page.offsetY / 96 * pageHead.dpi) +
                  ((textFace.y * pageHead.grid / 96) * pageHead.dpi)) *
              printScale;
        } else if (page.offsetX > 0) {
          x = (page.offsetX / 96 + (textFace.x * pageHead.grid / 96)) *
              printScale *
              pageHead.dpi;
          y = (templateHeight -
                  ((textFace.y / 96) * pageHead.grid * pageHead.dpi)) *
              printScale;
        } else {
          x = (textFace.x / 96) * pageHead.grid * printScale * pageHead.dpi;
          y = (templateHeight -
                  ((textFace.y / 96) * pageHead.grid * pageHead.dpi)) *
              printScale;
        }

        canvas.drawImage(textImage, Offset(x, y), Paint());
      } catch (e) {
        debugPrint('Error adding text face: $e');
      }
    }
  }

  /// Add watermarks to canvas
  static Future<void> _addWatermarks({
    required Canvas canvas,
    required List<PageWatermark> watermarks,
    required String magicPath,
    required String selectedPagePath,
    required PageHead pageHead,
    required Page page,
    required double templateHeight,
    required double printScale,
  }) async {
    for (final watermark in watermarks) {
      try {
        // Load watermark image
        ui.Image? watermarkImage = await _loadTemplateImage(
            magicPath, selectedPagePath, watermark.src);
        if (watermarkImage == null) {
          // Use default watermark if available
          watermarkImage = await _loadDefaultWatermark();
          if (watermarkImage == null) continue;
        }

        // Apply scale
        if (watermark.scale != 1) {
          watermarkImage = await _scaleImage(watermarkImage, watermark.scale);
          if (watermarkImage == null) continue;
        }

        // Apply rotation
        if (watermark.angle != 0) {
          watermarkImage = await _rotateImage(watermarkImage, watermark.angle);
          if (watermarkImage == null) continue;
        }

        // Calculate position
        double x, y;
        if (page.offsetY > 0) {
          x = (page.offsetX / 96 + (watermark.x * pageHead.grid / 96)) *
              printScale *
              pageHead.dpi;
          y = ((templateHeight - page.offsetY / 96 * pageHead.dpi) +
                  ((watermark.y * pageHead.grid / 96) * pageHead.dpi)) *
              printScale;
        } else if (page.offsetX > 0) {
          x = (page.offsetX / 96 + (watermark.x * pageHead.grid / 96)) *
              printScale *
              pageHead.dpi;
          y = (templateHeight -
                  ((watermark.y / 96) * pageHead.grid * pageHead.dpi)) *
              printScale;
        } else {
          x = (watermark.x / 96) * pageHead.grid * printScale * pageHead.dpi;
          y = (templateHeight -
                  ((watermark.y / 96) * pageHead.grid * pageHead.dpi)) *
              printScale;
        }

        canvas.drawImage(watermarkImage, Offset(x, y), Paint());
      } catch (e) {
        debugPrint('Error adding watermark: $e');
      }
    }
  }

  /// Build a default page when no page templates are found
  static Future<List<PagePreview>?> _buildDefaultPage({
    required String projectName,
    required String magicPath,
    void Function(String message)? onProgress,
  }) async {
    try {
      onProgress?.call('Building default page for $magicPath...');

      // Load magic template to get basic information
      final magic = await MagicManager.instance.loadMagic(magicPath);
      if (magic == null) {
        throw Exception('Failed to load magic template $magicPath');
      }

      // Create a simple default page
      final defaultPage = Page(
        id: 1,
        file: 'default.png', // This might not exist, but we'll handle it
        faces: [], // No faces for now - could be extended
        offsetX: 0,
        offsetY: 0,
      );

      // Create a simple canvas with template info
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 600));

      // Fill with white background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 800, 600),
        Paint()..color = Colors.white,
      );

      // Draw template information
      final textPainter = TextPainter(
        text: TextSpan(
          text:
              'Template: ${magic.name}\n\nNo page templates found.\nProcessed slices can be exported\ndirectly from the Export function.',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: 700);
      textPainter.paint(canvas, const Offset(50, 100));

      // Draw a border
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 800, 600),
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(800, 600);

      return [
        PagePreview(
          page: defaultPage,
          image: image,
          fileName: 'default_page.png',
        ),
      ];
    } catch (e) {
      debugPrint('Error building default page: $e');
      return null;
    }
  }

  /// Helper methods for image operations
  static Future<ui.Image?> _loadTemplateImage(
      String magicPath, String pagePath, String fileName) async {
    try {
      final assetPath = 'assets/magics/$magicPath/pages/$pagePath/$fileName';
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Failed to load template image $fileName: $e');
      return null;
    }
  }

  static Future<ui.Image?> _loadDefaultWatermark() async {
    try {
      // Try to load a default watermark from assets
      final data = await rootBundle.load('assets/default_watermark.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('No default watermark available');
      return null;
    }
  }

  static Future<ui.Image?> _scaleImage(ui.Image image, double scale) async {
    try {
      if (scale == 1.0) return image;

      final newWidth = (image.width * scale).toInt();
      final newHeight = (image.height * scale).toInt();

      if (newWidth <= 0 || newHeight <= 0) return image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()));

      canvas.scale(scale);
      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      return await picture.toImage(newWidth, newHeight);
    } catch (e) {
      debugPrint('Error scaling image: $e');
      return null;
    }
  }

  static Future<ui.Image?> _rotateImage(
      ui.Image image, double angleDegrees) async {
    try {
      if (angleDegrees == 0) return image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final centerX = image.width / 2.0;
      final centerY = image.height / 2.0;

      canvas.translate(centerX, centerY);
      canvas.rotate(angleDegrees * 3.14159 / 180.0);
      canvas.translate(-centerX, -centerY);

      canvas.drawImage(image, Offset.zero, Paint());

      final picture = recorder.endRecording();
      return await picture.toImage(image.width, image.height);
    } catch (e) {
      debugPrint('Error rotating image: $e');
      return null;
    }
  }

  static Future<ui.Image?> _createTextImage(MagicText text) async {
    try {
      // Calculate bounding box from polygon
      if (text.polygon.isEmpty) return null;

      double minX = text.polygon.first.x.toDouble();
      double maxX = minX;
      double minY = text.polygon.first.y.toDouble();
      double maxY = minY;

      for (final point in text.polygon) {
        minX = minX < point.x ? minX : point.x.toDouble();
        maxX = maxX > point.x ? maxX : point.x.toDouble();
        minY = minY < point.y ? minY : point.y.toDouble();
        maxY = maxY > point.y ? maxY : point.y.toDouble();
      }

      final width = (maxX - minX).toInt();
      final height = (maxY - minY).toInt();

      if (width <= 0 || height <= 0) return null;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

      // Create path for text background
      final path = Path();
      bool first = true;
      for (final point in text.polygon) {
        final x = point.x - minX;
        final y = point.y - minY;
        if (first) {
          path.moveTo(x.toDouble(), y.toDouble());
          first = false;
        } else {
          path.lineTo(x.toDouble(), y.toDouble());
        }
      }
      path.close();

      // Fill with background color
      final paint = Paint()
        ..color = Color(
            int.parse(text.background.substring(1), radix: 16) + 0xFF000000)
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      final picture = recorder.endRecording();
      return await picture.toImage(width, height);
    } catch (e) {
      debugPrint('Error creating text image: $e');
      return null;
    }
  }

  static Future<ui.Image?> _applyTransform(
      ui.Image image, MagicTransform transform) async {
    try {
      switch (transform.type) {
        case 'rotate':
          final angle = transform.params['angle']?.toDouble() ?? 0;
          return await _rotateImage(image, angle);
        case 'scale':
          final scaleX = transform.params['scaleX']?.toDouble() ?? 1;
          final scaleY = transform.params['scaleY']?.toDouble() ?? 1;
          final avgScale = (scaleX + scaleY) / 2;
          return await _scaleImage(image, avgScale);
        default:
          debugPrint('Unknown transform type: ${transform.type}');
          return image;
      }
    } catch (e) {
      debugPrint('Error applying transform: $e');
      return null;
    }
  }
}
