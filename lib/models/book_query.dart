import 'query_params.dart';

class BookQuery implements ListQuery<BookQuery> {
  static const sortFields = {'title', 'year', 'pages'};
  static const defaultSort = 'title';

  @override
  final String search;
  final int? genreId;
  final int? publisherId;
  final int? yearFrom;
  final int? yearTo;
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

  const BookQuery({
    this.search = '',
    this.genreId,
    this.publisherId,
    this.yearFrom,
    this.yearTo,
    this.sortField = defaultSort,
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  /// Восстанавливает условия отбора из адреса /books?...
  factory BookQuery.fromQueryParameters(Map<String, String> params) {
    final (sortField, sortAscending) = sortParam(
      params,
      sortFields,
      defaultSort,
    );
    return BookQuery(
      search: params['search'] ?? '',
      genreId: intParam(params, 'genreId'),
      publisherId: intParam(params, 'publisherId'),
      yearFrom: intParam(params, 'yearFrom'),
      yearTo: intParam(params, 'yearTo'),
      sortField: sortField,
      sortAscending: sortAscending,
      page: pageParam(params),
      size: sizeParam(params),
      includeDeleted: params['includeDeleted'] == 'true',
    );
  }

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
    if (genreId != null) 'genreId': '$genreId',
    if (publisherId != null) 'publisherId': '$publisherId',
    if (yearFrom != null) 'yearFrom': '$yearFrom',
    if (yearTo != null) 'yearTo': '$yearTo',
  };

  @override
  Uri toUri() => listUri('/books', toQueryParameters());

  @override
  BookQuery withCommon({
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
  BookQuery get reset => const BookQuery();

  BookQuery copyWith({
    String? search,
    Object? genreId = _unset,
    Object? publisherId = _unset,
    Object? yearFrom = _unset,
    Object? yearTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return BookQuery(
      search: search ?? this.search,
      genreId: genreId == _unset ? this.genreId : genreId as int?,
      publisherId: publisherId == _unset
          ? this.publisherId
          : publisherId as int?,
      yearFrom: yearFrom == _unset ? this.yearFrom : yearFrom as int?,
      yearTo: yearTo == _unset ? this.yearTo : yearTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      // Любое изменение условий отбора возвращает на первую страницу
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is BookQuery &&
      other.search == search &&
      other.genreId == genreId &&
      other.publisherId == publisherId &&
      other.yearFrom == yearFrom &&
      other.yearTo == yearTo &&
      other.sortField == sortField &&
      other.sortAscending == sortAscending &&
      other.page == page &&
      other.size == size &&
      other.includeDeleted == includeDeleted;

  @override
  int get hashCode => Object.hash(
    search,
    genreId,
    publisherId,
    yearFrom,
    yearTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );
}
