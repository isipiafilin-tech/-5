import 'json_read.dart';

/// Читательский билет. Связь с читателем один к одному: билет приходит
/// вложенным объектом и редактируется в форме читателя.
class LibraryCard {
  final String number;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const LibraryCard({
    required this.number,
    required this.issuedAt,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'number': number,
    'issuedAt': issuedAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory LibraryCard.fromJson(Map<String, dynamic> json) => LibraryCard(
    number: readString(json['number']),
    issuedAt: readDate(json['issuedAt']) ?? DateTime(2000),
    expiresAt: readDate(json['expiresAt']) ?? DateTime(2000),
  );
}

class Reader {
  final int id;
  final String fullName;
  final String email;
  final String phone;

  /// Сервер не создаёт билет для новых читателей, поэтому его может не быть.
  final LibraryCard? card;
  final DateTime? deletedAt;

  const Reader({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.card,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Reader copyWith({
    int? id,
    String? fullName,
    String? email,
    String? phone,
    LibraryCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Reader(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'phone': phone,
    'card': card?.toJson(),
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Reader.fromJson(Map<String, dynamic> json) => Reader(
    id: readInt(json['id']),
    fullName: readString(json['fullName']),
    email: readString(json['email']),
    phone: readString(json['phone']),
    card: json['card'] is Map<String, dynamic>
        ? LibraryCard.fromJson(json['card'] as Map<String, dynamic>)
        : null,
    deletedAt: readDate(json['deletedAt']),
  );
}
