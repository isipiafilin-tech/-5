/// Безопасное чтение полей из JSON.
///
/// Данные из хранилища (а в ПР4 — из ответа сервера) могут прийти без поля,
/// с null или с другим типом. Вместо падения возвращается запасное значение.
library;

int readInt(Object? value, [int fallback = 0]) => switch (value) {
  int v => v,
  num v => v.toInt(),
  String v => int.tryParse(v) ?? fallback,
  _ => fallback,
};

String readString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

List<int> readIntList(Object? value) => value is List
    ? value.whereType<num>().map((v) => v.toInt()).toList()
    : const [];

DateTime? readDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Map<String, dynamic> readMap(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

/// Идентификаторы из списка развёрнутых объектов: [{"id": 1, ...}, ...].
List<int> readIdList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => readInt(e['id'])).toList()
    : const [];
