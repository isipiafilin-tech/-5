import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/dates.dart';
import '../models/reader.dart';
import '../models/simple_query.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/catalog_notifiers.dart';
import '../validation/validators.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';

class ReadersScreen extends StatelessWidget {
  final SimpleQuery query;

  const ReadersScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return EntityListScreen<Reader, SimpleQuery>(
      title: 'Читатели',
      searchLabel: 'Поиск по ФИО, почте, телефону',
      query: query,
      notifier: context.watch<ReaderListNotifier>(),
      canEdit: auth.can(Permission.manageReaders),
      canAdmin: auth.can(Permission.restore),
      idOf: (r) => r.id,
      isDeleted: (r) => r.isDeleted,
      titleOf: (r) => r.fullName,
      columns: [
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (r) => Text(r.fullName),
        ),
        TableColumnSpec(
          label: 'Почта',
          sortField: 'email',
          build: (r) => Text(r.email),
        ),
        TableColumnSpec(
          label: 'Телефон',
          sortField: 'phone',
          build: (r) => Text(r.phone),
        ),
        TableColumnSpec(
          label: 'Билет',
          build: (r) => Text(r.card?.number ?? '—'),
        ),
      ],
    );
  }
}

class ReaderDetailScreen extends StatelessWidget {
  final int id;

  const ReaderDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final readers = context.read<ReaderListNotifier>();
    return DetailView<Reader>(
      title: 'Карточка читателя',
      load: () => readers.findById(id),
      notFoundText: 'Читатель $id не найден',
      editPath: auth.can(Permission.manageReaders) ? '/readers/$id/edit' : null,
      headline: (r) => r.fullName,
      fields: (r) => [
        ('Почта', Text(r.email)),
        ('Телефон', Text(r.phone.isEmpty ? '—' : r.phone)),
        ('Читательский билет', Text(r.card?.number ?? '—')),
        if (r.card != null) ...[
          ('Выдан', Text(formatDate(r.card!.issuedAt))),
          ('Действует до', Text(formatDate(r.card!.expiresAt))),
        ],
        if (r.isDeleted) ('Удалён', Text('${r.deletedAt}')),
      ],
    );
  }
}

/// Форма читателя; билет (один к одному) — вложенная группа полей.
class ReaderFormScreen extends StatelessWidget {
  final int? id;

  const ReaderFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final readers = context.read<ReaderListNotifier>();
    return EntityForm(
      title: isEditing ? 'Изменение читателя' : 'Новый читатель',
      submitLabel: isEditing ? 'Сохранить' : 'Создать',
      notFoundText: 'Читатель $id не найден',
      load: () async {
        final now = DateTime.now();
        if (!isEditing) {
          return FormSetup({
            'fullName': '',
            'email': '',
            'phone': '',
            'card.number': '',
            'card.issuedAt': formatDate(now),
            'card.expiresAt': formatDate(
              DateTime(now.year + 1, now.month, now.day),
            ),
          });
        }
        final reader = await readers.findById(id!);
        if (reader == null) return null;
        return FormSetup(
          {
            'fullName': reader.fullName,
            'email': reader.email,
            'phone': reader.phone,
            'card.number': reader.card?.number ?? '',
            'card.issuedAt': formatDate(reader.card?.issuedAt ?? now),
            'card.expiresAt': formatDate(
              reader.card?.expiresAt ??
                  DateTime(now.year + 1, now.month, now.day),
            ),
          },
          {'reader': reader},
        );
      },
      fields: (setup, v) => [
        TextFieldSpec(
          'fullName',
          'ФИО',
          hint: 'Смирнов П. А.',
          validator: all([requiredField(), length(2, 100)]),
        ),
        TextFieldSpec(
          'email',
          'Электронная почта',
          hint: 'reader@mail.ru',
          validator: all([requiredField(), length(5, 100), email()]),
        ),
        TextFieldSpec(
          'phone',
          'Телефон (необязательно)',
          hint: '+7 900 100-10-01',
          validator: optional(phone()),
        ),
        FieldGroupSpec('Читательский билет', [
          TextFieldSpec(
            'card.number',
            'Номер билета',
            hint: 'RC-000001',
            validator: all([
              requiredField(),
              pattern(RegExp(r'^RC-\d{6}$'), 'Формат номера: RC-000001'),
            ]),
          ),
          TextFieldSpec(
            'card.issuedAt',
            'Дата выдачи',
            hint: 'ДД.ММ.ГГГГ',
            validator: all([requiredField(), pastDate()]),
          ),
          TextFieldSpec(
            'card.expiresAt',
            'Действует до',
            hint: 'ДД.ММ.ГГГГ',
            validator: all([
              requiredField(),
              (value) {
                final until = parseDate(value);
                final from = parseDate(v['card.issuedAt'] as String?);
                if (until == null) return 'Дата в формате ДД.ММ.ГГГГ';
                if (from != null && !until.isAfter(from)) {
                  return 'Позже даты выдачи';
                }
                return null;
              },
            ]),
          ),
        ]),
      ],
      // Уникальность почты проверяет сервер: ответ 422 разложится по полям.
      submit: (setup, v) async {
        final original = setup.data['reader'] as Reader?;
        await readers.save(
          Reader(
            id: id ?? 0,
            fullName: (v['fullName'] as String).trim(),
            email: (v['email'] as String).trim(),
            phone: (v['phone'] as String).trim(),
            card: LibraryCard(
              number: (v['card.number'] as String).trim(),
              issuedAt: parseDate(v['card.issuedAt'] as String)!,
              expiresAt: parseDate(v['card.expiresAt'] as String)!,
            ),
            deletedAt: original?.deletedAt,
          ),
        );
        return {};
      },
      onSaved: () => context.go(readers.query.toUri().toString()),
    );
  }
}
