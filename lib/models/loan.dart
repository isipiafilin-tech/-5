import 'json_read.dart';

class Loan {
  final int id;
  final int bookId;
  final String bookTitle;
  final int readerId;
  final String readerName;
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;

  /// active, returned или overdue.
  final String status;
  final DateTime? deletedAt;

  const Loan({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.readerId,
    required this.readerName,
    required this.issuedAt,
    required this.dueAt,
    required this.status,
    this.returnedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isOpen => status != 'returned';

  String get statusLabel => switch (status) {
    'returned' => 'Возвращена',
    'overdue' => 'Просрочена',
    _ => 'Выдана',
  };

  factory Loan.fromJson(Map<String, dynamic> json) {
    final book = readMap(json['book']);
    final reader = readMap(json['reader']);
    return Loan(
      id: readInt(json['id']),
      bookId: readInt(book['id']),
      bookTitle: readString(book['title']),
      readerId: readInt(reader['id']),
      readerName: readString(reader['fullName']),
      issuedAt: readDate(json['issuedAt']) ?? DateTime(2000),
      dueAt: readDate(json['dueAt']) ?? DateTime(2000),
      returnedAt: readDate(json['returnedAt']),
      status: readString(json['status'], 'active'),
      deletedAt: readDate(json['deletedAt']),
    );
  }
}
