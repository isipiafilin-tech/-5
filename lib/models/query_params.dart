/// Разбор и запись общих для всех списков параметров адреса.
///
/// Сортировка записывается одним параметром: `sort=year,desc`.
library;

const pageSizes = [10, 25, 50];

int? intParam(Map<String, String> params, String key) =>
    int.tryParse(params[key] ?? '');

int pageParam(Map<String, String> params) {
  final page = intParam(params, 'page') ?? 1;
  return page < 1 ? 1 : page;
}

int sizeParam(Map<String, String> params) {
  final size = intParam(params, 'size');
  return pageSizes.contains(size) ? size! : pageSizes.first;
}

/// Возвращает поле и направление сортировки; неизвестное поле заменяется
/// полем по умолчанию, чтобы адрес с опечаткой не ломал список.
(String, bool) sortParam(
  Map<String, String> params,
  Set<String> fields,
  String defaultField,
) {
  final parts = (params['sort'] ?? '').split(',');
  final field = fields.contains(parts.first) ? parts.first : defaultField;
  final ascending = parts.length < 2 || parts[1] != 'desc';
  return (field, ascending);
}

/// Параметры, общие для всех списков; значения по умолчанию в адрес не пишутся.
Map<String, String> commonParams({
  required String search,
  required String sortField,
  required String defaultSortField,
  required bool sortAscending,
  required int page,
  required int size,
  required bool includeDeleted,
}) => {
  if (search.isNotEmpty) 'search': search,
  if (sortField != defaultSortField || !sortAscending)
    'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
  if (page != 1) 'page': '$page',
  if (size != pageSizes.first) 'size': '$size',
  if (includeDeleted) 'includeDeleted': 'true',
};

/// Адрес списка; пустой набор параметров не даёт висящего «?».
Uri listUri(String path, Map<String, String> params) =>
    Uri(path: path, queryParameters: params.isEmpty ? null : params);

/// Общий интерфейс условий отбора: его использует обобщённый экран списка,
/// чтобы менять поиск, сортировку и страницу у любой сущности.
abstract interface class ListQuery<Q> {
  String get search;
  String get sortField;
  bool get sortAscending;
  int get page;
  int get size;
  bool get includeDeleted;

  Q withCommon({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  });

  /// Условия по умолчанию — для кнопки «Сбросить».
  Q get reset;

  Map<String, String> toQueryParameters();
  Uri toUri();
}
