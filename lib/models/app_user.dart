import 'json_read.dart';

enum Role {
  reader('Читатель'),
  librarian('Библиотекарь'),
  admin('Администратор');

  const Role(this.label);

  final String label;

  static Role parse(Object? value) =>
      Role.values.firstWhere((r) => r.name == value, orElse: () => Role.reader);
}

/// Учётная запись пользователя (контракт API, раздел 2).
class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final Role role;
  final int? readerId;

  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.readerId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.name,
    'readerId': readerId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: readInt(json['id']),
    username: readString(json['username']),
    fullName: readString(json['fullName']),
    email: readString(json['email']),
    role: Role.parse(json['role']),
    readerId: json['readerId'] is int ? json['readerId'] as int : null,
  );
}
