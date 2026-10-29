import 'json_read.dart';

class Book {
  final int id;
  final String title;
  final String isbn;
  final int year;
  final int pages;
  final int publisherId;
  final List<int> authorIds;
  final List<int> genreIds;
  final int copiesTotal;
  final int copiesAvailable;
  final DateTime? deletedAt;

  const Book({
    required this.id,
    required this.title,
    required this.isbn,
    required this.year,
    required this.pages,
    required this.publisherId,
    required this.authorIds,
    required this.genreIds,
    required this.copiesTotal,
    required this.copiesAvailable,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  /// [clearDeletedAt] нужен, чтобы отличить «не менять deletedAt»
  /// от «сбросить deletedAt в null»: в обоих случаях deletedAt == null.
  Book copyWith({
    int? id,
    String? title,
    String? isbn,
    int? year,
    int? pages,
    int? publisherId,
    List<int>? authorIds,
    List<int>? genreIds,
    int? copiesTotal,
    int? copiesAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      isbn: isbn ?? this.isbn,
      year: year ?? this.year,
      pages: pages ?? this.pages,
      publisherId: publisherId ?? this.publisherId,
      authorIds: authorIds ?? this.authorIds,
      genreIds: genreIds ?? this.genreIds,
      copiesTotal: copiesTotal ?? this.copiesTotal,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isbn': isbn,
    'year': year,
    'pages': pages,
    'publisherId': publisherId,
    'authorIds': authorIds,
    'genreIds': genreIds,
    'copiesTotal': copiesTotal,
    'copiesAvailable': copiesAvailable,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  /// Разбирает обе формы: на запись уходят publisherId, authorIds, genreIds,
  /// а с сервера приходят развёрнутые объекты publisher, authors, genres.
  factory Book.fromJson(Map<String, dynamic> json) => Book(
    id: readInt(json['id']),
    title: readString(json['title']),
    isbn: readString(json['isbn']),
    year: readInt(json['year']),
    pages: readInt(json['pages']),
    publisherId: json.containsKey('publisherId')
        ? readInt(json['publisherId'])
        : readInt(readMap(json['publisher'])['id']),
    authorIds: json.containsKey('authorIds')
        ? readIntList(json['authorIds'])
        : readIdList(json['authors']),
    genreIds: json.containsKey('genreIds')
        ? readIntList(json['genreIds'])
        : readIdList(json['genres']),
    copiesTotal: readInt(json['copiesTotal']),
    copiesAvailable: readInt(json['copiesAvailable']),
    deletedAt: readDate(json['deletedAt']),
  );

  /// Тело запроса на создание и изменение по контракту API.
  Map<String, dynamic> toWriteJson() => {
    'title': title,
    'isbn': isbn,
    'year': year,
    'pages': pages,
    'publisherId': publisherId,
    'authorIds': authorIds,
    'genreIds': genreIds,
    'copiesTotal': copiesTotal,
  };
}
