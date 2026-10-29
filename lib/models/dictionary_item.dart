/// Элемент справочника: жанр или издательство.
///
/// В этой работе справочники нужны только для фильтров и подписей,
/// поэтому им достаточно идентификатора и названия.
class DictionaryItem {
  final int id;
  final String name;

  const DictionaryItem(this.id, this.name);
}
