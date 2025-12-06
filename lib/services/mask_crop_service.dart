import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

/// Service that handles mask-based image cropping for Magic Cube templates
/// This provides template-specific cropping using mask overlays
class MaskCropService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image and crop it using a template mask
  static Future<File?> pickAndCropWithMask({
    required BuildContext context,
    required String maskAssetPath,
    String? title,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // Step 1: Pick image from gallery or camera
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      // Step 2: Load the mask image
      final maskImage = await loadMaskFromAssets(maskAssetPath);
      if (maskImage == null) {
        // Fallback to regular crop if mask loading fails
        return File(pickedFile.path);
      }

      // Step 3: Open mask crop screen
      if (!context.mounted) return null;

      final croppedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (context) => MaskCropScreen(
            imagePath: pickedFile.path,
            maskImage: maskImage,
            title: title ?? 'Crop Image',
          ),
        ),
      );

      // Clean up the original picked file if cropping was successful
      if (croppedFile != null) {
        try {
          await File(pickedFile.path).delete();
        } catch (e) {
          // Ignore deletion errors for the temporary file
        }
      }

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking and cropping with mask: $e');
      return null;
    }
  }

  /// Load mask image from assets
  static Future<ui.Image?> loadMaskFromAssets(String assetPath) async {
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error loading mask from assets: $e');
      return null;
    }
  }

  /// Crop image for a specific magic template
  static Future<File?> cropForMagicTemplate({
    required BuildContext context,
    required String templatePath,
    String? title,
    ImageSource source = ImageSource.gallery,
    int sourceId = 1,
  }) async {
    // Load template metadata to get the correct mask
    final maskPath = await getMaskPathFromTemplate(templatePath, sourceId);
    if (maskPath == null) {
      debugPrint(
          'No mask found for template: $templatePath, sourceId: $sourceId');
      return null;
    }

    if (!context.mounted) return null;

    return await pickAndCropWithMask(
      context: context,
      maskAssetPath: maskPath,
      title: title ?? 'Crop for Template',
      source: source,
    );
  }

  /// Load template metadata and get the mask path for a specific source
  static Future<String?> getMaskPathFromTemplate(
      String templatePath, int sourceId) async {
    try {
      final metaData =
          await rootBundle.loadString('assets/magics/$templatePath/meta.json');
      final Map<String, dynamic> meta = json.decode(metaData);

      final List<dynamic>? sources = meta['sources'];
      if (sources == null) return null;

      // Find the source with the matching ID
      for (final source in sources) {
        if (source is Map<String, dynamic> && source['id'] == sourceId) {
          final String? mask = source['mask'];
          if (mask != null) {
            return 'assets/magics/$templatePath/$mask';
          }
        }
      }

      // Fallback to first source if sourceId not found
      if (sources.isNotEmpty) {
        final firstSource = sources.first;
        if (firstSource is Map<String, dynamic>) {
          final String? mask = firstSource['mask'];
          if (mask != null) {
            return 'assets/magics/$templatePath/$mask';
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error loading template metadata: $e');
      return null;
    }
  }

  /// Show image source dialog and crop with template mask
  static Future<File?> showImageSourceDialogWithTemplate({
    required BuildContext context,
    required String templatePath,
    String? title,
    int sourceId = 1,
  }) async {
    return await showModalBottomSheet<File?>(
      context: context,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  if (!context.mounted) return;
                  final result = await cropForMagicTemplate(
                    context: context,
                    templatePath: templatePath,
                    title: title,
                    source: ImageSource.gallery,
                    sourceId: sourceId,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  if (!context.mounted) return;
                  final result = await cropForMagicTemplate(
                    context: context,
                    templatePath: templatePath,
                    title: title,
                    source: ImageSource.camera,
                    sourceId: sourceId,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, result);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show image source dialog and crop with mask (legacy method)
  static Future<File?> showImageSourceDialogWithMask({
    required BuildContext context,
    required String maskAssetPath,
    String? title,
  }) async {
    return await showModalBottomSheet<File?>(
      context: context,
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  if (!context.mounted) return;
                  final result = await pickAndCropWithMask(
                    context: context,
                    maskAssetPath: maskAssetPath,
                    title: title,
                    source: ImageSource.gallery,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, result);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(modalContext);
                  if (!context.mounted) return;
                  final result = await pickAndCropWithMask(
                    context: context,
                    maskAssetPath: maskAssetPath,
                    title: title,
                    source: ImageSource.camera,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context, result);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom crop screen that shows a mask overlay for guided cropping
class MaskCropScreen extends StatefulWidget {
  final String imagePath;
  final ui.Image maskImage;
  final String title;

  const MaskCropScreen({
    super.key,
    required this.imagePath,
    required this.maskImage,
    required this.title,
  });

  @override
  State<MaskCropScreen> createState() => _MaskCropScreenState();
}

class _MaskCropScreenState extends State<MaskCropScreen> {
  ui.Image? _sourceImage;
  Offset _imagePosition = Offset.zero;
  double _imageScale = 1.0;
  bool _isLoading = true;
  double _minScale = 0.1;
  double _maxScale = 5.0;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSourceImage();
  }

  Future<void> _loadSourceImage() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();

      setState(() {
        _sourceImage = frame.image;
        _isLoading = false;
      });

      _centerImage();
    } catch (e) {
      debugPrint('Error loading source image: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _centerImage() {
    if (_sourceImage == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted || !context.mounted) return;

      // Get screen dimensions
      final screenSize = MediaQuery.of(context).size;
      final appBarHeight = AppBar().preferredSize.height;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final bottomBarHeight = 80.0; // Approximate bottom bar height

      final availableHeight =
          screenSize.height - appBarHeight - statusBarHeight - bottomBarHeight;
      final availableWidth = screenSize.width;

      // Calculate scale to fit mask nicely on screen (80% of available space)
      final maskWidth = widget.maskImage.width.toDouble();
      final maskHeight = widget.maskImage.height.toDouble();

      final scaleX = (availableWidth * 0.8) / maskWidth;
      final scaleY = (availableHeight * 0.8) / maskHeight;
      final maskScale = math.min(scaleX, scaleY);

      // Calculate effective mask size on screen
      final effectiveMaskWidth = maskWidth * maskScale;
      final effectiveMaskHeight = maskHeight * maskScale;

      // Calculate scale for the source image
      final sourceWidth = _sourceImage!.width.toDouble();
      final sourceHeight = _sourceImage!.height.toDouble();

      // containScale: fits the whole image inside the mask (black bars)
      // This allows seeing the full image
      final containScaleX = effectiveMaskWidth / sourceWidth;
      final containScaleY = effectiveMaskHeight / sourceHeight;
      final containScale = math.min(containScaleX, containScaleY);

      // coverScale: fills the mask completely (no black bars)
      final coverScaleX = effectiveMaskWidth / sourceWidth;
      final coverScaleY = effectiveMaskHeight / sourceHeight;
      final coverScale = math.max(coverScaleX, coverScaleY);

      setState(() {
        // Allow zooming out until the whole image fits in the mask
        _minScale = containScale * 0.8; // Allow slightly smaller than contain
        _maxScale = math.max(5.0, coverScale * 3.0);

        _imagePosition = Offset.zero;
        // Default to cover for better initial look, but user can zoom out
        _imageScale = coverScale;
      });
    });
  }

  Future<void> _cropAndSave() async {
    if (_sourceImage == null) return;

    try {
      // Get screen dimensions to calculate the scaling factor
      final screenSize = MediaQuery.of(context).size;

      // Calculate the same scale used in the painter
      final maskWidth = widget.maskImage.width.toDouble();
      final maskHeight = widget.maskImage.height.toDouble();

      final scaleX = (screenSize.width * 0.8) / maskWidth;
      final scaleY = (screenSize.height * 0.8) / maskHeight;
      final displayMaskScale = math.min(scaleX, scaleY);

      // Create a custom painter to draw the cropped result
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Set up the output canvas size to match original mask dimensions
      final outputWidth = maskWidth;
      final outputHeight = maskHeight;

      // Calculate the center position
      final centerX = outputWidth / 2;
      final centerY = outputHeight / 2;

      // Convert display coordinates to output coordinates
      final scaleAdjustment = 1.0 / displayMaskScale;
      final adjustedImagePosition = _imagePosition * scaleAdjustment;
      final adjustedImageScale = _imageScale * scaleAdjustment;

      // Draw the source image with adjusted transform
      final paint = Paint()..filterQuality = FilterQuality.high;

      canvas.save();
      canvas.translate(centerX + adjustedImagePosition.dx,
          centerY + adjustedImagePosition.dy);
      canvas.scale(adjustedImageScale);

      // Draw the source image centered
      final sourceRect = Rect.fromLTWH(
        -_sourceImage!.width / 2,
        -_sourceImage!.height / 2,
        _sourceImage!.width.toDouble(),
        _sourceImage!.height.toDouble(),
      );

      canvas.drawImageRect(
        _sourceImage!,
        Rect.fromLTWH(0, 0, _sourceImage!.width.toDouble(),
            _sourceImage!.height.toDouble()),
        sourceRect,
        paint,
      );
      canvas.restore();

      // Apply the mask using XOR blend mode
      canvas.drawImageRect(
        widget.maskImage,
        Rect.fromLTWH(0, 0, widget.maskImage.width.toDouble(),
            widget.maskImage.height.toDouble()),
        Rect.fromLTWH(0, 0, outputWidth, outputHeight),
        Paint()..blendMode = BlendMode.xor,
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(
          widget.maskImage.width, widget.maskImage.height);

      // Convert to bytes and save
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final croppedFile = File(
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png');
      await croppedFile.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      debugPrint('Error cropping and saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _sourceImage != null ? _cropAndSave : null,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _sourceImage == null
              ? const Center(
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : GestureDetector(
                  onScaleStart: (details) {
                    _baseScale = _imageScale;
                  },
                  onScaleUpdate: (details) {
                    setState(() {
                      // Handle scaling (pinch to zoom)
                      if (details.scale != 1.0) {
                        final newScale = _baseScale * details.scale;
                        _imageScale =
                            math.max(_minScale, math.min(_maxScale, newScale));
                      }

                      // Handle panning (drag to move)
                      _imagePosition += details.focalPointDelta;
                    });
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: MaskCropPainter(
                        sourceImage: _sourceImage!,
                        maskImage: widget.maskImage,
                        imagePosition: _imagePosition,
                        imageScale: _imageScale,
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: Container(
        color: Colors.black,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.center_focus_strong,
                      color: Colors.white),
                  onPressed: _centerImage,
                  tooltip: 'Center Image',
                ),
                const Spacer(),
                const Text(
                  'Drag to move • Pinch to zoom',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.crop, color: Colors.white),
                  onPressed: _sourceImage != null ? _cropAndSave : null,
                  tooltip: 'Crop Image',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that renders the source image with mask overlay
class MaskCropPainter extends CustomPainter {
  final ui.Image sourceImage;
  final ui.Image maskImage;
  final Offset imagePosition;
  final double imageScale;

  MaskCropPainter({
    required this.sourceImage,
    required this.maskImage,
    required this.imagePosition,
    required this.imageScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.high;

    // Calculate center position
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate scale to fit mask nicely on screen (80% of available space)
    final maskWidth = maskImage.width.toDouble();
    final maskHeight = maskImage.height.toDouble();

    final scaleX = (size.width * 0.8) / maskWidth;
    final scaleY = (size.height * 0.8) / maskHeight;
    final maskScale = math.min(scaleX, scaleY);

    // Calculate effective mask dimensions
    final effectiveMaskWidth = maskWidth * maskScale;
    final effectiveMaskHeight = maskHeight * maskScale;

    // Draw the source image
    canvas.save();
    canvas.translate(centerX + imagePosition.dx, centerY + imagePosition.dy);
    canvas.scale(imageScale);

    // Center the source image
    final sourceRect = Rect.fromLTWH(
        -sourceImage.width / 2,
        -sourceImage.height / 2,
        sourceImage.width.toDouble(),
        sourceImage.height.toDouble());

    canvas.drawImageRect(
      sourceImage,
      Rect.fromLTWH(
          0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
      sourceRect,
      paint,
    );
    canvas.restore();

    // Draw mask overlay with transparency, scaled to fit screen
    final maskPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..blendMode = BlendMode.srcOver;

    final maskRect = Rect.fromLTWH(
      centerX - effectiveMaskWidth / 2,
      centerY - effectiveMaskHeight / 2,
      effectiveMaskWidth,
      effectiveMaskHeight,
    );

    canvas.drawImageRect(
      maskImage,
      Rect.fromLTWH(0, 0, maskWidth, maskHeight),
      maskRect,
      maskPaint,
    );

    // Draw crop area border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(maskRect, borderPaint);

    // Add corner indicators for better UX
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final cornerSize = 8.0;
    final corners = [
      Offset(maskRect.left, maskRect.top),
      Offset(maskRect.right, maskRect.top),
      Offset(maskRect.left, maskRect.bottom),
      Offset(maskRect.right, maskRect.bottom),
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, cornerSize / 2, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
