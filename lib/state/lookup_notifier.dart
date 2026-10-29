import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/author.dart';
import '../models/dictionary_item.dart';
import '../models/genre.dart';
import '../models/publisher.dart';
import '../repositories/author_repository.dart';
import '../repositories/api_catalog_repositories.dart';

/// Справочные списки для выпадающих полей, фильтров и подписей.
///
/// Берутся из репозиториев и обновляются после каждого изменения
/// жанров, издательств и авторов.
class LookupNotifier extends ChangeNotifier {
  final GenreRepository _genres;
  final PublisherRepository _publishers;
  final AuthorRepository _authors;

  LookupNotifier(this._genres, this._publishers, this._authors);

  List<Genre> genres = const [];
  List<Publisher> publishers = const [];
  List<Author> authors = const [];

  bool _loaded = false;
  Future<void>? _loading;

  /// Справочники запрашиваются один раз и хранятся здесь; повторно —
  /// только после изменения жанров, издательств или авторов.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await (_loading ??= refresh().whenComplete(() => _loading = null));
  }

  Future<void> refresh() async {
    try {
      genres = await _genres.findAll(includeDeleted: true);
      publishers = await _publishers.findAll(includeDeleted: true);
      authors = await _authors.findAll(includeDeleted: true);
      _loaded = true;
    } on ApiException {
      // Сервер недоступен: подписи покажут номера, списки — пустые.
      _loaded = false;
    }
    notifyListeners();
  }

  // Для выбора в формах и фильтрах — только не удалённые записи.
  List<DictionaryItem> get genreItems => [
    for (final g in genres.where((g) => !g.isDeleted))
      DictionaryItem(g.id, g.name),
  ];
  List<DictionaryItem> get publisherItems => [
    for (final p in publishers.where((p) => !p.isDeleted))
      DictionaryItem(p.id, p.name),
  ];
  List<DictionaryItem> get authorItems => [
    for (final a in authors.where((a) => !a.isDeleted))
      DictionaryItem(a.id, a.fullName),
  ];

  Publisher? publisher(int id) {
    for (final p in publishers) {
      if (p.id == id) return p;
    }
    return null;
  }

  String genreName(int id) => _find(genres, (g) => g.id == id)?.name ?? '#$id';
  String publisherName(int id) => publisher(id)?.name ?? '#$id';
  String authorName(int id) =>
      _find(authors, (a) => a.id == id)?.fullName ?? '#$id';

  static E? _find<E>(List<E> items, bool Function(E) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}
