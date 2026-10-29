import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/api_exceptions.dart';
import '../models/dictionary_item.dart';

/// Описание поля общей формы.
sealed class FieldSpec {
  final String key;
  final String label;

  const FieldSpec(this.key, this.label);
}

class TextFieldSpec extends FieldSpec {
  final String? Function(String? value) validator;
  final bool numeric;
  final int maxLines;
  final String? hint;

  const TextFieldSpec(
    super.key,
    super.label, {
    required this.validator,
    this.numeric = false,
    this.maxLines = 1,
    this.hint,
  });
}

/// Связь «многие к одному»: выпадающий список.
class DropdownFieldSpec extends FieldSpec {
  final List<DictionaryItem> items;
  final String requiredMessage;

  const DropdownFieldSpec(
    super.key,
    super.label, {
    required this.items,
    required this.requiredMessage,
  });
}

/// Связь «многие ко многим»: множественный выбор флажками.
class MultiSelectFieldSpec extends FieldSpec {
  final List<DictionaryItem> items;
  final String requiredMessage;
  final String emptyText;

  const MultiSelectFieldSpec(
    super.key,
    super.label, {
    required this.items,
    required this.requiredMessage,
    this.emptyText = 'Нет доступных значений',
  });
}

/// Связь «один к одному»: вложенная группа полей.
class FieldGroupSpec extends FieldSpec {
  final List<FieldSpec> fields;

  const FieldGroupSpec(String label, this.fields) : super('', label);
}

/// Что нужно форме для открытия: начальные значения полей и данные,
/// из которых строятся списки выбора (например, издательства).
class FormSetup {
  final Map<String, Object?> values;
  final Map<String, Object?> data;

  const FormSetup(this.values, [this.data = const {}]);
}

/// Общая форма создания и изменения записи.
///
/// Разметка, загрузка, проверка, отправка и предупреждение о несохранённых
/// изменениях написаны один раз; сущность задаёт только список полей.
class EntityForm extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String notFoundText;

  /// Загружает запись и справочники; null — запись не найдена.
  final Future<FormSetup?> Function() load;

  /// Поля формы; могут зависеть от текущих значений (каскадные списки).
  final List<FieldSpec> Function(FormSetup setup, Map<String, Object?> values)
  fields;

  /// Сохраняет запись. Возвращает ошибки по полям, например
  /// {'isbn': 'Такой ISBN уже есть'}; пустой словарь — успех.
  final Future<Map<String, String>> Function(
    FormSetup setup,
    Map<String, Object?> values,
  )
  submit;

  final VoidCallback onSaved;

  const EntityForm({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.notFoundText,
    required this.load,
    required this.fields,
    required this.submit,
    required this.onSaved,
  });

  @override
  State<EntityForm> createState() => _EntityFormState();
}

class _EntityFormState extends State<EntityForm> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  String? _loadError;
  FormSetup? _setup;
  Map<String, Object?> _values = {};
  Map<String, Object?> _initial = {};

  /// Ошибки, пришедшие при сохранении (уникальность). Валидаторы полей
  /// возвращают их, поэтому они выводятся под своими полями.
  Map<String, String> _submitErrors = {};
  bool _submitted = false;
  bool _saving = false;

  bool get _dirty => !_sameValues(_values, _initial);

  @override
  void initState() {
    super.initState();
    widget.load().then(
      (setup) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _setup = setup;
          if (setup != null) {
            _values = Map.of(setup.values);
            _initial = Map.of(setup.values);
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      },
    );
  }

  static bool _sameValues(Map<String, Object?> a, Map<String, Object?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      final x = a[key], y = b[key];
      if (x is List && y is List) {
        if (!setEquals(x.toSet(), y.toSet())) return false;
      } else if (x != y) {
        return false;
      }
    }
    return true;
  }

  List<FieldSpec> _flatten(List<FieldSpec> specs) => [
    for (final spec in specs)
      if (spec is FieldGroupSpec) ..._flatten(spec.fields) else spec,
  ];

  void _change(String key, Object? value) {
    setState(() {
      _values[key] = value;
      _submitErrors.remove(key);
      // Каскад: после изменения одного поля из множественного выбора
      // убираются значения, которых больше нет среди доступных.
      for (final spec in _flatten(widget.fields(_setup!, _values))) {
        if (spec is MultiSelectFieldSpec) {
          final allowed = spec.items.map((i) => i.id).toSet();
          final current = (_values[spec.key] as List<int>?) ?? const [];
          _values[spec.key] = current.where(allowed.contains).toList();
        }
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitErrors = {};
      _submitted = true;
    });
    if (!_formKey.currentState!.validate()) return;
    // Пока идёт сохранение, кнопка заблокирована: повторное нажатие
    // не создаст вторую запись.
    setState(() => _saving = true);
    Map<String, String> errors = {};
    try {
      errors = await widget.submit(_setup!, Map.of(_values));
    } on ValidationException catch (e) {
      // 422: ключи ошибок совпадают с именами полей формы.
      errors = e.errors;
      final keys = _flatten(widget.fields(_setup!, _values)).map((f) => f.key);
      final other = e.errors.keys.where((k) => !keys.contains(k));
      if (other.isNotEmpty || e.errors.isEmpty) _showMessage(e.message);
    } on ApiException catch (e) {
      // 409, 401, 403, сетевой сбой и прочее — понятным сообщением.
      _showMessage(e.message);
      errors = {'': e.message};
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _submitErrors = errors;
    });
    if (errors.isEmpty) {
      _initial = Map.of(_values);
      widget.onSaved();
    } else {
      _formKey.currentState!.validate(); // показать ошибки под полями
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохранённые изменения'),
        content: const Text('Изменения в форме будут потеряны. Уйти с формы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Уйти'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(child: Text('Не удалось загрузить: $_loadError'));
    }
    if (_setup == null) return Center(child: Text(widget.notFoundText));

    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final spec in widget.fields(_setup!, _values))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _field(context, spec),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('Отмена'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        child: Text(widget.submitLabel),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _error(String key, String? Function() check) =>
      _submitErrors[key] ?? check();

  Widget _field(BuildContext context, FieldSpec spec) {
    final decoration = InputDecoration(
      labelText: spec.label,
      border: const OutlineInputBorder(),
      errorMaxLines: 3,
    );

    switch (spec) {
      case TextFieldSpec():
        return TextFormField(
          initialValue: _values[spec.key] as String? ?? '',
          decoration: decoration.copyWith(hintText: spec.hint),
          keyboardType: spec.numeric ? TextInputType.number : null,
          maxLines: spec.maxLines,
          validator: (v) => _error(spec.key, () => spec.validator(v)),
          onChanged: (v) => _change(spec.key, v),
        );

      case DropdownFieldSpec():
        final value = _values[spec.key] as int?;
        return DropdownButtonFormField<int>(
          value: spec.items.any((i) => i.id == value) ? value : null,
          decoration: decoration,
          isExpanded: true,
          items: [
            for (final item in spec.items)
              DropdownMenuItem(value: item.id, child: Text(item.name)),
          ],
          validator: (v) =>
              _error(spec.key, () => v == null ? spec.requiredMessage : null),
          onChanged: (v) => _change(spec.key, v),
        );

      case MultiSelectFieldSpec():
        final selected = (_values[spec.key] as List<int>?) ?? const [];
        return FormField<List<int>>(
          initialValue: selected,
          validator: (_) => _error(
            spec.key,
            () => (_values[spec.key] as List<int>? ?? const []).isEmpty
                ? spec.requiredMessage
                : null,
          ),
          builder: (field) => InputDecorator(
            decoration: decoration.copyWith(errorText: field.errorText),
            child: spec.items.isEmpty
                ? Text(spec.emptyText)
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in spec.items)
                        FilterChip(
                          label: Text(item.name),
                          selected: selected.contains(item.id),
                          onSelected: (on) {
                            final next = [...selected];
                            on ? next.add(item.id) : next.remove(item.id);
                            field.didChange(next); // сообщаем форме
                            _change(spec.key, next);
                          },
                        ),
                    ],
                  ),
          ),
        );

      case FieldGroupSpec():
        return InputDecorator(
          decoration: decoration.copyWith(
            contentPadding: const EdgeInsets.fromLTRB(12, 28, 12, 4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in spec.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _field(context, child),
                ),
            ],
          ),
        );
    }
  }
}
