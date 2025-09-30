# Source Image Scaling Fix

## Problem Description

The slice extraction logic was incorrectly scaling polygon coordinates instead of scaling source images to fit the defined dimensions in meta.json files.

### Original Incorrect Approach
- Load source image (e.g., 1200x1600 pixels)
- Read meta.json dimensions (e.g., 800x800)
- Scale **polygon coordinates** from meta.json to match source image
- Extract slice using scaled coordinates

### Issues with Original Approach
1. **Coordinate Mismatch**: Polygon coordinates in meta.json are designed for specific dimensions (800x800)
2. **Distortion**: Scaling coordinates can cause aspect ratio distortion
3. **Inconsistent Results**: Different source image sizes produce different slice shapes
4. **Design Intent**: Meta.json defines the expected "canvas" size that polygon coordinates are designed for

## Corrected Approach

### New Logic Flow
1. Load source image (any size)
2. Read expected dimensions from meta.json (e.g., 800x800)
3. **Scale source image** to match meta.json dimensions using `ImageUtils.scaleBitmap()`
4. Use **original polygon coordinates** from meta.json (designed for the meta.json dimensions)
5. Extract slice from scaled source image

### Code Changes

#### Before (Incorrect)
```dart
// Calculate scaling factors to match actual source image dimensions
final scaleX = sourceImage.width / expectedWidth;
final scaleY = sourceImage.height / expectedHeight;

// Scale polygon coordinates
points.addAll(polygon.map((point) {
  final scaledX = originalX * scaleX;
  final scaledY = originalY * scaleY;
  return Offset(scaledX, scaledY);
}));

// Extract slice using scaled coordinates
final sliceImage = await _extractPolygonSlice(sourceImage, points);
```

#### After (Correct)
```dart
// Scale source image to match meta.json dimensions
ui.Image workingImage = sourceImage;
if (needsScaling) {
  workingImage = await ImageUtils.scaleBitmap(sourceImage, expectedWidth, expectedHeight) ?? sourceImage;
}

// Use original polygon coordinates (designed for meta.json dimensions)
final points = polygon.map((point) => Offset(
    (point['x'] as num).toDouble(), 
    (point['y'] as num).toDouble())
).toList();

// Extract slice from scaled source image
final sliceImage = await _extractPolygonSlice(workingImage, points);
```

## Example: PhotoCube Meta.json

```json
{
  "sources": [
    {"id": 1, "width": 800, "height": 800, "mask": "mask.png",
      "slices": [
        {"id": 1, "polygon": [
          {"x": 0, "y": 0}, 
          {"x": 800, "y": 0}, 
          {"x": 800, "y": 800}, 
          {"x": 0, "y": 800}
        ]}
      ]
    }
  ]
}
```

### Processing Flow
1. **User uploads**: 1200x1600 photo for source 1
2. **System scales**: Photo to 800x800 (meta.json dimensions)
3. **System extracts**: Full slice using polygon [0,0 → 800,0 → 800,800 → 0,800]
4. **Result**: Consistent 800x800 slice regardless of original photo size

## Benefits

1. **Consistent Slice Shapes**: All slices maintain the exact shapes defined in meta.json
2. **No Coordinate Distortion**: Polygon coordinates work as designed
3. **Predictable Results**: Same slice shape regardless of source image dimensions
4. **Design Integrity**: Preserves the intended template design from meta.json
5. **Better Quality**: Uses high-quality `ImageUtils.scaleBitmap()` for source scaling

## Impact on Different Magic Types

- **PhotoCube**: 800x800 sources → consistent square slices
- **Kaleidocycle**: Various polygon shapes maintain exact proportions
- **MagicPrism**: Complex geometry preserved
- **All Templates**: Polygon coordinates work as intended by designers

## Files Modified
- `lib/services/magic_processing_service.dart`: Updated `_processSlice()` method

## Testing Notes
This fix ensures that uploaded photos of any size will be properly fitted to the template's expected dimensions before slice extraction, maintaining the design integrity of all magic templates.
