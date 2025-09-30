# Image Utils Alignment with Java Implementation

## Overview

The Flutter `ImageUtils` class has been created to align image manipulation logic with the Java `Utils.java` class. This ensures consistent behavior between the Java and Flutter implementations of the MagicCube application.

## Method Alignment

### Scaling Methods

| Java Method | Flutter Method | Description |
|-------------|----------------|-------------|
| `scaleBitmap(Bitmap, int, int)` | `ImageUtils.scaleBitmap(ui.Image, int, int)` | Scale to specific dimensions with high-quality filtering |
| `scaleBitmap(Bitmap, float, boolean)` | `ImageUtils.scaleBitmapByFactor(ui.Image, double, {bool recycle})` | Scale by factor with optional recycling |
| `scaleBitmap(Bitmap, float)` | `ImageUtils.scaleBitmapByFactorSimple(ui.Image, double)` | Scale by factor (recycle=true by default) |

### Rotation Methods

| Java Method | Flutter Method | Description |
|-------------|----------------|-------------|
| `rotateBitmap(Bitmap, float, boolean)` | `ImageUtils.rotateBitmap(ui.Image, double, {bool recycle})` | Rotate with automatic dimension calculation and trimming |
| `rotateBitmap(Bitmap, float)` | `ImageUtils.rotateBitmapSimple(ui.Image, double)` | Rotate (recycle=true by default) |

### Image Processing Methods

| Java Method | Flutter Method | Description |
|-------------|----------------|-------------|
| `createContrast(Bitmap, double)` | `ImageUtils.createContrast(ui.Image, double)` | Apply contrast adjustment using same formula |
| `toGrayscale(Bitmap)` | `ImageUtils.toGrayscale(ui.Image)` | Convert to grayscale using ColorMatrix |
| `trim(Bitmap)` | `ImageUtils.trim(ui.Image)` | Remove transparent edges |

### Utility Methods

| Java Method | Flutter Method | Description |
|-------------|----------------|-------------|
| `getBitmapFromAsset(Context, String)` | `ImageUtils.getBitmapFromAsset(String)` | Load image from assets |
| `tileBitmap(BitmapDrawable, int, int)` | `ImageUtils.tileBitmap(ui.Image, int, int)` | Create tiled pattern |
| `loadBitmap(File)` | `ImageUtils.loadBitmapFromFile(String)` | Load with EXIF support |

## Key Implementation Details

### Scaling Quality
- Uses `Paint.filterQuality = FilterQuality.high` equivalent to Java's `Paint.FILTER_BITMAP_FLAG`
- Applies proper matrix transformations for high-quality results

### Rotation Accuracy
- Calculates new dimensions using same trigonometry as Java implementation
- Automatically applies trimming to remove transparent borders
- Preserves center-point rotation behavior

### Memory Management
- Flutter's garbage collector handles image disposal automatically
- Optional `recycle` parameter maintains API compatibility with Java
- Proper canvas state management with save/restore

### Contrast Algorithm
- Uses identical mathematical formula: `contrast = Math.pow((100 + value) / 100, 2)`  
- Processes RGB channels individually with proper clamping
- Preserves alpha channel values

## Integration

The following services have been updated to use `ImageUtils`:

- `MagicProcessingService`: Uses `ImageUtils` for transform operations
- `PageBuilderService`: Uses `ImageUtils` for scaling and rotation
- All image manipulation now follows Java implementation patterns

## Benefits

1. **Consistency**: Identical results between Java and Flutter implementations
2. **Quality**: High-quality image processing with proper filtering
3. **Maintainability**: Centralized image utilities reduce code duplication
4. **Performance**: Optimized implementations based on proven Java algorithms

## Usage Example

```dart
// Scale image to specific size
final scaledImage = await ImageUtils.scaleBitmap(sourceImage, 800, 600);

// Rotate image with trimming
final rotatedImage = await ImageUtils.rotateBitmap(sourceImage, 45.0);

// Apply contrast adjustment
final contrastedImage = await ImageUtils.createContrast(sourceImage, 25.0);

// Convert to grayscale
final grayscaleImage = await ImageUtils.toGrayscale(sourceImage);
```
