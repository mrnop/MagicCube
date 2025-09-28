import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Flutter equivalent of the Android Crop library
/// Provides a fluent interface for configuring and starting image cropping using image_cropper
class Crop {
  final String? sourcePath;
  final String? destinationPath;
  final Map<String, dynamic> _options = {};

  static const int requestCrop = 69;
  static const int resultError = 96;

  Crop._(this.sourcePath, this.destinationPath);

  factory Crop.ofFile(File file) {
    return Crop._(file.path, null);
  }

  factory Crop.ofPath(String path) {
    return Crop._(path, null);
  }

  Crop withAspectRatio(int x, int y) {
    _options['aspectRatioX'] = x;
    _options['aspectRatioY'] = y;
    return this;
  }

  Crop withTitle(String title) {
    _options['title'] = title;
    return this;
  }

  Crop withScaleIfNeed() {
    _options['scaleUpIfNeeded'] = true;
    return this;
  }

  Crop withCircle() {
    _options['isCircle'] = true;
    return this;
  }

  Crop withScale() {
    _options['scale'] = true;
    return this;
  }

  Crop withOutputSize(int x, int y) {
    _options['maxWidth'] = x;
    _options['maxHeight'] = y;
    return this;
  }

  /// Start the crop activity and return the cropped file
  Future<File?> start(BuildContext context) async {
    if (sourcePath == null) return null;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath!,
      maxWidth: _options['maxWidth'],
      maxHeight: _options['maxHeight'],
      compressFormat: ImageCompressFormat.png,
      compressQuality: 100,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: _options['title'] ?? 'Crop Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: _getAspectRatioPreset(),
          lockAspectRatio: _hasAspectRatio(),
          aspectRatioPresets: _getAspectRatioPresets(),
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: _options['title'] ?? 'Crop Image',
          aspectRatioLockEnabled: _hasAspectRatio(),
          resetAspectRatioEnabled: !_hasAspectRatio(),
          aspectRatioPresets: _getAspectRatioPresets(),
          hidesNavigationBar: false,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: CropperSize(
            width: _options['maxWidth']?.toDouble() ?? 520,
            height: _options['maxHeight']?.toDouble() ?? 520,
          ),
        ),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }

  List<CropAspectRatioPreset> _getAspectRatioPresets() {
    if (_options['isCircle'] == true) {
      return [CropAspectRatioPreset.square];
    }

    return [
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio16x9
    ];
  }

  CropAspectRatioPreset _getAspectRatioPreset() {
    if (!_hasAspectRatio()) return CropAspectRatioPreset.original;

    final x = _options['aspectRatioX'] ?? 1;
    final y = _options['aspectRatioY'] ?? 1;

    if (x == 1 && y == 1) return CropAspectRatioPreset.square;
    if (x == 3 && y == 2) return CropAspectRatioPreset.ratio3x2;
    if (x == 4 && y == 3) return CropAspectRatioPreset.ratio4x3;
    if (x == 5 && y == 3) return CropAspectRatioPreset.ratio5x3;
    if (x == 5 && y == 4) return CropAspectRatioPreset.ratio5x4;
    if (x == 7 && y == 5) return CropAspectRatioPreset.ratio7x5;
    if (x == 16 && y == 9) return CropAspectRatioPreset.ratio16x9;

    return CropAspectRatioPreset.original;
  }

  bool _hasAspectRatio() {
    return _options.containsKey('aspectRatioX') &&
        _options.containsKey('aspectRatioY');
  }

  Map<String, dynamic> get options => Map.unmodifiable(_options);
}

/// Simplified crop utility class for basic cropping needs
class CropUtil {
  /// Crop an image file with a specific aspect ratio
  static Future<File?> cropWithAspectRatio(
    BuildContext context,
    String imagePath, {
    int? aspectRatioX,
    int? aspectRatioY,
    String? title,
    bool circleShape = false,
    int? maxWidth,
    int? maxHeight,
  }) async {
    final crop = Crop.ofPath(imagePath);

    if (aspectRatioX != null && aspectRatioY != null) {
      crop.withAspectRatio(aspectRatioX, aspectRatioY);
    }

    if (title != null) {
      crop.withTitle(title);
    }

    if (circleShape) {
      crop.withCircle();
    }

    if (maxWidth != null && maxHeight != null) {
      crop.withOutputSize(maxWidth, maxHeight);
    }

    return await crop.start(context);
  }

  /// Crop an image to a square
  static Future<File?> cropToSquare(
    BuildContext context,
    String imagePath, {
    String? title,
    int? size,
  }) async {
    return await cropWithAspectRatio(
      context,
      imagePath,
      aspectRatioX: 1,
      aspectRatioY: 1,
      title: title ?? 'Crop to Square',
      maxWidth: size,
      maxHeight: size,
    );
  }

  /// Crop an image to a circle
  static Future<File?> cropToCircle(
    BuildContext context,
    String imagePath, {
    String? title,
    int? size,
  }) async {
    return await cropWithAspectRatio(
      context,
      imagePath,
      aspectRatioX: 1,
      aspectRatioY: 1,
      title: title ?? 'Crop to Circle',
      circleShape: true,
      maxWidth: size,
      maxHeight: size,
    );
  }

  /// Quick crop with different aspect ratios
  static Future<File?> cropWithPreset(
    BuildContext context,
    String imagePath,
    CropAspectRatioPreset preset, {
    String? title,
  }) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imagePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title ?? 'Crop Image',
          toolbarColor: Theme.of(context).primaryColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: preset,
          lockAspectRatio: preset != CropAspectRatioPreset.original,
        ),
        IOSUiSettings(
          title: title ?? 'Crop Image',
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
        ),
      ],
    );

    return croppedFile != null ? File(croppedFile.path) : null;
  }
}

/// Extension methods for easier usage
extension CropExtensions on File {
  Future<File?> crop({
    required BuildContext context,
    int? aspectRatioX,
    int? aspectRatioY,
    String? title,
    bool circleShape = false,
    int? maxWidth,
    int? maxHeight,
  }) async {
    return await CropUtil.cropWithAspectRatio(
      context,
      path,
      aspectRatioX: aspectRatioX,
      aspectRatioY: aspectRatioY,
      title: title,
      circleShape: circleShape,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  Future<File?> cropSquare(BuildContext context,
      {String? title, int? size}) async {
    return await CropUtil.cropToSquare(context, path, title: title, size: size);
  }

  Future<File?> cropCircle(BuildContext context,
      {String? title, int? size}) async {
    return await CropUtil.cropToCircle(context, path, title: title, size: size);
  }

  Future<File?> cropWithPreset(
    BuildContext context,
    CropAspectRatioPreset preset, {
    String? title,
  }) async {
    return await CropUtil.cropWithPreset(context, path, preset, title: title);
  }
}
