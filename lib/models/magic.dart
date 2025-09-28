class MagicPoint {
  final int x;
  final int y;

  const MagicPoint({required this.x, required this.y});

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory MagicPoint.fromJson(Map<String, dynamic> json) =>
      MagicPoint(x: json['x'], y: json['y']);
}

class MagicTransform {
  final String type;
  final Map<String, dynamic> params;

  const MagicTransform({required this.type, required this.params});

  Map<String, dynamic> toJson() => {'type': type, 'params': params};

  factory MagicTransform.fromJson(Map<String, dynamic> json) =>
      MagicTransform(type: json['type'], params: json['params']);
}

class MagicSlice {
  final int id;
  final List<MagicPoint> polygon;
  final List<MagicTransform> transforms;

  const MagicSlice({
    required this.id,
    required this.polygon,
    this.transforms = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'polygon': polygon.map((p) => p.toJson()).toList(),
        'transforms': transforms.map((t) => t.toJson()).toList(),
      };

  factory MagicSlice.fromJson(Map<String, dynamic> json) => MagicSlice(
        id: json['id'],
        polygon: (json['polygon'] as List)
            .map((p) => MagicPoint.fromJson(p))
            .toList(),
        transforms: (json['transforms'] as List? ?? [])
            .map((t) => MagicTransform.fromJson(t))
            .toList(),
      );
}

class MagicSource {
  final int id;
  final int width;
  final int height;
  final String? mask;
  final List<MagicSlice> slices;

  const MagicSource({
    required this.id,
    required this.width,
    required this.height,
    this.mask,
    required this.slices,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'width': width,
        'height': height,
        'mask': mask,
        'slices': slices.map((s) => s.toJson()).toList(),
      };

  factory MagicSource.fromJson(Map<String, dynamic> json) => MagicSource(
        id: json['id'],
        width: json['width'],
        height: json['height'],
        mask: json['mask'],
        slices: (json['slices'] as List)
            .map((s) => MagicSlice.fromJson(s))
            .toList(),
      );
}

class MagicText {
  final int id;
  final String text;
  final String font;
  final int size;
  final String textColor;
  final String background;
  final List<MagicPoint> polygon;

  const MagicText({
    required this.id,
    required this.text,
    required this.font,
    required this.size,
    required this.textColor,
    required this.background,
    required this.polygon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'font': font,
        'size': size,
        'textColor': textColor,
        'background': background,
        'polygon': polygon.map((p) => p.toJson()).toList(),
      };

  factory MagicText.fromJson(Map<String, dynamic> json) => MagicText(
        id: json['id'],
        text: json['text'],
        font: json['font'],
        size: json['size'],
        textColor: json['textColor'],
        background: json['background'],
        polygon: (json['polygon'] as List)
            .map((p) => MagicPoint.fromJson(p))
            .toList(),
      );
}

class Magic {
  final String version;
  final String name;
  final String description;
  final String icon;
  final List<MagicSource> sources;
  final List<MagicText> texts;
  String? path;

  Magic({
    required this.version,
    required this.name,
    required this.description,
    required this.icon,
    required this.sources,
    required this.texts,
    this.path,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'name': name,
        'description': description,
        'icon': icon,
        'sources': sources.map((s) => s.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
      };

  factory Magic.fromJson(Map<String, dynamic> json) => Magic(
        version: json['version'] ?? '1.0',
        name: json['name'] ?? 'Unknown Magic',
        description: json['description'] ?? '',
        icon: json['icon'] ?? 'icon.png',
        sources: (json['sources'] as List? ?? [])
            .map((s) => MagicSource.fromJson(s))
            .toList(),
        texts: (json['texts'] as List? ?? [])
            .map((t) => MagicText.fromJson(t))
            .toList(),
      );
}