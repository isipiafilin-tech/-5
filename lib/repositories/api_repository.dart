import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/json_read.dart';
import '../models/page_result.dart';
import '../models/query_params.dart';
import 'entity_repository.dart';

/// Общая реализация репозитория поверх REST API.
///
/// Набор операций у всех ресурсов одинаковый (раздел 3 контракта),
/// поэтому наследник задаёт только адрес, разбор и тело на запись.
abstract class ApiRepository<T, Q extends ListQuery<Q>>
    implements EntityRepository<T, Q> {
  final Dio dio;
  final String path;
  CancelToken? _findToken;

  ApiRepository(this.dio, this.path);

  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toWriteJson(T item);
  int idOf(T item);

  /// Дополнительные фильтры ресурса.
  Map<String, dynamic> filters(Q q) => const {};

  @override
  Future<PageResult<T>> find(Q q) {
    // Новый запрос списка отменяет предыдущий незавершённый: иначе ответ
    // на устаревший запрос может прийти последним и попасть на экран.
    _findToken?.cancel();
    final token = _findToken = CancelToken();
    return guard(() async {
      final response = await dio.get(
        path,
        queryParameters: {
          if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
          ...filters(q),
          'sort': '${q.sortField},${q.sortAscending ? 'asc' : 'desc'}',
          'page': q.page,
          'size': q.size,
          if (q.includeDeleted) 'includeDeleted': true,
        },
        cancelToken: token,
      );
      return _page(response.data, q.size);
    });
  }

  PageResult<T> _page(dynamic body, int size) {
    final data = body as Map<String, dynamic>;
    return PageResult(
      items: (data['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(),
      page: readInt(data['page'], 1),
      size: readInt(data['size'], size),
      total: readInt(data['total']),
    );
  }

  @override
  Future<List<T>> findAll({bool includeDeleted = false}) => guard(() async {
    final response = await dio.get(
      path,
      queryParameters: {
        'size': 100,
        if (includeDeleted) 'includeDeleted': true,
      },
    );
    return _page(response.data, 100).items;
  });

  @override
  Future<T?> findById(int id) async {
    try {
      return await guard(() async {
        final response = await dio.get(
          '$path/$id',
          queryParameters: {'includeDeleted': true},
        );
        return fromJson(response.data as Map<String, dynamic>);
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<T> create(T item) => guard(() async {
    final response = await dio.post(path, data: toWriteJson(item));
    return fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<T> update(T item) => guard(() async {
    final response = await dio.put(
      '$path/${idOf(item)}',
      data: toWriteJson(item),
    );
    return fromJson(response.data as Map<String, dynamic>);
  });

  @override
  Future<void> softDelete(int id) => guard(() => dio.delete('$path/$id'));

  @override
  Future<void> hardDelete(int id) =>
      guard(() => dio.delete('$path/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) => guard(() => dio.post('$path/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await dio.post('$path/bulk-delete', data: {'ids': ids});
    return readInt((response.data as Map<String, dynamic>)['deleted']);
  });
}
