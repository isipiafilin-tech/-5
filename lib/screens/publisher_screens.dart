import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/publisher.dart';
import '../models/simple_query.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/book_list_notifier.dart';
import '../state/catalog_notifiers.dart';
import '../validation/validators.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class PublishersScreen extends StatelessWidget {
  final SimpleQuery query;

  const PublishersScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return EntityListScreen<Publisher, SimpleQuery>(
      title: 'Издательства',
      searchLabel: 'Поиск по названию или городу',
      query: query,
      notifier: context.watch<PublisherListNotifier>(),
      canEdit: auth.can(Permission.manageCatalog),
      canAdmin: auth.can(Permission.restore),
      idOf: (p) => p.id,
      isDeleted: (p) => p.isDeleted,
      titleOf: (p) => p.name,
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'name',
          build: (p) => Text(p.name),
        ),
        TableColumnSpec(
          label: 'Город',
          sortField: 'city',
          build: (p) => Text(p.city),
        ),
        TableColumnSpec(
          label: 'Основано',
          sortField: 'foundedYear',
          numeric: true,
          build: (p) => Text('${p.foundedYear}'),
        ),
      ],
    );
  }
}

class PublisherDetailScreen extends StatelessWidget {
  final int id;

  const PublisherDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final publishers = context.read<PublisherListNotifier>();
    final books = context.read<BookListNotifier>();
    return DetailView<(Publisher, int)>(
      title: 'Карточка издательства',
      load: () async {
        final publisher = await publishers.findById(id);
        if (publisher == null) return null;
        return (publisher, await books.countByPublisher(id));
      },
      notFoundText: 'Издательство $id не найдено',
      editPath: auth.can(Permission.manageCatalog)
          ? '/publishers/$id/edit'
          : null,
      headline: (data) => data.$1.name,
      fields: (data) {
        final (p, bookCount) = data;
        return [
          ('Город', Text(p.city)),
          ('Год основания', Text('${p.foundedYear}')),
          ('Книг в каталоге', Text('$bookCount')),
          if (p.isDeleted) ('Удалено', Text('${p.deletedAt}')),
        ];
      },
    );
  }
}

class PublisherFormScreen extends StatelessWidget {
  final int? id;

  const PublisherFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final publishers = context.read<PublisherListNotifier>();
    return EntityForm(
      title: isEditing ? 'Изменение издательства' : 'Новое издательство',
      submitLabel: isEditing ? 'Сохранить' : 'Создать',
      notFoundText: 'Издательство $id не найдено',
      load: () async {
        if (!isEditing) {
          return const FormSetup({'name': '', 'city': '', 'foundedYear': ''});
        }
        final publisher = await publishers.findById(id!);
        if (publisher == null) return null;
        return FormSetup(
          {
            'name': publisher.name,
            'city': publisher.city,
            'foundedYear': '${publisher.foundedYear}',
          },
          {'publisher': publisher},
        );
      },
      fields: (setup, v) => [
        TextFieldSpec(
          'name',
          'Название',
          validator: all([requiredField(), length(2, 100)]),
        ),
        TextFieldSpec(
          'city',
          'Город',
          validator: all([requiredField(), length(2, 60)]),
        ),
        TextFieldSpec(
          'foundedYear',
          'Год основания',
          numeric: true,
          validator: all([requiredField(), year(1500)]),
        ),
      ],
      submit: (setup, v) async {
        final original = setup.data['publisher'] as Publisher?;
        await publishers.save(
          Publisher(
            id: id ?? 0,
            name: (v['name'] as String).trim(),
            city: (v['city'] as String).trim(),
            foundedYear: int.parse(v['foundedYear'] as String),
            deletedAt: original?.deletedAt,
          ),
        );
        return {};
      },
      onSaved: () => context.go(publishers.query.toUri().toString()),
    );
  }
}
