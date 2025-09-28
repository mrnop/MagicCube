import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/crop_service.dart';
import '../services/mask_crop_service.dart';

/// Example usage of the Flutter Crop library
class CropExample extends StatefulWidget {
  const CropExample({super.key});

  @override
  State<CropExample> createState() => _CropExampleState();
}

class _CropExampleState extends State<CropExample> {
  File? _croppedImage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Crop Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _cropImage,
              child: const Text('Regular Crop'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _cropWithMask,
              child: const Text('Crop with Mask (Decagonal)'),
            ),
            const SizedBox(height: 20),
            if (_croppedImage != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.file(
                  _croppedImage!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cropImage() async {
    try {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      final crop = Crop.ofPath(pickedFile.path)
          .withAspectRatio(1, 1)
          .withTitle('Crop to Square')
          .withOutputSize(500, 500);

      final result = await crop.start(context);
      if (result != null) {
        setState(() {
          _croppedImage = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e')),
        );
      }
    }
  }

  Future<void> _cropWithMask() async {
    try {
      final result = await MaskCropService.pickAndCropWithMask(
        context: context,
        maskAssetPath: 'assets/magics/decagonal/mask.png',
        title: 'Crop with Decagonal Mask',
        source: ImageSource.gallery,
      );

      if (result != null) {
        setState(() {
          _croppedImage = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping with mask: $e')),
        );
      }
    }
  }
}
