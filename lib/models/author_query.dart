import 'query_params.dart';

class AuthorQuery implements ListQuery<AuthorQuery> {
  static const sortFields = {'fullName', 'country', 'birthYear'};
  static const defaultSort = 'fullName';

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

  const AuthorQuery({
    this.search = '',
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  factory AuthorQuery.fromQueryParameters(Map<String, String> params) {
    final (sortField, sortAscending) = sortParam(
      params,
      sortFields,
      defaultSort,
    );
    return AuthorQuery(
      search: params['search'] ?? '',
      sortField: sortField,
      sortAscending: sortAscending,
      page: pageParam(params),
      size: sizeParam(params),
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

  @override
  Map<String, String> toQueryParameters() => commonParams(
    search: search,
    sortField: sortField,
    defaultSortField: defaultSort,
    sortAscending: sortAscending,
    page: page,
    size: size,
    includeDeleted: includeDeleted,
  );

  @override
  Uri toUri() => listUri('/authors', toQueryParameters());

  @override
  AuthorQuery withCommon({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) => copyWith(
    search: search,
    sortField: sortField,
    sortAscending: sortAscending,
    page: page,
    size: size,
    includeDeleted: includeDeleted,
  );

  @override
  AuthorQuery get reset => const AuthorQuery();

  AuthorQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return AuthorQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Любое изменение условий отбора возвращает на первую страницу
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorQuery &&
      other.search == search &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode =>
      Object.hash(search, sortField, sortAscending, page, size, includeDeleted);
}
