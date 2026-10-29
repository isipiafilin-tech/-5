import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/author.dart';
import '../models/author_query.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/author_list_notifier.dart';
import '../validation/validators.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class AuthorsScreen extends StatelessWidget {
  final AuthorQuery query;

  const AuthorsScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return EntityListScreen<Author, AuthorQuery>(
      title: 'Авторы',
      searchLabel: 'Поиск по имени или стране',
      query: query,
      notifier: context.watch<AuthorListNotifier>(),
      canEdit: auth.can(Permission.manageCatalog),
      canAdmin: auth.can(Permission.restore),
      idOf: (a) => a.id,
      isDeleted: (a) => a.isDeleted,
      titleOf: (a) => a.fullName,
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (a) => Text(a.fullName),
        ),
        TableColumnSpec(
          label: 'Страна',
          sortField: 'country',
          build: (a) => Text(a.country),
        ),
        TableColumnSpec(
          label: 'Год рождения',
          sortField: 'birthYear',
          numeric: true,
          build: (a) => Text('${a.birthYear}'),
        ),
      ],
    );
  }
}

class AuthorDetailScreen extends StatelessWidget {
  final int id;

  const AuthorDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final authors = context.read<AuthorListNotifier>();
    return DetailView<Author>(
      title: 'Карточка автора',
      load: () => authors.findById(id),
      notFoundText: 'Автор $id не найден',
      editPath: auth.can(Permission.manageCatalog) ? '/authors/$id/edit' : null,
      headline: (a) => a.fullName,
      fields: (a) => [
        ('Страна', Text(a.country)),
        ('Год рождения', Text('${a.birthYear}')),
        if (a.isDeleted) ('Удалён', Text('${a.deletedAt}')),
      ],
    );
  }
}

class AuthorFormScreen extends StatelessWidget {
  final int? id;

  const AuthorFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final authors = context.read<AuthorListNotifier>();
    return EntityForm(
      title: isEditing ? 'Изменение автора' : 'Новый автор',
      submitLabel: isEditing ? 'Сохранить' : 'Создать',
      notFoundText: 'Автор $id не найден',
      load: () async {
        if (!isEditing) {
          return const FormSetup({
            'fullName': '',
            'country': '',
            'birthYear': '',
          });
        }
        final author = await authors.findById(id!);
        if (author == null) return null;
        return FormSetup(
          {
            'fullName': author.fullName,
            'country': author.country,
            'birthYear': '${author.birthYear}',
          },
          {'author': author},
        );
      },
      fields: (setup, v) => [
        TextFieldSpec(
          'fullName',
          'ФИО',
          hint: 'Толстой Л. Н.',
          validator: all([requiredField(), length(2, 100)]),
        ),
        TextFieldSpec(
          'country',
          'Страна',
          validator: all([requiredField(), length(2, 60)]),
        ),
        TextFieldSpec(
          'birthYear',
          'Год рождения',
          numeric: true,
          validator: all([requiredField(), year(1000)]),
        ),
      ],
      submit: (setup, v) async {
        final original = setup.data['author'] as Author?;
        await authors.save(
          Author(
            id: id ?? 0,
            fullName: (v['fullName'] as String).trim(),
            country: (v['country'] as String).trim(),
            birthYear: int.parse(v['birthYear'] as String),
            deletedAt: original?.deletedAt,
          ),
        );
        return {};
      },
      onSaved: () => context.go(authors.query.toUri().toString()),
    );
  }
}
