class Save {
  final String name;
  final String magic;
  final String author;
  final DateTime created;
  final DateTime updated;
  final bool? ready;
  String? path;

  Save({
    required this.name,
    required this.magic,
    required this.author,
    required this.created,
    required this.updated,
    this.ready,
    this.path,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'magic': magic,
        'author': author,
        'created': created.toIso8601String(),
        'updated': updated.toIso8601String(),
        'ready': ready,
      };

  factory Save.fromJson(Map<String, dynamic> json) => Save(
        name: json['name'],
        magic: json['magic'],
        author: json['author'],
        created: DateTime.parse(json['created']),
        updated: DateTime.parse(json['updated']),
        ready: json['ready'],
      );

  Save copyWith({
    String? name,
    String? magic,
    String? author,
    DateTime? created,
    DateTime? updated,
    bool? ready,
    String? path,
  }) =>
      Save(
        name: name ?? this.name,
        magic: magic ?? this.magic,
        author: author ?? this.author,
        created: created ?? this.created,
        updated: updated ?? this.updated,
        ready: ready ?? this.ready,
        path: path ?? this.path,
      );
}