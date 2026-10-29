import 'package:flutter/material.dart';

import '../models/dictionary_item.dart';

/// Выпадающий список для фильтра по справочнику; null — «все».
class FilterDropdown extends StatelessWidget {
  final String label;
  final int? value;
  final List<DictionaryItem> items;
  final ValueChanged<int?> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Неизвестный id из адреса (или ещё не загруженный справочник)
    // не должен ронять DropdownButton.
    final known = items.any((i) => i.id == value) ? value : null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: known,
          isExpanded: true,
          items: [
            const DropdownMenuItem(value: null, child: Text('Все')),
            for (final item in items)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
