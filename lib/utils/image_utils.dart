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

  /// Applies perspective transformation to warp source image to destination quadrilateral
  /// Flutter equivalent of Android's Matrix.setPolyToPoly() for perspective warp
  ///
  /// Parameters:
  /// - source: The source image to transform
  /// - srcQuad: Four corner points of source quadrilateral (top-left, top-right, bottom-right, bottom-left)
  /// - dstQuad: Four corner points of destination quadrilateral (top-left, top-right, bottom-right, bottom-left)
  /// - outputWidth: Width of output image
  /// - outputHeight: Height of output image
  static Future<ui.Image?> warpPerspective(
    ui.Image source,
    List<Offset> srcQuad,
    List<Offset> dstQuad,
    int outputWidth,
    int outputHeight,
  ) async {
    if (srcQuad.length != 4 || dstQuad.length != 4) {
      debugPrint('warpPerspective requires exactly 4 points for src and dst');
      return null;
    }

    try {
      // Calculate the perspective transformation matrix (homography)
      // This maps from destination to source (inverse mapping for sampling)
      final matrix = _calculateHomography(dstQuad, srcQuad);
      if (matrix == null) {
        debugPrint('Failed to calculate homography matrix');
        return null;
      }

      // Get source pixel data
      final srcByteData =
          await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (srcByteData == null) return null;

      final srcPixels = srcByteData.buffer.asUint8List();
      final srcWidth = source.width;
      final srcHeight = source.height;

      // Create output pixel buffer
      final dstPixels = Uint8List(outputWidth * outputHeight * 4);

      // Apply perspective transformation by inverse mapping
      for (int y = 0; y < outputHeight; y++) {
        for (int x = 0; x < outputWidth; x++) {
          // Map destination pixel (x,y) to source coordinates using homography
          final srcPoint = _applyHomography(matrix, x.toDouble(), y.toDouble());
          final srcX = srcPoint.dx;
          final srcY = srcPoint.dy;

          // Check if source coordinates are within bounds
          if (srcX >= 0 &&
              srcX < srcWidth - 1 &&
              srcY >= 0 &&
              srcY < srcHeight - 1) {
            // Bilinear interpolation for smooth sampling
            final color =
                _bilinearSample(srcPixels, srcWidth, srcHeight, srcX, srcY);

            final dstIndex = (y * outputWidth + x) * 4;
            dstPixels[dstIndex] = color[0]; // R
            dstPixels[dstIndex + 1] = color[1]; // G
            dstPixels[dstIndex + 2] = color[2]; // B
            dstPixels[dstIndex + 3] = color[3]; // A
          }
          // else: pixel remains transparent (default 0)
        }
      }

      // Create image from pixel data
      final codec = await ui.instantiateImageCodec(
        dstPixels,
        targetWidth: outputWidth,
        targetHeight: outputHeight,
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error in warpPerspective: $e');
      return null;
    }
  }

  /// Calculate 3x3 homography matrix from source to destination quad
  /// Using Direct Linear Transform (DLT) algorithm
  static List<double>? _calculateHomography(
      List<Offset> src, List<Offset> dst) {
    // We need to solve for 8 unknowns (h11..h33, with h33=1 for normalization)
    // Each point correspondence gives us 2 equations
    // 4 points give us 8 equations

    // Build the equation matrix A and vector b for Ah = b
    final a = List.generate(8, (_) => List.filled(8, 0.0));
    final b = List.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final sx = src[i].dx;
      final sy = src[i].dy;
      final dx = dst[i].dx;
      final dy = dst[i].dy;

      // First equation for this point
      a[i * 2][0] = sx;
      a[i * 2][1] = sy;
      a[i * 2][2] = 1;
      a[i * 2][6] = -dx * sx;
      a[i * 2][7] = -dx * sy;
      b[i * 2] = dx;

      // Second equation for this point
      a[i * 2 + 1][3] = sx;
      a[i * 2 + 1][4] = sy;
      a[i * 2 + 1][5] = 1;
      a[i * 2 + 1][6] = -dy * sx;
      a[i * 2 + 1][7] = -dy * sy;
      b[i * 2 + 1] = dy;
    }

    // Solve using Gaussian elimination
    final h = _gaussianElimination(a, b);
    if (h == null) return null;

    // Construct 3x3 homography matrix
    // [h[0], h[1], h[2]]
    // [h[3], h[4], h[5]]
    // [h[6], h[7],   1 ]
    return [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0];
  }

  /// Solve linear system using Gaussian elimination with partial pivoting
  static List<double>? _gaussianElimination(
      List<List<double>> a, List<double> b) {
    final n = a.length;
    final aug = List.generate(
        n, (i) => List<double>.from([...a[i], b[i]])); // Augmented matrix

    // Forward elimination with partial pivoting
    for (int col = 0; col < n; col++) {
      // Find pivot
      int maxRow = col;
      for (int row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > aug[maxRow][col].abs()) {
          maxRow = row;
        }
      }

      // Swap rows
      if (maxRow != col) {
        final temp = aug[col];
        aug[col] = aug[maxRow];
        aug[maxRow] = temp;
      }

      // Check for singular matrix
      if (aug[col][col].abs() < 1e-10) {
        return null;
      }

      // Eliminate column
      for (int row = col + 1; row < n; row++) {
        final factor = aug[row][col] / aug[col][col];
        for (int j = col; j <= n; j++) {
          aug[row][j] -= factor * aug[col][j];
        }
      }
    }

    // Back substitution
    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      x[i] /= aug[i][i];
    }

    return x;
  }

  /// Apply homography matrix to transform a point
  static Offset _applyHomography(List<double> h, double x, double y) {
    // Homography transformation:
    // x' = (h[0]*x + h[1]*y + h[2]) / (h[6]*x + h[7]*y + h[8])
    // y' = (h[3]*x + h[4]*y + h[5]) / (h[6]*x + h[7]*y + h[8])
    final w = h[6] * x + h[7] * y + h[8];
    final newX = (h[0] * x + h[1] * y + h[2]) / w;
    final newY = (h[3] * x + h[4] * y + h[5]) / w;
    return Offset(newX, newY);
  }

  /// Bilinear interpolation for smooth pixel sampling
  static List<int> _bilinearSample(
      Uint8List pixels, int width, int height, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final dx = x - x0;
    final dy = y - y0;

    // Get the four surrounding pixels
    final p00 = _getPixel(pixels, width, height, x0, y0);
    final p10 = _getPixel(pixels, width, height, x1, y0);
    final p01 = _getPixel(pixels, width, height, x0, y1);
    final p11 = _getPixel(pixels, width, height, x1, y1);

    // Interpolate
    final result = List.filled(4, 0);
    for (int c = 0; c < 4; c++) {
      final v0 = p00[c] * (1 - dx) + p10[c] * dx;
      final v1 = p01[c] * (1 - dx) + p11[c] * dx;
      result[c] = (v0 * (1 - dy) + v1 * dy).round();
    }

    return result;
  }

  /// Get pixel color at coordinates (with bounds checking)
  static List<int> _getPixel(
      Uint8List pixels, int width, int height, int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return [0, 0, 0, 0]; // Transparent black
    }

    final index = (y * width + x) * 4;
    return [
      pixels[index], // R
      pixels[index + 1], // G
      pixels[index + 2], // B
      pixels[index + 3], // A
    ];
  }
}
