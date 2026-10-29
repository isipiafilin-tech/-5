/// Валидаторы полей форм. Каждый возвращает текст ошибки или null,
/// поэтому подставляется прямо в validator у TextFormField.
///
/// Проверки собираются из простых частей через [all]:
/// `all([requiredField(), length(2, 100)])`.
library;

import '../models/dates.dart';

typedef Validator = String? Function(String? value);

/// Применяет проверки по очереди и возвращает первую ошибку.
Validator all(List<Validator> validators) => (value) {
  for (final validator in validators) {
    final error = validator(value);
    if (error != null) return error;
  }
  return null;
};

/// Необязательное поле: пустое значение допустимо, заполненное проверяется.
Validator optional(Validator validator) =>
    (value) =>
        (value == null || value.trim().isEmpty) ? null : validator(value);

Validator requiredField([String message = 'Заполните поле']) =>
    (value) => (value == null || value.trim().isEmpty) ? message : null;

Validator length(int min, int max) => (value) {
  final length = value?.trim().length ?? 0;
  if (length < min) return 'Не короче $min символов';
  if (length > max) return 'Не длиннее $max символов';
  return null;
};

Validator intRange(int min, int max) => (value) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null) return 'Введите целое число';
  if (number < min || number > max) return 'Допустимо от $min до $max';
  return null;
};

/// Количество: целое число больше нуля.
Validator positive([int max = 100000]) => (value) {
  final number = int.tryParse(value?.trim() ?? '');
  if (number == null) return 'Введите целое число';
  if (number <= 0) return 'Число должно быть больше нуля';
  if (number > max) return 'Не больше $max';
  return null;
};

/// Год: не раньше [min] и не позже текущего.
Validator year(int min) => intRange(min, DateTime.now().year);

Validator email() =>
    (value) =>
        RegExp(
          r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$',
        ).hasMatch(value?.trim() ?? '')
        ? null
        : 'Неверный формат почты, например reader@mail.ru';

Validator phone() =>
    (value) =>
        RegExp(
          r'^\+7 ?\(?\d{3}\)? ?\d{3}-?\d{2}-?\d{2}$',
        ).hasMatch(value?.trim() ?? '')
        ? null
        : 'Формат: +7 (999) 123-45-67';

/// ISBN-13: 13 цифр (дефисы допускаются), начинается с 978 или 979.
Validator isbn() => (value) {
  final digits = (value ?? '').replaceAll('-', '').trim();
  if (!RegExp(r'^\d{13}$').hasMatch(digits)) {
    return 'ISBN — 13 цифр, например 978-5-17-118366-4';
  }
  if (!digits.startsWith('978') && !digits.startsWith('979')) {
    return 'ISBN начинается с 978 или 979';
  }
  return null;
};

Validator pattern(RegExp regExp, String message) =>
    (value) => regExp.hasMatch(value?.trim() ?? '') ? null : message;

/// Дата ДД.ММ.ГГГГ не позже сегодняшнего дня.
Validator pastDate() => (value) {
  final date = parseDate(value);
  if (date == null) return 'Дата в формате ДД.ММ.ГГГГ';
  if (date.isAfter(DateTime.now())) return 'Дата не может быть в будущем';
  if (date.year < 1900) return 'Слишком ранняя дата';
  return null;
};

/// Значение не больше другого поля формы, например «в наличии» ≤ «всего».
Validator notGreaterThan(String? Function() other, String message) => (value) {
  final a = int.tryParse(value?.trim() ?? '');
  final b = int.tryParse(other()?.trim() ?? '');
  return (a != null && b != null && a > b) ? message : null;
};

/// Правила надёжного пароля; проверяются по мере ввода.
const passwordRules = <(String, bool Function(String))>[
  ('не короче 8 символов', _longEnough),
  ('есть цифра', _hasDigit),
  ('есть специальный символ (!@#\$% и т. п.)', _hasSpecial),
];

bool _longEnough(String v) => v.length >= 8;
bool _hasDigit(String v) => RegExp(r'\d').hasMatch(v);
bool _hasSpecial(String v) => RegExp(r'[^A-Za-zА-Яа-яЁё0-9\s]').hasMatch(v);

Validator strongPassword() => (value) {
  for (final (label, ok) in passwordRules) {
    if (!ok(value ?? '')) return 'Пароль: $label';
  }
  return null;
};
