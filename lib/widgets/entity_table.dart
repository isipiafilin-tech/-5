import 'package:flutter/material.dart';

/// Описание колонки: подпись, поле сортировки и способ отрисовки ячейки.
class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

/// Обобщённая таблица для любой сущности.
///
/// При ширине окна от 600 пикселей — DataTable с двумерной прокруткой,
/// на узком окне — список карточек, собранных из тех же колонок.
class EntityTable<T> extends StatelessWidget {
  static const narrowWidth = 600.0;

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final int Function(T item) idOf;
  final Set<int> selected;
  final ValueChanged<int>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final ValueChanged<T>? onOpen;
  final bool Function(T item)? isDeleted;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.onOpen,
    this.isDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery.sizeOf(context).width < narrowWidth
        ? _buildCards(context)
        : _buildTable(context);
  }

  Color? _deletedColor(BuildContext context, T item) =>
      isDeleted?.call(item) ?? false
      ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4)
      : null;

  void _setSelected(T item, bool? value) {
    final id = idOf(item);
    if ((value ?? false) != selected.contains(id)) onToggleSelect!(id);
  }

  Widget _buildTable(BuildContext context) {
    final sortIndex = columns.indexWhere(
      (c) => c.sortField != null && c.sortField == sortField,
    );

    final table = DataTable(
      sortColumnIndex: sortIndex == -1 ? null : sortIndex,
      sortAscending: sortAscending,
      columnSpacing: 28,
      showCheckboxColumn: onToggleSelect != null,
      columns: [
        for (final column in columns)
          DataColumn(
            label: Text(column.label),
            numeric: column.numeric,
            onSort: column.sortField == null || onSort == null
                ? null
                : (_, _) => onSort!(column.sortField!),
          ),
        if (actions != null) const DataColumn(label: SizedBox.shrink()),
      ],
      rows: [
        for (final item in items)
          DataRow(
            selected: selected.contains(idOf(item)),
            onSelectChanged: onToggleSelect == null
                ? null
                : (v) => _setSelected(item, v),
            color: WidgetStatePropertyAll(_deletedColor(context, item)),
            cells: [
              for (final column in columns)
                DataCell(
                  column.build(item),
                  onTap: onOpen == null ? null : () => onOpen!(item),
                ),
              if (actions != null)
                DataCell(
                  Row(mainAxisSize: MainAxisSize.min, children: actions!(item)),
                ),
            ],
          ),
      ],
    );

    // Двумерная прокрутка: таблица не уезжает за край окна ни по ширине,
    // ни по высоте; на широком окне растягивается на всю ширину.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: table,
          ),
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          color: _deletedColor(context, item),
          child: InkWell(
            onTap: onOpen == null ? null : () => onOpen!(item),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (onToggleSelect != null)
                        Checkbox(
                          value: selected.contains(idOf(item)),
                          onChanged: (v) => _setSelected(item, v),
                        ),
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: textTheme.titleMedium,
                          child: columns.first.build(item),
                        ),
                      ),
                    ],
                  ),
                  for (final column in columns.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 4),
                      child: Row(
                        children: [
                          Text('${column.label}: ', style: textTheme.bodySmall),
                          Flexible(child: column.build(item)),
                        ],
                      ),
                    ),
                  if (actions != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actions!(item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
