/// Даты в интерфейсе вводятся и показываются в формате ДД.ММ.ГГГГ.
library;

String formatDate(DateTime date) =>
    '${_two(date.day)}.${_two(date.month)}.${date.year}';

DateTime? parseDate(String? text) {
  final match = RegExp(
    r'^(\d{2})\.(\d{2})\.(\d{4})$',
  ).firstMatch(text?.trim() ?? '');
  if (match == null) return null;
  final day = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final year = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  // DateTime молча переносит 31.02 на март — такую дату считаем неверной.
  if (date.day != day || date.month != month) return null;
  return date;
}

String _two(int value) => value.toString().padLeft(2, '0');
