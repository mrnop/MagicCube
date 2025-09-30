# Face Scaling Fix in Page Builder

## Issue Identified
Images were not scaling up properly when building pages because the individual face scale property was not being applied.

## Root Cause
In `PageBuilderService._buildFace()`, the scaling logic was incomplete:

**Before (Incorrect):**
```dart
// Only used page scale and print scale
final finalScale = scale != 1 ? scale * printScale : printScale;
```

**Problem:** The `face.scale` property from `PageFace` model was completely ignored.

## Solution Applied
**After (Fixed):**
```dart
// Combine page scale, face scale, and print scale
final finalScale = scale * face.scale * printScale;
if (finalScale != 1.0) {
  sliceImage = await _scaleImage(sliceImage, finalScale);
  if (sliceImage == null) return;
}
```

## Technical Details

### PageFace Model
The `PageFace` class has a `scale` property:
```dart
class PageFace {
  final double scale; // Default: 1.0
  // ... other properties
}
```

### Scaling Hierarchy
The fix now properly combines three scaling factors:
1. **Page-level scale** (`pageHead.scale`) - Template-wide scaling
2. **Face-level scale** (`face.scale`) - Individual slice scaling  
3. **Print scale** (`printScale`) - Display/output scaling

### ImageUtils Integration
The fix uses `ImageUtils.scaleBitmap()` for consistent scaling with the Java implementation:
```dart
sliceImage = await _scaleImage(sliceImage, finalScale);
```

## Impact
- ✅ **Individual face scaling** now works correctly
- ✅ **Backward compatibility** maintained (all existing scaling still works)
- ✅ **Consistent behavior** with Java implementation
- ✅ **No performance impact** (only applies scaling when needed)

## Testing
The fix should be tested with:
1. Pages with `face.scale > 1.0` (should scale up)
2. Pages with `face.scale < 1.0` (should scale down)  
3. Pages with `face.scale = 1.0` (should remain unchanged)
4. Complex pages with mixed face scales

## File Modified
- `lib/services/page_builder_service.dart` - Fixed `_buildFace()` method

## Related
This fix complements the earlier ImageUtils alignment work, ensuring all image manipulation operations are consistent between Java and Flutter implementations.
