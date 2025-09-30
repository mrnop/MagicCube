import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flutter equivalent of the Java Utils class for image manipulation
/// Provides consistent image processing functionality aligned with Java implementation
class ImageUtils {
  /// Scales the provided image to have the height and width provided.
  /// Flutter equivalent of Utils.scaleBitmap(Bitmap bitmap, int newWidth, int newHeight)
  /// Uses high-quality scaling with proper filtering
  static Future<ui.Image?> scaleBitmap(
      ui.Image image, int newWidth, int newHeight) async {
    try {
      if (newWidth <= 0 || newHeight <= 0) return null;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()));

      // Calculate scale factors like Java implementation
      final scaleX = newWidth / image.width.toDouble();
      final scaleY = newHeight / image.height.toDouble();

      // Apply scaling transformation
      canvas.save();
      canvas.scale(scaleX, scaleY);

      // Draw with high quality filtering (equivalent to Paint.FILTER_BITMAP_FLAG)
      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImage(image, Offset.zero, paint);
      canvas.restore();

      final picture = recorder.endRecording();
      return await picture.toImage(newWidth, newHeight);
    } catch (e) {
      debugPrint('Error scaling bitmap: $e');
      return null;
    }
  }

  /// Scales bitmap by a scale factor, with option to recycle original
  /// Flutter equivalent of Utils.scaleBitmap(Bitmap source, float scale, boolean recycle)
  static Future<ui.Image?> scaleBitmapByFactor(ui.Image source, double scale,
      {bool recycle = true}) async {
    try {
      final newWidth = (source.width * scale).round();
      final newHeight = (source.height * scale).round();

      final scaledImage = await scaleBitmap(source, newWidth, newHeight);

      // Note: In Flutter, we don't have explicit bitmap recycling like Android
      // The garbage collector handles image memory automatically
      if (recycle) {
        source.dispose();
      }

      return scaledImage;
    } catch (e) {
      debugPrint('Error scaling bitmap by factor: $e');
      return null;
    }
  }

  /// Scales bitmap by a scale factor (recycle = true by default)
  /// Flutter equivalent of Utils.scaleBitmap(Bitmap source, float scale)
  static Future<ui.Image?> scaleBitmapByFactorSimple(
      ui.Image source, double scale) async {
    return await scaleBitmapByFactor(source, scale, recycle: true);
  }

  /// Rotates bitmap by angle with option to recycle original
  /// Flutter equivalent of Utils.rotateBitmap(Bitmap source, float angle, boolean recycle)
  static Future<ui.Image?> rotateBitmap(ui.Image source, double angle,
      {bool recycle = true}) async {
    try {
      if (angle == 0) return source;

      final radians = angle * (math.pi / 180.0);

      // Calculate new dimensions after rotation (like Java implementation)
      final cosAngle = math.cos(radians).abs();
      final sinAngle = math.sin(radians).abs();

      final newWidth =
          (source.width * cosAngle + source.height * sinAngle).round();
      final newHeight =
          (source.width * sinAngle + source.height * cosAngle).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder,
          Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()));

      // Clear background (equivalent to transparent bitmap creation)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        Paint()..color = Colors.transparent,
      );

      // Apply rotation around center (like Java Matrix.setRotate)
      canvas.translate(newWidth / 2.0, newHeight / 2.0);
      canvas.rotate(radians);
      canvas.translate(-source.width / 2.0, -source.height / 2.0);

      final paint = Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true;

      canvas.drawImage(source, Offset.zero, paint);

      final picture = recorder.endRecording();
      final rotatedImage = await picture.toImage(newWidth, newHeight);

      // Apply trim like Java implementation
      final trimmedImage = await trim(rotatedImage);

      if (recycle) {
        source.dispose();
      }

      return trimmedImage ?? rotatedImage;
    } catch (e) {
      debugPrint('Error rotating bitmap: $e');
      return null;
    }
  }

  /// Rotates bitmap by angle (recycle = true by default)
  /// Flutter equivalent of Utils.rotateBitmap(Bitmap source, float angle)
  static Future<ui.Image?> rotateBitmapSimple(
      ui.Image source, double angle) async {
    return await rotateBitmap(source, angle, recycle: true);
  }

  /// Trims transparent pixels from bitmap edges
  /// Flutter equivalent of Utils.trim(Bitmap source)
  static Future<ui.Image?> trim(ui.Image source) async {
    try {
      // Get pixel data from image
      final byteData =
          await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint32List();
      final width = source.width;
      final height = source.height;

      int firstX = 0, firstY = 0;
      int lastX = width;
      int lastY = height;

      // Find first non-transparent pixel from left (like Java loop)
      bool found = false;
      for (int x = 0; x < width && !found; x++) {
        for (int y = 0; y < height; y++) {
          final pixel = pixels[y * width + x];
          if ((pixel & 0xFF000000) != 0) {
            // Check alpha channel
            firstX = x;
            found = true;
            break;
          }
        }
      }

      // Find first non-transparent pixel from top
      found = false;
      for (int y = 0; y < height && !found; y++) {
        for (int x = firstX; x < width; x++) {
          final pixel = pixels[y * width + x];
          if ((pixel & 0xFF000000) != 0) {
            firstY = y;
            found = true;
            break;
          }
        }
      }

      // Find last non-transparent pixel from right
      found = false;
      for (int x = width - 1; x >= firstX && !found; x--) {
        for (int y = height - 1; y >= firstY; y--) {
          final pixel = pixels[y * width + x];
          if ((pixel & 0xFF000000) != 0) {
            lastX = x + 1; // +1 because we need the boundary
            found = true;
            break;
          }
        }
      }

      // Find last non-transparent pixel from bottom
      found = false;
      for (int y = height - 1; y >= firstY && !found; y--) {
        for (int x = width - 1; x >= firstX; x--) {
          final pixel = pixels[y * width + x];
          if ((pixel & 0xFF000000) != 0) {
            lastY = y + 1; // +1 because we need the boundary
            found = true;
            break;
          }
        }
      }

      // Create trimmed image if bounds are valid
      final trimmedWidth = lastX - firstX;
      final trimmedHeight = lastY - firstY;

      if (trimmedWidth <= 0 || trimmedHeight <= 0) {
        return source; // Return original if nothing to trim
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder,
          Rect.fromLTWH(
              0, 0, trimmedWidth.toDouble(), trimmedHeight.toDouble()));

      // Draw the cropped portion
      canvas.drawImageRect(
        source,
        Rect.fromLTWH(firstX.toDouble(), firstY.toDouble(),
            trimmedWidth.toDouble(), trimmedHeight.toDouble()),
        Rect.fromLTWH(0, 0, trimmedWidth.toDouble(), trimmedHeight.toDouble()),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final trimmedImage = await picture.toImage(trimmedWidth, trimmedHeight);

      // Dispose original image (like Java recycle)
      source.dispose();

      return trimmedImage;
    } catch (e) {
      debugPrint('Error trimming bitmap: $e');
      return source;
    }
  }

  /// Creates a contrast-adjusted image
  /// Flutter equivalent of Utils.createContrast(Bitmap src, double value)
  static Future<ui.Image?> createContrast(ui.Image src, double value) async {
    try {
      // Get pixel data
      final byteData = await src.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;

      final pixels = byteData.buffer.asUint8List();
      final width = src.width;
      final height = src.height;

      // Calculate contrast value (like Java implementation)
      final contrast = math.pow((100 + value) / 100, 2).toDouble();

      // Process each pixel
      for (int i = 0; i < pixels.length; i += 4) {
        // Get RGBA values
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        final a = pixels[i + 3];

        // Apply contrast to RGB channels (like Java implementation)
        int newR = ((((r / 255.0 - 0.5) * contrast) + 0.5) * 255.0).round();
        int newG = ((((g / 255.0 - 0.5) * contrast) + 0.5) * 255.0).round();
        int newB = ((((b / 255.0 - 0.5) * contrast) + 0.5) * 255.0).round();

        // Clamp values to 0-255 range
        newR = math.max(0, math.min(255, newR));
        newG = math.max(0, math.min(255, newG));
        newB = math.max(0, math.min(255, newB));

        // Set new pixel values
        pixels[i] = newR;
        pixels[i + 1] = newG;
        pixels[i + 2] = newB;
        pixels[i + 3] = a; // Keep original alpha
      }

      // Create new image from modified pixels
      final codec = await ui.instantiateImageCodec(pixels,
          targetWidth: width, targetHeight: height);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error creating contrast: $e');
      return null;
    }
  }

  /// Converts image to grayscale
  /// Flutter equivalent of Utils.toGrayscale(Bitmap bmpOriginal)
  static Future<ui.Image?> toGrayscale(ui.Image bmpOriginal) async {
    try {
      final width = bmpOriginal.width;
      final height = bmpOriginal.height;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

      // Create grayscale color filter (like Java ColorMatrix.setSaturation(0))
      final paint = Paint()
        ..colorFilter = const ColorFilter.matrix([
          0.2989, 0.5870, 0.1140, 0, 0, // Red channel
          0.2989, 0.5870, 0.1140, 0, 0, // Green channel
          0.2989, 0.5870, 0.1140, 0, 0, // Blue channel
          0, 0, 0, 1, 0, // Alpha channel
        ]);

      canvas.drawImage(bmpOriginal, Offset.zero, paint);

      final picture = recorder.endRecording();
      return await picture.toImage(width, height);
    } catch (e) {
      debugPrint('Error converting to grayscale: $e');
      return null;
    }
  }

  /// Loads bitmap from asset path
  /// Flutter equivalent of Utils.getBitmapFromAsset(Context context, String filePath)
  static Future<ui.Image?> getBitmapFromAsset(String filePath) async {
    try {
      final data = await rootBundle.load(filePath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error loading bitmap from asset: $e');
      return null;
    }
  }

  /// Creates a tiled bitmap pattern
  /// Flutter equivalent of Utils.tileBitmap(BitmapDrawable src, int width, int height)
  static Future<ui.Image?> tileBitmap(
      ui.Image src, int width, int height) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
          recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

      final paint = Paint()..filterQuality = FilterQuality.high;

      // Tile the source image across the canvas
      final srcWidth = src.width.toDouble();
      final srcHeight = src.height.toDouble();

      for (double y = 0; y < height; y += srcHeight) {
        for (double x = 0; x < width; x += srcWidth) {
          canvas.drawImage(src, Offset(x, y), paint);
        }
      }

      final picture = recorder.endRecording();
      return await picture.toImage(width, height);
    } catch (e) {
      debugPrint('Error tiling bitmap: $e');
      return null;
    }
  }

  /// Loads bitmap from file with automatic EXIF orientation correction
  /// Flutter equivalent of Utils.loadBitmap(File file)
  /// Note: EXIF handling would require additional packages in Flutter
  static Future<ui.Image?> loadBitmapFromFile(String filePath) async {
    try {
      final file = await rootBundle.load(filePath);
      final codec = await ui.instantiateImageCodec(file.buffer.asUint8List());
      final frame = await codec.getNextFrame();

      // Note: In Flutter, automatic EXIF rotation is typically handled
      // by the image_picker package or similar libraries
      // For manual EXIF handling, you would need the exif package

      return frame.image;
    } catch (e) {
      debugPrint('Error loading bitmap from file: $e');
      return null;
    }
  }
}
