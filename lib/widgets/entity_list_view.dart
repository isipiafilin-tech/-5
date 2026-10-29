import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import '../state/list_notifier.dart';
import 'entity_table.dart';
import 'pagination_bar.dart';

/// Тело экрана списка: четыре состояния загрузки, выделение с удалением,
/// таблица или карточки, постраничная навигация.
///
/// Изменение сортировки и страницы передаётся наверх через колбэки:
/// экран записывает новые условия в адрес, а не в состояние напрямую.
class EntityListView<T> extends StatelessWidget {
  final ListNotifier<T, Object> notifier;
  final List<TableColumnSpec<T>> columns;
  final int Function(T item) idOf;
  final bool Function(T item) isDeleted;
  final String Function(T item) titleOf;
  final String sortField;
  final bool sortAscending;
  final void Function(String field) onSort;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onSize;
  final ValueChanged<T>? onOpen;
  final VoidCallback onReset;

  /// Права текущей роли: изменение и удаление, восстановление и физическое
  /// удаление. Недоступные кнопки не показываются.
  final bool canEdit;
  final bool canAdmin;

  /// Дополнительные действия в строке, например «Закрыть выдачу».
  final List<Widget> Function(T item)? extraActions;

  const EntityListView({
    super.key,
    required this.notifier,
    required this.columns,
    required this.idOf,
    required this.isDeleted,
    required this.titleOf,
    required this.sortField,
    required this.sortAscending,
    required this.onSort,
    required this.onPage,
    required this.onSize,
    required this.onOpen,
    required this.onReset,
    this.canEdit = true,
    this.canAdmin = true,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final result = notifier.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canEdit && notifier.hasSelection) _selectionBar(context),
        if (notifier.status == LoadStatus.loading && result.items.isNotEmpty)
          const LinearProgressIndicator(),
        Expanded(child: _body(context)),
        if (notifier.status == LoadStatus.success && result.total > 0)
          PaginationBar(page: result, onPage: onPage, onSize: onSize),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final items = notifier.result.items;

    switch (notifier.status) {
      case LoadStatus.idle:
      case LoadStatus.loading when items.isEmpty:
        return const Center(child: CircularProgressIndicator());
      case LoadStatus.error:
        return _message(
          icon: Icon(Icons.error_outline, size: 56, color: scheme.error),
          title: Text(
            notifier.error!,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(color: scheme.error),
          ),
          action: FilledButton.icon(
            onPressed: notifier.load,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        );
      case LoadStatus.success when items.isEmpty:
        return _message(
          icon: Icon(Icons.search_off, size: 56, color: scheme.outline),
          title: Text('Ничего не найдено', style: textTheme.titleMedium),
          action: OutlinedButton(
            onPressed: onReset,
            child: const Text('Сбросить условия отбора'),
          ),
        );
      default:
        return EntityTable<T>(
          columns: columns,
          items: items,
          idOf: idOf,
          isDeleted: isDeleted,
          selected: notifier.selected,
          onToggleSelect: canEdit ? notifier.toggleSelection : null,
          sortField: sortField,
          sortAscending: sortAscending,
          onSort: onSort,
          onOpen: onOpen,
          actions: (item) => [
            ...?extraActions?.call(item),
            ..._actions(context, item),
          ],
        );
    }
  }

  Widget _message({
    required Widget icon,
    required Widget title,
    required Widget action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            title,
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }

  Widget _selectionBar(BuildContext context) {
    final count = notifier.selected.length;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text('Выбрано: $count')),
            FilledButton.icon(
              onPressed: () async {
                final reason = await _run(
                  context,
                  notifier.deleteSelectedBlockReason,
                );
                if (!context.mounted) return;
                if (reason != null) return _blocked(context, reason);
                if (await _confirm(
                  context,
                  'Удалить выбранные записи ($count)?',
                  'Записи будут помечены удалёнными, их можно восстановить.',
                )) {
                  if (context.mounted) {
                    await _run(context, notifier.deleteSelected);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Удалить выбранные'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context, T item) {
    final id = idOf(item);
    if (!canEdit) return const [];
    if (isDeleted(item) && !canAdmin) return const [];
    if (isDeleted(item)) {
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () => _run(context, () => notifier.restore(id)),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever_outlined),
          color: Theme.of(context).colorScheme.error,
          onPressed: () async {
            final reason = await _run(
              context,
              () => notifier.deleteBlockReason(id),
            );
            if (!context.mounted) return;
            if (reason != null) return _blocked(context, reason);
            if (await _confirm(
              context,
              'Удалить «${titleOf(item)}» навсегда?',
              'Запись будет стёрта, восстановить её будет нельзя.',
            )) {
              if (context.mounted) {
                await _run(context, () => notifier.hardDelete(id));
              }
            }
          },
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final reason = await _run(
            context,
            () => notifier.deleteBlockReason(id),
          );
          if (!context.mounted) return;
          if (reason != null) return _blocked(context, reason);
          if (await _confirm(
            context,
            'Удалить «${titleOf(item)}»?',
            'Запись будет помечена удалённой, её можно восстановить.',
          )) {
            if (context.mounted) {
              await _run(context, () => notifier.softDelete(id));
            }
          }
        },
      ),
    ];
  }

  /// Выполняет операцию; ошибку сервера (403, 409, сбой сети)
  /// показывает сообщением, а не роняет экран.
  Future<R?> _run<R>(BuildContext context, Future<R> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    }
  }

  /// Удаление запрещено связями: сообщаем причину вместо подтверждения.
  Future<void> _blocked(BuildContext context, String reason) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.block),
      title: const Text('Удаление невозможно'),
      content: Text(reason),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );

  Future<bool> _confirm(BuildContext context, String title, String text) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
