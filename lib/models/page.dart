import 'magic.dart';

class PageFace {
  final int source;
  final int slice;
  final double x;
  final double y;
  final double angle;
  final double scale;
  final List<MagicTransform> transforms;

  const PageFace({
    required this.source,
    required this.slice,
    required this.x,
    required this.y,
    this.angle = 0,
    this.scale = 1,
    this.transforms = const [],
  });

  Map<String, dynamic> toJson() => {
        'source': source,
        'slice': slice,
        'x': x,
        'y': y,
        'angle': angle,
        'scale': scale,
        'transforms': transforms.map((t) => t.toJson()).toList(),
      };

  factory PageFace.fromJson(Map<String, dynamic> json) => PageFace(
        source: json['source'] ?? 1,
        slice: json['slice'] ?? 1,
        x: json['x']?.toDouble() ?? 0,
        y: json['y']?.toDouble() ?? 0,
        angle: json['angle']?.toDouble() ?? 0,
        scale: json['scale']?.toDouble() ?? 1,
        transforms: (json['transforms'] as List? ?? [])
            .map((t) => MagicTransform.fromJson(t))
            .toList(),
      );
}

class PageTextFace {
  final int text;
  final double x;
  final double y;
  final double angle;

  const PageTextFace({
    required this.text,
    required this.x,
    required this.y,
    this.angle = 0,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'x': x,
        'y': y,
        'angle': angle,
      };

  factory PageTextFace.fromJson(Map<String, dynamic> json) => PageTextFace(
        text: json['text'],
        x: json['x'].toDouble(),
        y: json['y'].toDouble(),
        angle: json['angle']?.toDouble() ?? 0,
      );
}

class PageWatermark {
  final String src;
  final double scale;
  final double x;
  final double y;
  final double angle;

  const PageWatermark({
    required this.src,
    this.scale = 1,
    required this.x,
    required this.y,
    this.angle = 0,
  });

  Map<String, dynamic> toJson() => {
        'src': src,
        'scale': scale,
        'x': x,
        'y': y,
        'angle': angle,
      };

  factory PageWatermark.fromJson(Map<String, dynamic> json) => PageWatermark(
        src: json['src'] ?? 'watermark.png',
        scale: json['scale']?.toDouble() ?? 1,
        x: json['x']?.toDouble() ?? 0,
        y: json['y']?.toDouble() ?? 0,
        angle: json['angle']?.toDouble() ?? 0,
      );
}

class PageSection {
  final double offsetX;
  final double offsetY;
  final List<PageFace> faces;
  final double scale;
  final int dpi;
  final double grid;

  const PageSection({
    required this.offsetX,
    required this.offsetY,
    required this.faces,
    this.scale = 1,
    this.dpi = 90,
    this.grid = 1,
  });

  Map<String, dynamic> toJson() => {
        'offsetX': offsetX,
        'offsetY': offsetY,
        'faces': faces.map((f) => f.toJson()).toList(),
        'scale': scale,
        'dpi': dpi,
        'grid': grid,
      };

  factory PageSection.fromJson(Map<String, dynamic> json) => PageSection(
        offsetX: json['offsetX'].toDouble(),
        offsetY: json['offsetY'].toDouble(),
        faces:
            (json['faces'] as List).map((f) => PageFace.fromJson(f)).toList(),
        scale: json['scale']?.toDouble() ?? 1,
        dpi: json['dpi'] ?? 90,
        grid: json['grid']?.toDouble() ?? 1,
      );
}

class Page {
  final int id;
  final double offsetX;
  final double offsetY;
  final String file;
  final List<PageFace> faces;
  final List<PageSection> sections;
  final List<PageTextFace> texts;
  final List<PageWatermark> watermarks;

  const Page({
    required this.id,
    this.offsetX = 0,
    this.offsetY = 0,
    required this.file,
    this.faces = const [],
    this.sections = const [],
    this.texts = const [],
    this.watermarks = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'offsetX': offsetX,
        'offsetY': offsetY,
        'file': file,
        'faces': faces.map((f) => f.toJson()).toList(),
        'sections': sections.map((s) => s.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
        'watermarks': watermarks.map((w) => w.toJson()).toList(),
      };

  factory Page.fromJson(Map<String, dynamic> json) => Page(
        id: json['id'] ?? 1,
        offsetX: json['offsetX']?.toDouble() ?? 0,
        offsetY: json['offsetY']?.toDouble() ?? 0,
        file: json['file'] ?? 'unknown.png',
        faces: (json['faces'] as List? ?? [])
            .map((f) => PageFace.fromJson(f))
            .toList(),
        sections: (json['sections'] as List? ?? [])
            .map((s) => PageSection.fromJson(s))
            .toList(),
        texts: (json['texts'] as List? ?? [])
            .map((t) => PageTextFace.fromJson(t))
            .toList(),
        watermarks: (json['watermarks'] as List? ?? [])
            .map((w) => PageWatermark.fromJson(w))
            .toList(),
      );
}

class PageHead {
  final String version;
  final String name;
  final String description;
  final double scale;
  final int width;
  final int height;
  final int dpi;
  final double grid;
  final List<Page> pages;
  String? path;

  PageHead({
    required this.version,
    required this.name,
    this.description = '',
    this.scale = 1,
    this.width = 2480,
    this.height = 3508,
    this.dpi = 90,
    this.grid = 1,
    required this.pages,
    this.path,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'name': name,
        'description': description,
        'scale': scale,
        'width': width,
        'height': height,
        'dpi': dpi,
        'grid': grid,
        'pages': pages.map((p) => p.toJson()).toList(),
      };

  factory PageHead.fromJson(Map<String, dynamic> json) => PageHead(
        version: json['version'] ?? '1.0',
        name: json['name'] ?? 'Unknown Page',
        description: json['description'] ?? '',
        scale: json['scale']?.toDouble() ?? 1,
        width: json['width'] ?? 2480,
        height: json['height'] ?? 3508,
        dpi: json['dpi'] ?? 90,
        grid: json['grid']?.toDouble() ?? 1,
        pages: (json['pages'] as List).map((p) => Page.fromJson(p)).toList(),
      );
}
