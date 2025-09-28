# Java Crop Library to Flutter Conversion

This document outlines the conversion of the Android Java crop library to a Flutter equivalent.

## Original Java Library

The original Java library (`cropLib/src/main/java/com/isarainc/crop/Crop.java`) provides:
- Fluent interface for configuring image cropping
- Support for aspect ratios, circle cropping, scaling options
- Integration with Android Activities and Fragments
- Intent-based navigation to crop activity

## Flutter Conversion

The Flutter equivalent (`lib/services/crop_service.dart`) provides:
- Similar fluent interface using Dart's method chaining
- Native Flutter widget-based crop screen
- Support for aspect ratios, circle cropping, and output sizing
- Navigation using Flutter's Navigator

## Key Differences

| Feature | Java | Flutter |
|---------|------|---------|
| **Navigation** | `start(activity)` | `start(context)` |
| **File Handling** | `Uri`, `File` | `File` objects |
| **Configuration** | Bundle parameters | Map<String, dynamic> |
| **UI** | Android Activity | Flutter Widget |
| **Result** | onActivityResult | Navigator.pop |

## Usage Comparison

### Java Usage
```java
// Basic usage
new Crop(sourceUri, destinationUri)
    .withAspectRatio(1, 1)
    .withCircle()
    .withTitle("Crop Image")
    .start(activity);

// From file
Crop.of(imageFile)
    .withAspectRatio(16, 9)
    .start(activity, 1234);
```

### Flutter Usage
```dart
// Basic usage
Crop.ofFile(imageFile)
    .withAspectRatio(1, 1)
    .withCircle()
    .withTitle("Crop Image")
    .start(context);

// From path
Crop.ofPath(imagePath)
    .withAspectRatio(16, 9)
    .start(context);
```

## API Mapping

| Java Method | Flutter Method | Notes |
|-------------|----------------|-------|
| `Crop(Uri, Uri)` | `Crop.ofFile(File)` | Constructor replacement |
| `Crop(File)` | `Crop.ofPath(String)` | File path handling |
| `withAspectRatio(x, y)` | `withAspectRatio(x, y)` | Same interface |
| `withTitle(title)` | `withTitle(title)` | Same interface |
| `withCircle()` | `withCircle()` | Same interface |
| `withScale()` | `withScale()` | Same interface |
| `withOutputSize(x, y)` | `withOutputSize(x, y)` | Same interface |
| `start(activity)` | `start(context)` | Context parameter change |

## Additional Flutter Features

The Flutter version includes additional convenience features:

### Utility Methods
```dart
// Simple cropping without builder pattern
await CropUtil.cropToSquare(context, imagePath);
await CropUtil.cropToCircle(context, imagePath);
await CropUtil.cropWithAspectRatio(context, imagePath, aspectRatioX: 4, aspectRatioY: 3);
```

### Extension Methods
```dart
// Extension methods on File objects
final file = File('image.jpg');
await file.cropSquare(context);
await file.cropCircle(context);
await file.crop(context, aspectRatioX: 16, aspectRatioY: 9);
```

## Installation

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
```

## Platform Integration

The Flutter version is platform-agnostic and works on:
- iOS
- Android
- Web (with limitations)
- Desktop (Windows, macOS, Linux)

## Migration Guide

1. Replace Java imports with Dart imports
2. Change `start(activity)` to `start(context)`
3. Replace `Uri` objects with `File` objects
4. Update error handling from try-catch to async/await
5. Replace Android permissions with Flutter permission handling

## Example Migration

### Before (Java)
```java
public void startCrop(Uri imageUri) {
    Uri destination = Uri.fromFile(new File(getCacheDir(), "cropped.jpg"));
    new Crop(imageUri, destination)
        .withAspectRatio(1, 1)
        .withCircle()
        .start(this);
}

@Override
protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode == Crop.REQUEST_CROP) {
        if (resultCode == RESULT_OK) {
            // Handle success
        }
    }
}
```

### After (Flutter)
```dart
Future<void> startCrop(String imagePath) async {
  final destination = File('${Directory.systemTemp.path}/cropped.jpg');
  final result = await Crop.ofPath(imagePath)
      .withAspectRatio(1, 1)
      .withCircle()
      .start(context);
  
  if (result != null) {
    // Handle success
  }
}
```

## File Structure

```
lib/
├── services/
│   └── crop_service.dart      # Main crop library
├── example/
│   └── crop_example.dart    # Usage examples
└── FLUTTER_CROP_CONVERSION.md  # This file
```

## Testing

The Flutter version can be tested using:
- Unit tests for the Crop class
- Widget tests for the CropScreen
- Integration tests for the full flow

## Limitations

- No native platform crop UI (uses custom Flutter implementation)
- Limited to basic cropping features
- No integration with native gallery apps
- Custom UI instead of platform-specific crop interfaces
