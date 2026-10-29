import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/author.dart';
import '../models/author_query.dart';
import '../models/genre.dart';
import '../models/json_read.dart';
import '../models/loan.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../models/simple_query.dart';
import 'api_repository.dart';
import 'author_repository.dart';
import 'entity_repository.dart';

abstract interface class GenreRepository
    implements EntityRepository<Genre, SimpleQuery> {}

abstract interface class PublisherRepository
    implements EntityRepository<Publisher, SimpleQuery> {}

abstract interface class ReaderRepository
    implements EntityRepository<Reader, SimpleQuery> {}

abstract interface class LoanRepository
    implements EntityRepository<Loan, SimpleQuery> {
  Future<void> issue({required int bookId, required int readerId, int days});

  /// Закрытие выдачи (возврат книги).
  Future<void> close(int id);

  /// Продление срока возврата.
  Future<void> extend(Loan loan, int days);
}

abstract interface class UserRepository
    implements EntityRepository<AppUser, SimpleQuery> {}

/// Сводные числа для экрана статистики.
abstract interface class StatsRepository {
  Future<List<(String, int)>> load();
}

class ApiAuthorRepository extends ApiRepository<Author, AuthorQuery>
    implements AuthorRepository {
  ApiAuthorRepository(Dio dio) : super(dio, '/authors');

  @override
  Author fromJson(Map<String, dynamic> json) => Author.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Author item) => {
    'fullName': item.fullName,
    'birthYear': item.birthYear,
    'country': item.country,
  };

  @override
  int idOf(Author item) => item.id;
}

class ApiGenreRepository extends ApiRepository<Genre, SimpleQuery>
    implements GenreRepository {
  ApiGenreRepository(Dio dio) : super(dio, '/genres');

  @override
  Genre fromJson(Map<String, dynamic> json) => Genre.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Genre item) => {
    'name': item.name,
    'description': item.description,
  };

  @override
  int idOf(Genre item) => item.id;
}

class ApiPublisherRepository extends ApiRepository<Publisher, SimpleQuery>
    implements PublisherRepository {
  ApiPublisherRepository(Dio dio) : super(dio, '/publishers');

  @override
  Publisher fromJson(Map<String, dynamic> json) => Publisher.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Publisher item) => {
    'name': item.name,
    'city': item.city,
    'foundedYear': item.foundedYear,
  };

  @override
  int idOf(Publisher item) => item.id;
}

class ApiReaderRepository extends ApiRepository<Reader, SimpleQuery>
    implements ReaderRepository {
  ApiReaderRepository(Dio dio) : super(dio, '/readers');

  @override
  Reader fromJson(Map<String, dynamic> json) => Reader.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Reader item) => {
    'fullName': item.fullName,
    'email': item.email,
    'phone': item.phone,
    if (item.card != null) 'card': item.card!.toJson(),
  };

  @override
  int idOf(Reader item) => item.id;
}

class ApiLoanRepository extends ApiRepository<Loan, SimpleQuery>
    implements LoanRepository {
  ApiLoanRepository(Dio dio) : super(dio, '/loans');

  @override
  Loan fromJson(Map<String, dynamic> json) => Loan.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Loan item) => {
    'dueAt': item.dueAt.toUtc().toIso8601String(),
  };

  @override
  int idOf(Loan item) => item.id;

  @override
  Future<void> issue({
    required int bookId,
    required int readerId,
    int days = 14,
  }) => guard(
    () => dio.post(
      '/loans',
      data: {'readerId': readerId, 'bookId': bookId, 'days': days},
    ),
  );

  @override
  Future<void> close(int id) => guard(() => dio.post('/loans/$id/return'));

  @override
  Future<void> extend(Loan loan, int days) => guard(
    () => dio.patch(
      '/loans/${loan.id}',
      data: {
        'dueAt': loan.dueAt.add(Duration(days: days)).toUtc().toIso8601String(),
      },
    ),
  );
}

class ApiUserRepository extends ApiRepository<AppUser, SimpleQuery>
    implements UserRepository {
  ApiUserRepository(Dio dio) : super(dio, '/users');

  @override
  AppUser fromJson(Map<String, dynamic> json) => AppUser.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(AppUser item) => item.toJson();

  @override
  int idOf(AppUser item) => item.id;
}

class ApiStatsRepository implements StatsRepository {
  final Dio _dio;

  ApiStatsRepository(this._dio);

  Future<int> _total(String path, [Map<String, dynamic> params = const {}]) =>
      guard(() async {
        final response = await _dio.get(
          path,
          queryParameters: {...params, 'size': 1},
        );
        return readInt((response.data as Map<String, dynamic>)['total']);
      });

  @override
  Future<List<(String, int)>> load() async {
    final values = await Future.wait([
      _total('/books'),
      _total('/readers'),
      _total('/loans', {'status': 'active'}),
      _total('/loans', {'status': 'overdue'}),
      _total('/users'),
    ]);
    return [
      ('Книг в каталоге', values[0]),
      ('Читателей', values[1]),
      ('Активных выдач', values[2]),
      ('Просроченных выдач', values[3]),
      ('Пользователей', values[4]),
    ];
  }
}
