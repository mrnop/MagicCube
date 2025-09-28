# MagicCube Flutter

Flutter port of the MagicManager functionality from the Android MagicCube app with a simple interface.

## Features

- **Asset Management**: Load magic templates and bitmaps from Flutter assets
- **Project Management**: Create, save, load, and delete user projects
- **VIP Device Support**: Simple device-based premium features
- **File System**: Workspace directory management for user data
- **Simple UI**: Basic template selection and project management interface

## Structure

### Models
- `Magic`: Template definition with sources, slices, and text elements
- `Page`: Page layout with faces, sections, watermarks, and text positioning
- `Save`: User project metadata with creation/modification tracking

### Services
- `MagicManager`: Core functionality singleton with simple API

### Simple Interface
- Template browser
- Project list with creation/deletion
- Basic VIP status indication

## Usage

```dart
// Initialize manager
await MagicManager.instance.initialize();

// List available templates
final magics = await MagicManager.instance.listMagics();

// Create new project
await MagicManager.instance.createMagic('template_name', 'project_name');

// List user projects
final saves = await MagicManager.instance.listSaves();

// Check VIP status
final isVip = MagicManager.instance.isVip;
```

## Setup

1. Add magic template assets to `assets/magics/`
2. Configure VIP device IDs in `assets/devices.json`
3. Run `flutter pub get` to install dependencies
4. Launch with `flutter run`

This implementation provides the core MagicManager functionality with a clean, simple Flutter interface for template and project management.