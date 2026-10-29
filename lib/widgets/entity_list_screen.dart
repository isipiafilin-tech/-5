import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/query_params.dart';
import '../state/list_notifier.dart';
import 'catalog_scaffold.dart';
import 'debounced_text_field.dart';
import 'entity_list_view.dart';
import 'entity_table.dart';

/// Общий экран списка: поиск, фильтры, показ удалённых, таблица,
/// кнопка создания. Условия отбора берутся из адреса и пишутся в адрес.
class EntityListScreen<T, Q extends ListQuery<Q>> extends StatefulWidget {
  final String title;

  /// null — сервер не умеет искать по этому ресурсу, поле не показывается.
  final String? searchLabel;
  final Q query;
  final ListNotifier<T, Q> notifier;
  final List<TableColumnSpec<T>> columns;
  final int Function(T item) idOf;
  final bool Function(T item) isDeleted;
  final String Function(T item) titleOf;

  /// Дополнительные фильтры сущности; [go] переходит на адрес с новыми условиями.
  final List<Widget> Function(Q query, void Function(Q next) go)? filters;

  /// Права текущей роли; недоступные элементы не показываются.
  final bool canEdit;
  final bool canAdmin;

  /// Есть ли у записи карточка.
  final bool openable;
  final List<Widget> Function(T item)? extraActions;

  const EntityListScreen({
    super.key,
    required this.title,
    required this.searchLabel,
    required this.query,
    required this.notifier,
    required this.columns,
    required this.idOf,
    required this.isDeleted,
    required this.titleOf,
    this.filters,
    this.canEdit = true,
    this.canAdmin = true,
    this.openable = true,
    this.extraActions,
  });

  @override
  State<EntityListScreen<T, Q>> createState() => _EntityListScreenState<T, Q>();
}

class _EntityListScreenState<T, Q extends ListQuery<Q>>
    extends State<EntityListScreen<T, Q>> {
  @override
  void initState() {
    super.initState();
    // При открытии экрана список всегда загружается заново: после смены
    // пользователя в памяти не должно остаться чужих данных.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.notifier.applyQuery(widget.query);
    });
  }

  @override
  void didUpdateWidget(EntityListScreen<T, Q> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _sync();
  }

  /// Адрес изменился (переход, «назад», новая вкладка) — подгружаем список.
  /// После кадра, потому что загрузка сразу вызывает notifyListeners.
  void _sync() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) widget.notifier.syncWith(widget.query);
  });

  /// Любое изменение условий отбора — это переход на новый адрес.
  void _go(Q query) => context.go(query.toUri().toString());

  String get _path => widget.query.toUri().path;

  @override
  Widget build(BuildContext context) {
    final q = widget.query;
    return CatalogScaffold(
      title: widget.title,
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.go('$_path/new'),
              icon: const Icon(Icons.add),
              label: const Text('Добавить'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.searchLabel != null)
                  SizedBox(
                    width: 280,
                    child: DebouncedTextField(
                      label: widget.searchLabel!,
                      icon: Icons.search,
                      value: q.search,
                      onChanged: (v) => _go(q.withCommon(search: v)),
                    ),
                  ),
                ...?widget.filters?.call(q, _go),
                if (widget.canAdmin)
                  FilterChip(
                    label: const Text('Показывать удалённые'),
                    selected: q.includeDeleted,
                    onSelected: (v) => _go(q.withCommon(includeDeleted: v)),
                  ),
                TextButton(
                  onPressed: () => _go(q.reset),
                  child: const Text('Сбросить'),
                ),
              ],
            ),
          ),
          Expanded(
            child: EntityListView<T>(
              notifier: widget.notifier,
              columns: widget.columns,
              idOf: widget.idOf,
              isDeleted: widget.isDeleted,
              titleOf: widget.titleOf,
              sortField: q.sortField,
              sortAscending: q.sortAscending,
              onSort: (field) => _go(
                q.withCommon(
                  sortField: field,
                  sortAscending: field == q.sortField ? !q.sortAscending : true,
                ),
              ),
              onPage: (page) => _go(q.withCommon(page: page)),
              onSize: (size) => _go(q.withCommon(size: size)),
              // Карточка вложена в список: параметры отбора сохраняются
              // в адресе, и «назад» возвращает к тому же списку.
              onOpen: widget.openable
                  ? (item) => context.go(
                      listUri(
                        '$_path/${widget.idOf(item)}',
                        q.toQueryParameters(),
                      ).toString(),
                    )
                  : null,
              onReset: () => _go(q.reset),
              canEdit: widget.canEdit,
              canAdmin: widget.canAdmin,
              extraActions: widget.extraActions,
            ),
          ),
        ],
      ),
    );
  }
}
