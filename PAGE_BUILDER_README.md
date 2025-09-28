# Page Builder Service

This document explains the Flutter conversion of the Java MagicManager build functionality with page selection logic.

## Overview

The `PageBuilderService` converts the Java `MagicManager.build()` method to Flutter, providing:

1. **Page Selection Dialog**: When a template has multiple page layouts, users can choose which one to build
2. **Page Preview Generation**: Creates visual previews of magic cube pages with processed slices
3. **Template Integration**: Works with existing magic templates and processed slices

## Key Features

### Java to Flutter Conversion

**Original Java Method:**

```java
public List<PagePreview> build(String name, String magicPath, String page) {
    // Build pages with faces, sections, texts, and watermarks
    // Apply transforms and scaling
    // Generate bitmap output
}
```

**Flutter Equivalent:**

```dart
static Future<List<PagePreview>?> buildProjectPages({
  required String projectName,
  required String magicPath, 
  required BuildContext context,
  void Function(String message)? onProgress,
}) async {
  // Load available pages and show selection dialog if needed
  // Build selected page with UI.Image output
}
```

### Page Selection Logic

When processing a project:

1. **Single Page Template**: Automatically builds the only available page
2. **Multiple Page Templates**: Shows selection dialog with:
   - Page name and description
   - Page dimensions and count
   - Visual preview cards
   - Cancel option

### Building Process

1. **Template Loading**: Loads page head and magic template metadata
2. **Image Processing**: Scales template images and applies transformations
3. **Face Building**: Places processed slices according to face definitions
4. **Section Processing**: Handles page sections with their own transformations
5. **Text Rendering**: Creates text overlays from polygon definitions
6. **Watermark Application**: Adds watermarks for non-VIP users
7. **Final Composition**: Combines all elements into final page image

## Usage

### In Project Detail Screen

```dart
// Build pages button (available after processing)
ElevatedButton.icon(
  onPressed: isProcessed ? _buildPages : null,
  icon: const Icon(Icons.article),
  label: const Text('Build Pages'),
)
```

### Direct Service Usage

```dart
final previews = await PageBuilderService.buildProjectPages(
  projectName: 'my_project',
  magicPath: 'decagonal',
  context: context,
  onProgress: (message) => print(message),
);

if (previews != null) {
  // Display or save the generated page previews
  for (var preview in previews) {
    // preview.image contains the UI.Image
    // preview.page contains the page metadata
  }
}
```

## Implementation Details

### Page Selection Dialog

- **Material Design**: Uses AlertDialog with ListView of page options
- **Rich Information**: Shows page dimensions, description, and page count
- **User Choice**: Returns selected page path or null if cancelled

### Image Processing

- **Canvas-based**: Uses Flutter's Canvas API for image composition
- **Transform Support**: Handles rotation, scaling, and perspective transforms
- **Memory Efficient**: Properly disposes of temporary images

### Error Handling

- **Graceful Degradation**: Continues building even if some elements fail
- **User Feedback**: Progress callbacks and error messages
- **Null Safety**: Handles missing templates, images, or slices

## Testing

### Page Builder Test Screen

Access via the floating action button in the home screen:

1. **Template Detection**: Verifies available magic templates
2. **Page Selection**: Tests the multi-page selection dialog
3. **Preview Generation**: Creates and displays page previews
4. **Error Handling**: Shows any issues during the build process

### Integration Testing

The service integrates with:

- **Magic Manager**: For template and slice loading
- **Processing Service**: Requires processed slices
- **Project System**: Works with saved projects

## File Structure

```text
lib/services/
  page_builder_service.dart     # Main service implementation

lib/screens/
  page_builder_test_screen.dart # Test interface
  project_detail_screen.dart    # Integration with "Build Pages" button

lib/models/
  page.dart                     # Page and PageHead models (unchanged)
  magic.dart                    # Magic template models (unchanged)
```

## Future Enhancements

1. **Export Integration**: Save generated pages to files
2. **Batch Processing**: Build multiple page types simultaneously
3. **Preview Optimization**: Thumbnail generation for better performance
4. **Custom Templates**: User-defined page layouts
5. **Print Settings**: Page size and DPI customization

## Notes

- **VIP Features**: Watermarks are skipped for VIP users (same as Java)
- **Asset Loading**: Uses Flutter's `rootBundle` for template assets
- **Performance**: Large images may require optimization for mobile devices
- **Platform Support**: Works on all Flutter-supported platforms
