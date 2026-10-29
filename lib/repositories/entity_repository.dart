import '../models/page_result.dart';

/// Операции, общие для всех сущностей каталога: [T] — модель, [Q] — условия отбора.
abstract interface class EntityRepository<T, Q> {
  Future<PageResult<T>> find(Q query);

  /// Все записи без постраничного вывода — для выпадающих списков и подписей.
  Future<List<T>> findAll({bool includeDeleted = false});
  Future<T?> findById(int id);
  Future<T> create(T item);
  Future<T> update(T item);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}

/// Ошибка источника данных; текст показывается пользователю как есть.
class RepositoryException implements Exception {
  final String message;

  const RepositoryException(this.message);

  @override
  String toString() => message;
}
