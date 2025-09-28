import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/magic.dart';
import '../models/page.dart';
import '../models/save.dart';

class MagicManager {
  static MagicManager? _instance;
  static MagicManager get instance => _instance ??= MagicManager._();

  MagicManager._();

  String? _deviceId;
  List<String> _vipDevices = [];
  final Map<String, Save> _saves = {}; // In-memory storage for web

  /// Initialize the manager with device ID and VIP list
  Future<void> initialize() async {
    // Generate a device ID for web
    _deviceId = 'web_device_${DateTime.now().millisecondsSinceEpoch}';

    // Load VIP devices from assets
    await _loadVipDevices();

    print('MagicManager initialized for web platform');
  }

  Future<void> _loadVipDevices() async {
    try {
      final deviceData = await rootBundle.loadString('assets/devices.json');
      final List<dynamic> devices = json.decode(deviceData);
      _vipDevices = devices.cast<String>();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load VIP devices: $e');
      }
      _vipDevices = [];
    }
  }

  /// Check if current device is VIP
  bool get isVip => _vipDevices.contains(_deviceId);

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

    // For demo purposes, create some sample magic templates
    magics.add(Magic(
      version: '1.0',
      name: 'Sample Magic',
      description: 'Demo magic template',
      icon: 'icon.png',
      sources: [],
      texts: [],
      path: 'sample',
    ));

    magics.add(Magic(
      version: '1.0',
      name: 'Photo Frame',
      description: 'Photo frame template',
      icon: 'frame.png',
      sources: [],
      texts: [],
      path: 'frame',
    ));

    return magics;
  }

  /// Load magic template metadata
  Future<Magic?> loadMagic(String magicPath) async {
    // Return sample magic based on path
    switch (magicPath) {
      case 'sample':
        return Magic(
          version: '1.0',
          name: 'Sample Magic',
          description: 'Demo magic template',
          icon: 'icon.png',
          sources: [],
          texts: [],
          path: magicPath,
        );
      case 'frame':
        return Magic(
          version: '1.0',
          name: 'Photo Frame',
          description: 'Photo frame template',
          icon: 'frame.png',
          sources: [],
          texts: [],
          path: magicPath,
        );
      default:
        return null;
    }
  }

  /// Load bitmap from magic assets
  Future<ui.Image?> loadMagicBitmap(String magicPath, String filename) async {
    // Mock implementation for web - would normally load from assets
    if (kDebugMode) {
      print('Loading bitmap: $magicPath/$filename');
    }
    return null;
  }

  /// List pages for a magic template
  Future<List<PageHead>> listPages(String magicPath) async {
    // Return sample page
    return [
      PageHead(
        version: '1.0',
        name: 'Default Page',
        description: 'Default page layout',
        pages: [
          const Page(
            id: 1,
            file: 'page1.png',
          )
        ],
        path: 'default',
      )
    ];
  }

  /// Load page metadata
  Future<PageHead?> loadPage(String magicPath, String pagePath) async {
    return PageHead(
      version: '1.0',
      name: 'Default Page',
      description: 'Default page layout',
      pages: [
        const Page(
          id: 1,
          file: 'page1.png',
        )
      ],
      path: pagePath,
    );
  }

  /// List all saved projects
  Future<List<Save>> listSaves() async {
    return _saves.values.toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));
  }

  /// Generate next available filename for magic
  String nextFileName(String magicName) {
    int counter = 1;
    while (true) {
      final filename = '$magicName$counter';
      if (!_saves.containsKey(filename)) {
        return filename;
      }
      counter++;
    }
  }

  /// Load saved project
  Future<Save?> loadSave(String savePath) async {
    return _saves[savePath];
  }

  /// Create new magic project
  Future<void> createMagic(String magicName, String projectPath) async {
    final save = Save(
      name: projectPath,
      magic: magicName,
      author: 'Me',
      created: DateTime.now(),
      updated: DateTime.now(),
    );
    save.path = projectPath;

    _saves[projectPath] = save;
  }

  /// Update/save project
  Future<void> updateSave(Save save) async {
    final updatedSave = save.copyWith(updated: DateTime.now());
    _saves[save.path!] = updatedSave;
  }

  /// Delete saved project
  Future<void> deleteSave(String savePath) async {
    _saves.remove(savePath);
  }

  /// Load processed slice bitmap
  Future<ui.Image?> loadSlice(
      String projectPath, int sourceId, int sliceId) async {
    // Mock implementation for web
    if (kDebugMode) {
      print('Loading slice: $projectPath/$sourceId/$sliceId');
    }
    return null;
  }

  /// Save processed slice bitmap
  Future<void> saveSlice(
      String projectPath, int sourceId, int sliceId, Uint8List pngBytes) async {
    // Mock implementation for web
    if (kDebugMode) {
      print(
          'Saving slice: $projectPath/$sourceId/$sliceId (${pngBytes.length} bytes)');
    }
  }
}
