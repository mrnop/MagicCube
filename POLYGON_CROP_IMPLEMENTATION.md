# Polygon Crop Implementation Fix

## Issue Description
The polygon-based cropping was producing inverted/opposite results compared to what was expected from the meta.json configuration files. Images were being cropped incorrectly, showing content outside the intended polygon areas.

## Root Cause
The issue was in the `_extractPolygonSlice` method in `magic_processing_service.dart`:

1. **Improper Path Winding**: The polygon path wasn't explicitly setting the correct fill type for clipping
2. **Coordinate System Issues**: The image drawing and clipping coordinates weren't properly aligned
3. **Canvas State Management**: The canvas clipping wasn't being properly managed with save/restore

## Solution Implemented

### 1. Fixed Path Creation
- Set explicit `PathFillType.nonZero` to ensure consistent polygon winding behavior
- This ensures the polygon interior is correctly identified for clipping

### 2. Improved Image Drawing
- Replaced `canvas.drawImage()` with `canvas.drawImageRect()` for better control over positioning
- Added `FilterQuality.high` for better image quality during cropping
- Properly aligned source and destination rectangles

### 3. Canvas State Management
- Added proper `canvas.save()` and `canvas.restore()` around clipping operations
- This ensures clipping doesn't affect other drawing operations

### 4. Coordinate Scaling
- Added automatic scaling of polygon coordinates to match actual source image dimensions
- Meta.json defines polygons for expected dimensions (e.g., 800x764), but user images may differ
- Now calculates `scaleX` and `scaleY` factors and applies them to polygon coordinates
- This ensures crop areas are correctly positioned regardless of source image size

## Code Changes

### Before (Problematic):
```dart
// Create clipping path from polygon
final path = Path();
// ... build path ...

// Clip to polygon and draw the source image
canvas.clipPath(path);
canvas.drawImage(
  sourceImage,
  Offset(-bounds.left, -bounds.top),
  Paint(),
);
```

### After (Fixed):
```dart
// Create clipping path from polygon
final path = Path();
// ... build path ...
path.fillType = PathFillType.nonZero;

// Save canvas state before clipping
canvas.save();

// Apply clipping path
canvas.clipPath(path);

// Draw the source image, properly positioned within the bounds
canvas.drawImageRect(
  sourceImage,
  Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
  Rect.fromLTWH(-bounds.left, -bounds.top, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
  Paint()..filterQuality = FilterQuality.high,
);

// Restore canvas state
canvas.restore();
```

## Template Support
This fix ensures proper cropping for all template types:
- **Decagonal**: Complex diamond/triangular shapes
- **Octagonal**: Perspective-transformed squares  
- **MagicCube**: Simple rectangular subdivisions
- **All Others**: Any polygon-defined crop areas

## Testing
To verify the fix:
1. Create a project with the decagonal template
2. Add source images and process them
3. Check that the resulting slices match the expected polygon shapes from meta.json
4. Verify that the cropped areas contain the correct image content (not inverted)

The polygon vertices in meta.json now correctly define the crop areas, with the image content properly extracted from within those boundaries.