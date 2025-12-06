import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'crop_service.dart';
import 'mask_crop_service.dart';

/// Service that handles image picking and cropping for magic creation
class ImageCropService {
  static final ImagePicker _picker = ImagePicker();

  /// Pick an image from gallery and immediately open crop interface
  static Future<File?> pickAndCropImage({
    required BuildContext context,
    ImageSource source = ImageSource.gallery,
    int? aspectRatioX,
    int? aspectRatioY,
    String? cropTitle,
    bool circleShape = false,
  }) async {
    try {
      // Step 1: Pick image from gallery or camera
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null || !context.mounted) return null;

      // Step 2: Immediately open crop screen
      final croppedFile = await CropUtil.cropWithAspectRatio(
        context,
        pickedFile.path,
        aspectRatioX: aspectRatioX,
        aspectRatioY: aspectRatioY,
        title: cropTitle ?? 'Crop Image',
        circleShape: circleShape,
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
      debugPrint('Error picking and cropping image: $e');
      return null;
    }
  }

  /// Pick image from gallery and crop for magic creation
  static Future<File?> pickImageForMagic(BuildContext context) async {
    return await _showImageSourceDialog(context);
  }

  /// Pick image from gallery and crop using template mask
  static Future<File?> pickImageForMagicWithMask(
      BuildContext context, String templatePath,
      {int sourceId = 1}) async {
    return await MaskCropService.cropForMagicTemplate(
      context: context,
      templatePath: templatePath,
      title: 'Crop for Template',
      source: ImageSource.gallery,
      sourceId: sourceId,
    );
  }

  /// Show dialog to choose image source (camera or gallery)
  static Future<File?> _showImageSourceDialog(BuildContext context) async {
    final result = await showModalBottomSheet<File?>(
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
                  final result = await pickAndCropImage(
                    context: context,
                    source: ImageSource.gallery,
                    cropTitle: 'Crop Image for Magic',
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
                  final result = await pickAndCropImage(
                    context: context,
                    source: ImageSource.camera,
                    cropTitle: 'Crop Image for Magic',
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
    return result;
  }

  /// Pick and crop image to square aspect ratio
  static Future<File?> pickAndCropSquare(BuildContext context) async {
    return await pickAndCropImage(
      context: context,
      source: ImageSource.gallery,
      aspectRatioX: 1,
      aspectRatioY: 1,
      cropTitle: 'Crop to Square',
    );
  }

  /// Pick and crop image to circle
  static Future<File?> pickAndCropCircle(BuildContext context) async {
    return await pickAndCropImage(
      context: context,
      source: ImageSource.gallery,
      aspectRatioX: 1,
      aspectRatioY: 1,
      cropTitle: 'Crop to Circle',
      circleShape: true,
    );
  }

  /// Pick image from camera and crop to square
  static Future<File?> captureAndCropSquare(BuildContext context) async {
    return await pickAndCropImage(
      context: context,
      source: ImageSource.camera,
      aspectRatioX: 1,
      aspectRatioY: 1,
      cropTitle: 'Crop Captured Image',
    );
  }

  /// Pick multiple images for all sources in a magic template and crop them
  static Future<List<File>?> pickImagesForAllSources({
    required BuildContext context,
    required String templatePath,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // Load template metadata to get sources
      final sources = await _loadTemplateSources(templatePath);
      if (sources == null || sources.isEmpty) {
        debugPrint('No sources found in template: $templatePath');
        return null;
      }

      if (!context.mounted) return null;

      final List<File> croppedImages = [];

      // Show initial info dialog
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Multi-Image Crop'),
          content: Text(
              'You will need to pick and crop ${sources.length} images, one for each source in this template.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return null;

      // Process each source sequentially
      for (int i = 0; i < sources.length; i++) {
        final sourceData = sources[i];
        final sourceId = sourceData['id'] ?? (i + 1);

        debugPrint(
            'Processing source ${i + 1} of ${sources.length} (ID: $sourceId)');

        // Get the mask path for this source
        final maskPath = await MaskCropService.getMaskPathFromTemplate(
            templatePath, sourceId);
        if (maskPath == null) {
          debugPrint('No mask found for source $sourceId');
          continue; // Skip this source if no mask found
        }

        if (!context.mounted) return null;

        // Pick and crop image directly without additional wrapper calls
        final croppedFile = await MaskCropService.pickAndCropWithMask(
          context: context,
          maskAssetPath: maskPath,
          title: 'Image ${i + 1}/${sources.length} - Source $sourceId',
          source: source,
        );

        if (croppedFile == null) {
          // User cancelled - clean up any already cropped images
          debugPrint(
              'User cancelled at image ${i + 1}, cleaning up ${croppedImages.length} files');
          for (final file in croppedImages) {
            try {
              await file.delete();
            } catch (e) {
              debugPrint('Error cleaning up file: $e');
            }
          }
          return null;
        }

        croppedImages.add(croppedFile);
        debugPrint('Successfully cropped image ${i + 1} of ${sources.length}');
      }

      debugPrint(
          'Successfully picked and cropped ${croppedImages.length} images');
      return croppedImages;
    } catch (e) {
      debugPrint('Error picking images for all sources: $e');
      return null;
    }
  }

  /// Simplified multi-source picking - picks all images first, then crops them
  static Future<List<File>?> pickMultipleImagesSimple({
    required BuildContext context,
    required String templatePath,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // Load template metadata to get sources
      final sources = await _loadTemplateSources(templatePath);
      if (sources == null || sources.isEmpty) {
        debugPrint('No sources found in template: $templatePath');
        return null;
      }

      final List<File> allImages = [];

      // Step 1: Pick all images first
      for (int i = 0; i < sources.length; i++) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 90,
        );

        if (pickedFile == null) {
          // User cancelled - clean up
          for (final file in allImages) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          }
          return null;
        }

        allImages.add(File(pickedFile.path));
      }

      // Step 2: Crop all images with their respective masks
      final List<File> croppedImages = [];
      for (int i = 0; i < allImages.length && i < sources.length; i++) {
        final sourceData = sources[i];
        final sourceId = sourceData['id'] ?? (i + 1);

        // Get mask path
        final maskPath = await MaskCropService.getMaskPathFromTemplate(
            templatePath, sourceId);
        if (maskPath == null) {
          debugPrint('No mask found for source $sourceId, skipping');
          continue;
        }

        // Load mask image
        final maskImage = await MaskCropService.loadMaskFromAssets(maskPath);
        if (maskImage == null) {
          debugPrint('Failed to load mask for source $sourceId');
          continue;
        }

        if (!context.mounted) return null;

        // Open crop screen
        final croppedFile = await Navigator.push<File?>(
          context,
          MaterialPageRoute(
            builder: (context) => MaskCropScreen(
              imagePath: allImages[i].path,
              maskImage: maskImage,
              title: 'Crop Image ${i + 1}/${sources.length} (Source $sourceId)',
            ),
          ),
        );

        if (croppedFile == null) {
          // User cancelled cropping - clean up
          for (final file in allImages) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          }
          for (final file in croppedImages) {
            try {
              await file.delete();
            } catch (e) {
              // Ignore cleanup errors
            }
          }
          return null;
        }

        croppedImages.add(croppedFile);
      }

      // Clean up original picked files
      for (final file in allImages) {
        try {
          await file.delete();
        } catch (e) {
          // Ignore cleanup errors
        }
      }

      return croppedImages;
    } catch (e) {
      debugPrint('Error in simplified multi-source picking: $e');
      return null;
    }
  }

  /// Load template metadata and extract sources
  static Future<List<Map<String, dynamic>>?> _loadTemplateSources(
      String templatePath) async {
    try {
      final metaData =
          await rootBundle.loadString('assets/magics/$templatePath/meta.json');
      final Map<String, dynamic> meta = json.decode(metaData);

      final List<dynamic>? sources = meta['sources'];
      if (sources == null) return null;

      return sources.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error loading template sources: $e');
      return null;
    }
  }
}
