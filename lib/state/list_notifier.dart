import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import '../repositories/entity_repository.dart';

enum LoadStatus { idle, loading, success, error }

/// Состояние экрана списка: условия отбора, текущая страница, выделение,
/// а также операции сохранения и удаления записей.
///
/// Общее для всех сущностей; отличаются только типы [T] и [Q].
class ListNotifier<T, Q> extends ChangeNotifier {
  final EntityRepository<T, Q> _repository;
  final int Function(T item) _idOf;

  /// Вызывается после любого изменения данных — например, чтобы обновить
  /// списки для выпадающих полей.
  final VoidCallback? onChanged;

  ListNotifier(this._repository, Q initialQuery, this._idOf, {this.onChanged})
    : _query = initialQuery;

  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<int> _selected = {};
  int _loadSeq = 0;

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    // Ответ на устаревший запрос (его отменил более новый) не показываем.
    final seq = ++_loadSeq;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final result = await _repository.find(_query);
      if (seq != _loadSeq) return;
      _result = result;
      _status = LoadStatus.success;
    } catch (e) {
      if (seq != _loadSeq) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> applyQuery(Q next) async {
    _query = next;
    _selected.clear(); // выделение теряет смысл при смене условий отбора
    await load();
  }

  /// Вызывается экраном, когда меняется адрес: загружает список,
  /// только если условия из адреса отличаются от текущих.
  Future<void> syncWith(Q fromAddress) async {
    if (fromAddress != _query || _status == LoadStatus.idle) {
      await applyQuery(fromAddress);
    }
  }

  void toggleSelection(int id) {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
    notifyListeners();
  }

  Future<T?> findById(int id) => _repository.findById(id);
  Future<List<T>> all() => _repository.findAll();

  /// Создаёт запись (id == 0) или сохраняет изменения существующей.
  Future<T> save(T item) async {
    final saved = _idOf(item) == 0
        ? await _repository.create(item)
        : await _repository.update(item);
    await _afterChange();
    return saved;
  }

  /// Причина, по которой запись нельзя удалить, или null.
  /// Переопределяется там, где на запись ссылаются другие сущности.
  Future<String?> deleteBlockReason(int id) async => null;

  Future<String?> deleteSelectedBlockReason() async {
    for (final id in _selected) {
      final reason = await deleteBlockReason(id);
      if (reason != null) return reason;
    }
    return null;
  }

  Future<void> deleteSelected() async {
    await _repository.deleteMany(_selected.toList());
    await _afterChange();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    await _afterChange();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    await _afterChange();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await _afterChange();
  }

  Future<void> _afterChange() async {
    _selected.clear();
    onChanged?.call();
    if (_status != LoadStatus.idle) await load();
  }
}
