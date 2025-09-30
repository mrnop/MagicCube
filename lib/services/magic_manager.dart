import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/magic.dart';
import '../models/page.dart';
import '../models/save.dart';

class MagicManager {
  static MagicManager? _instance;
  static MagicManager get instance => _instance ??= MagicManager._();

  MagicManager._();

  String? _deviceId;
  List<String> _vipDevices = [];
  Directory? _workDir;

  /// Initialize the manager with device ID and VIP list
  Future<void> initialize() async {
    // In Flutter, we use a unique device identifier
    // You might want to use device_info_plus package for actual device ID
    _deviceId = 'flutter_device_${DateTime.now().millisecondsSinceEpoch}';

    // Load VIP devices from assets
    await _loadVipDevices();

    // Initialize work directory
    await _initWorkDirectory();
  }

  Future<void> _loadVipDevices() async {
    try {
      final deviceData = await rootBundle.loadString('assets/devices.json');
      final List<dynamic> devices = json.decode(deviceData);
      _vipDevices = devices.cast<String>();
    } catch (e) {
      print('Failed to load VIP devices: $e');
      _vipDevices = [];
    }
  }

  Future<void> _initWorkDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _workDir = Directory(path.join(appDir.path, 'workspace'));
    if (!_workDir!.existsSync()) {
      _workDir!.createSync(recursive: true);
    }
  }

  /// Check if current device is VIP
  bool get isVip => _vipDevices.contains(_deviceId);

  /// Get workspace directory
  Directory get workDir => _workDir!;

  /// Check if asset exists
  Future<bool> assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// List all available magic templates
  Future<List<Magic>> listMagics() async {
    final List<Magic> magics = [];

    try {
      // Load magic list from assets manifest
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Find magic directories
      final magicPaths = <String>{};
      for (final key in manifestMap.keys) {
        final match =
            RegExp(r'assets/magics/([^/]+)/meta\.json').firstMatch(key);
        if (match != null) {
          magicPaths.add(match.group(1)!);
        }
      }

      // Load each magic
      for (final magicPath in magicPaths) {
        try {
          final magic = await loadMagic(magicPath);
          if (magic != null) {
            magics.add(magic);
          }
        } catch (e) {
          print('Failed to load magic $magicPath: $e');
        }
      }
    } catch (e) {
      print('Failed to list magics: $e');
    }

    return magics;
  }

  /// Load magic template metadata
  Future<Magic?> loadMagic(String magicPath) async {
    try {
      final metaData =
          await rootBundle.loadString('assets/magics/$magicPath/meta.json');
      final magic = Magic.fromJson(json.decode(metaData));
      magic.path = magicPath;
      return magic;
    } catch (e) {
      print('Failed to load magic $magicPath: $e');
      return null;
    }
  }
  /// Load bitmap from magic assets
  Future<ui.Image?> loadMagicBitmap(String magicPath, String filename) async {
    try {
      final data = await rootBundle.load('assets/magics/$magicPath/$filename');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('Failed to load bitmap $magicPath/$filename: $e');
      return null;
    }
  }

  /// List pages for a magic template
  Future<List<PageHead>> listPages(String magicPath) async {
    final List<PageHead> pages = [];

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Find page directories - use proper regex escaping for the variable
      final pagePaths = <String>{};
      final pattern =
          RegExp('assets/magics/$magicPath/pages/([^/]+)/meta\\.json');

      for (final key in manifestMap.keys) {
        final match = pattern.firstMatch(key);
        if (match != null) {
          pagePaths.add(match.group(1)!);
        }
      }

      // Load each page
      for (final pagePath in pagePaths) {
        try {
          final page = await loadPage(magicPath, pagePath);
          if (page != null) {
            pages.add(page);
          }
        } catch (e) {
          print('Failed to load page $magicPath/$pagePath: $e');
        }
      }
    } catch (e) {
      print('Failed to list pages for $magicPath: $e');
    }

    return pages;
  }

  /// Load page metadata
  Future<PageHead?> loadPage(String magicPath, String pagePath) async {
    try {
      final metaData = await rootBundle
          .loadString('assets/magics/$magicPath/pages/$pagePath/meta.json');
      final page = PageHead.fromJson(json.decode(metaData));
      page.path = pagePath;
      return page;
    } catch (e) {
      print('Failed to load page $magicPath/$pagePath: $e');
      return null;
    }
  }

  /// List all saved projects
  Future<List<Save>> listSaves() async {
    final List<Save> saves = [];

    try {
      if (!_workDir!.existsSync()) return saves;

      final dirs = _workDir!.listSync().whereType<Directory>();

      for (final dir in dirs) {
        final metaFile = File(path.join(dir.path, 'meta.json'));
        if (metaFile.existsSync()) {
          try {
            final save = await loadSave(path.basename(dir.path));
            if (save != null) {
              // Verify magic still exists
              final magic = await loadMagic(save.magic);
              if (magic == null) {
                // Magic no longer exists, delete save
                await deleteSave(path.basename(dir.path));
              } else {
                saves.add(save);
              }
            } else {
              // Invalid save, delete
              await deleteSave(path.basename(dir.path));
            }
          } catch (e) {
            print('Failed to load save ${dir.path}: $e');
            await deleteSave(path.basename(dir.path));
          }
        }
      }
    } catch (e) {
      print('Failed to list saves: $e');
    }

    // Sort by updated date, newest first
    saves.sort((a, b) => b.updated.compareTo(a.updated));
    return saves;
  }

  /// Generate next available filename for magic
  String nextFileName(String magicName) {
    int counter = 1;
    while (true) {
      final filename = '$magicName$counter';
      final dir = Directory(path.join(_workDir!.path, filename));
      if (!dir.existsSync()) {
        return filename;
      }
      counter++;
    }
  }

  /// Load saved project
  Future<Save?> loadSave(String savePath) async {
    try {
      final metaFile = File(path.join(_workDir!.path, savePath, 'meta.json'));
      if (!metaFile.existsSync()) return null;

      final metaData = await metaFile.readAsString();
      final save = Save.fromJson(json.decode(metaData));
      save.path = savePath;
      return save;
    } catch (e) {
      print('Failed to load save $savePath: $e');
      return null;
    }
  }

  /// Create new magic project
  Future<void> createMagic(String magicName, String projectPath) async {
    final projectDir = Directory(path.join(_workDir!.path, projectPath));
    if (!projectDir.existsSync()) {
      projectDir.createSync(recursive: true);
    }

    final save = Save(
      name: projectPath,
      magic: magicName,
      author: 'Me',
      created: DateTime.now(),
      updated: DateTime.now(),
    );
    save.path = projectPath;

    await updateSave(save);
  }

  /// Update/save project
  Future<void> updateSave(Save save) async {
    try {
      final projectDir = Directory(path.join(_workDir!.path, save.path!));
      if (!projectDir.existsSync()) {
        projectDir.createSync(recursive: true);
      }

      final updatedSave = save.copyWith(updated: DateTime.now());

      final metaFile = File(path.join(projectDir.path, 'meta.json'));
      await metaFile.writeAsString(json.encode(updatedSave.toJson()));
    } catch (e) {
      print('Failed to update save ${save.path}: $e');
      rethrow;
    }
  }

  /// Delete saved project
  Future<void> deleteSave(String savePath) async {
    try {
      final projectDir = Directory(path.join(_workDir!.path, savePath));
      if (projectDir.existsSync()) {
        await projectDir.delete(recursive: true);
      }
    } catch (e) {
      print('Failed to delete save $savePath: $e');
    }
  }

  /// Load processed slice bitmap
  Future<ui.Image?> loadSlice(
      String projectPath, int sourceId, int sliceId) async {
    try {
      final sliceFile = File(path.join(
          _workDir!.path, projectPath, sourceId.toString(), '$sliceId.png'));

      if (!sliceFile.existsSync()) return null;

      final bytes = await sliceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      print('Failed to load slice $projectPath/$sourceId/$sliceId: $e');
      return null;
    }
  }

  /// Save processed slice bitmap
  Future<void> saveSlice(
      String projectPath, int sourceId, int sliceId, Uint8List pngBytes) async {
    try {
      final sliceDir = Directory(
          path.join(_workDir!.path, projectPath, sourceId.toString()));
      if (!sliceDir.existsSync()) {
        sliceDir.createSync(recursive: true);
      }

      final sliceFile = File(path.join(sliceDir.path, '$sliceId.png'));
      await sliceFile.writeAsBytes(pngBytes);
    } catch (e) {
      print('Failed to save slice $projectPath/$sourceId/$sliceId: $e');
      rethrow;
    }
  }
}
