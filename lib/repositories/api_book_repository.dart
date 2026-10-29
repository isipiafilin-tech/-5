import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/book.dart';
import '../models/book_query.dart';
import '../models/json_read.dart';
import 'api_repository.dart';
import 'book_repository.dart';

class ApiBookRepository extends ApiRepository<Book, BookQuery>
    implements BookRepository {
  ApiBookRepository(Dio dio) : super(dio, '/books');

  @override
  Book fromJson(Map<String, dynamic> json) => Book.fromJson(json);

  @override
  Map<String, dynamic> toWriteJson(Book item) => item.toWriteJson();

  @override
  int idOf(Book item) => item.id;

  @override
  Map<String, dynamic> filters(BookQuery q) => {
    if (q.genreId != null) 'genreId': q.genreId,
    if (q.publisherId != null) 'publisherId': q.publisherId,
    if (q.yearFrom != null) 'yearFrom': q.yearFrom,
    if (q.yearTo != null) 'yearTo': q.yearTo,
  };

  @override
  Future<int> countByPublisher(int publisherId) => guard(() async {
    final response = await dio.get(
      path,
      queryParameters: {
        'publisherId': publisherId,
        'includeDeleted': true,
        'size': 1,
      },
    );
    return readInt((response.data as Map<String, dynamic>)['total']);
  });
}
