import 'package:flutter/foundation.dart';

import 'query_params.dart';

/// Условия отбора для жанров, издательств и читателей.
///
/// Общие параметры те же, что у книг; дополнительные фильтры лежат
/// в [filters] и записываются в адрес под своими именами.
class SimpleQuery implements ListQuery<SimpleQuery> {
  final String path;
  final Set<String> sortFields;
  final String defaultSort;
  final Set<String> filterKeys;

  @override
  final String search;
  @override
  final String sortField;
  @override
  final bool sortAscending;
  @override
  final int page;
  @override
  final int size;
  @override
  final bool includeDeleted;
  final Map<String, String> filters;

  const SimpleQuery({
    required this.path,
    required this.sortFields,
    required this.defaultSort,
    this.filterKeys = const {},
    this.search = '',
    String? sortField,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
    this.filters = const {},
  }) : sortField = sortField ?? defaultSort;

  /// Разбирает адрес; [base] задаёт путь, допустимые сортировки и фильтры.
  factory SimpleQuery.parse(SimpleQuery base, Map<String, String> params) {
    final (sortField, sortAscending) = sortParam(
      params,
      base.sortFields,
      base.defaultSort,
    );
    return base._copy(
      search: params['search'] ?? '',
      sortField: sortField,
      sortAscending: sortAscending,
      page: pageParam(params),
      size: sizeParam(params),
      includeDeleted: params['includeDeleted'] == 'true',
      filters: {
        for (final key in base.filterKeys)
          if (params[key]?.isNotEmpty ?? false) key: params[key]!,
      },
    );
  }

  int? intFilter(String key) => int.tryParse(filters[key] ?? '');

  /// Новый фильтр возвращает на первую страницу, как и любое условие.
  SimpleQuery withFilter(String key, Object? value) => _copy(
    page: 1,
    filters: {...filters, key: value?.toString() ?? ''}
      ..removeWhere((_, v) => v.isEmpty),
  );

  @override
  SimpleQuery withCommon({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) => _copy(
    search: search,
    sortField: sortField,
    sortAscending: sortAscending,
    page: page ?? 1,
    size: size,
    includeDeleted: includeDeleted,
  );

  @override
  SimpleQuery get reset => SimpleQuery(
    path: path,
    sortFields: sortFields,
    defaultSort: defaultSort,
    filterKeys: filterKeys,
  );

  @override
  Map<String, String> toQueryParameters() => {
    ...commonParams(
      search: search,
      sortField: sortField,
      defaultSortField: defaultSort,
      sortAscending: sortAscending,
      page: page,
      size: size,
      includeDeleted: includeDeleted,
    ),
    ...filters,
  };

  @override
  Uri toUri() => listUri(path, toQueryParameters());

  SimpleQuery _copy({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
    Map<String, String>? filters,
  }) => SimpleQuery(
    path: path,
    sortFields: sortFields,
    defaultSort: defaultSort,
    filterKeys: filterKeys,
    search: search ?? this.search,
    sortField: sortField ?? this.sortField,
    sortAscending: sortAscending ?? this.sortAscending,
    page: page ?? this.page,
    size: size ?? this.size,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    filters: filters ?? this.filters,
  );

  @override
  bool operator ==(Object other) =>
      other is SimpleQuery &&
      other.path == path &&
      other.search == search &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted &&
      mapEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(
    path,
    search,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
    Object.hashAllUnordered(filters.entries.map((e) => '${e.key}=${e.value}')),
  );
}

const genreQuery = SimpleQuery(
  path: '/genres',
  sortFields: {'name', 'id'},
  defaultSort: 'name',
);

const publisherQuery = SimpleQuery(
  path: '/publishers',
  sortFields: {'name', 'city', 'foundedYear'},
  defaultSort: 'name',
);

const readerQuery = SimpleQuery(
  path: '/readers',
  sortFields: {'fullName', 'email', 'phone'},
  defaultSort: 'fullName',
);

/// Все выдачи — рабочее место библиотекаря.
const loanQuery = SimpleQuery(
  path: '/loans',
  sortFields: {'issuedAt', 'dueAt'},
  defaultSort: 'issuedAt',
);

/// Выдачи текущего читателя: сервер сам отбирает их по токену.
const myLoanQuery = SimpleQuery(
  path: '/my-loans',
  sortFields: {'issuedAt', 'dueAt'},
  defaultSort: 'issuedAt',
);

const userQuery = SimpleQuery(
  path: '/admin/users',
  sortFields: {'username', 'fullName', 'role'},
  defaultSort: 'username',
);
