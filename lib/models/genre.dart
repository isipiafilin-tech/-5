import 'json_read.dart';

class Genre {
  final int id;
  final String name;
  final String description;
  final DateTime? deletedAt;

  const Genre({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Genre copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Genre(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
    id: readInt(json['id']),
    name: readString(json['name']),
    description: readString(json['description']),
    deletedAt: readDate(json['deletedAt']),
  );
}
