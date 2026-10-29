import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../models/simple_query.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/catalog_notifiers.dart';
import '../validation/validators.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class GenresScreen extends StatelessWidget {
  final SimpleQuery query;

  const GenresScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return EntityListScreen<Genre, SimpleQuery>(
      title: 'Жанры',
      searchLabel: 'Поиск по названию или описанию',
      query: query,
      notifier: context.watch<GenreListNotifier>(),
      canEdit: auth.can(Permission.manageCatalog),
      canAdmin: auth.can(Permission.restore),
      idOf: (g) => g.id,
      isDeleted: (g) => g.isDeleted,
      titleOf: (g) => g.name,
      columns: [
        TableColumnSpec(
          label: '№',
          sortField: 'id',
          numeric: true,
          build: (g) => Text('${g.id}'),
        ),
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (g) => Text(g.name),
        ),
        TableColumnSpec(label: 'Описание', build: (g) => Text(g.description)),
      ],
    );
  }
}

class GenreDetailScreen extends StatelessWidget {
  final int id;

  const GenreDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final genres = context.read<GenreListNotifier>();
    return DetailView<Genre>(
      title: 'Карточка жанра',
      load: () => genres.findById(id),
      notFoundText: 'Жанр $id не найден',
      editPath: auth.can(Permission.manageCatalog) ? '/genres/$id/edit' : null,
      headline: (g) => g.name,
      fields: (g) => [
        ('Описание', Text(g.description.isEmpty ? '—' : g.description)),
        if (g.isDeleted) ('Удалён', Text('${g.deletedAt}')),
      ],
    );
  }
}

class GenreFormScreen extends StatelessWidget {
  final int? id;

  const GenreFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final genres = context.read<GenreListNotifier>();
    return EntityForm(
      title: isEditing ? 'Изменение жанра' : 'Новый жанр',
      submitLabel: isEditing ? 'Сохранить' : 'Создать',
      notFoundText: 'Жанр $id не найден',
      load: () async {
        if (!isEditing) return const FormSetup({'name': '', 'description': ''});
        final genre = await genres.findById(id!);
        if (genre == null) return null;
        return FormSetup(
          {'name': genre.name, 'description': genre.description},
          {'genre': genre},
        );
      },
      fields: (setup, v) => [
        TextFieldSpec(
          'name',
          'Название',
          validator: all([requiredField(), length(2, 50)]),
        ),
        TextFieldSpec(
          'description',
          'Описание',
          maxLines: 3,
          validator: optional(length(0, 300)),
        ),
      ],
      submit: (setup, v) async {
        final original = setup.data['genre'] as Genre?;
        await genres.save(
          Genre(
            id: id ?? 0,
            name: (v['name'] as String).trim(),
            description: (v['description'] as String).trim(),
            deletedAt: original?.deletedAt,
          ),
        );
        return {};
      },
      onSaved: () => context.go(genres.query.toUri().toString()),
    );
  }
}
