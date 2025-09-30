# Reprocess Images Fix

## Issue
The "Reprocess Images" button was not working because the button logic was incorrectly configured.

## Problem
In `lib/screens/project_detail_screen.dart`, the `canProcess` variable was defined as:

```dart
final canProcess = _processingStatus != null && !_processingStatus!.isProcessed;
```

This meant the button was only enabled when the project was **NOT processed**, which prevented reprocessing.

## Solution
Changed the logic to:

```dart
final canProcess = _processingStatus != null;
```

This allows the button to be enabled whenever we have processing status, supporting both:
1. **First-time processing**: When the project is not processed yet
2. **Reprocessing**: When the project is already processed

## How It Works

### Button State Logic
- **Before**: Button only enabled for unprocessed projects
- **After**: Button enabled for both processed and unprocessed projects

### Processing Detection
The system correctly detects reprocessing vs. first-time processing:

```dart
final isReprocessing = _processingStatus?.isProcessed == true;
```

### Service Call
The correct `forceReprocess` parameter is passed to the service:

```dart
final result = await MagicProcessingService.processProject(
  projectPath: widget.save.path!,
  templatePath: widget.save.magic,
  forceReprocess: isReprocessing,  // ✓ This was already correct
  onProgress: (message) => { /* ... */ },
);
```

## Testing
To test the fix:

1. **Create a project** with source images
2. **Process the project** - button should show "Process Images" 
3. **After processing completes** - button should show "Reprocess Images" and be enabled
4. **Click "Reprocess Images"** - should show reprocessing dialog and regenerate all slices

## Files Changed
- `lib/screens/project_detail_screen.dart`: Fixed button enable logic

## Notes
- The underlying processing service was already correctly implemented
- The UI just needed the button state logic fixed
- All reprocessing functionality including `forceReprocess` parameter was working
- The fix maintains proper UX with different labels for process vs. reprocess
