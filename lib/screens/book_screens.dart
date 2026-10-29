import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../models/book_query.dart';
import '../core/api_exceptions.dart';
import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/book_list_notifier.dart';
import '../state/catalog_notifiers.dart';
import '../state/lookup_notifier.dart';
import '../validation/validators.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/detail_view.dart';
import '../widgets/entity_form.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';
import '../widgets/filter_dropdown.dart';

class BooksScreen extends StatelessWidget {
  final BookQuery query;

  const BooksScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final lookup = context.watch<LookupNotifier>();
    return EntityListScreen<Book, BookQuery>(
      title: 'Книги',
      searchLabel: 'Поиск по названию или ISBN',
      query: query,
      notifier: context.watch<BookListNotifier>(),
      canEdit: auth.can(Permission.manageCatalog),
      canAdmin: auth.can(Permission.restore),
      idOf: (b) => b.id,
      isDeleted: (b) => b.isDeleted,
      titleOf: (b) => b.title,
      filters: (q, go) => [
        SizedBox(
          width: 230,
          child: FilterDropdown(
            label: 'Жанр',
            value: q.genreId,
            items: lookup.genreItems,
            onChanged: (v) => go(q.copyWith(genreId: v)),
          ),
        ),
        SizedBox(
          width: 230,
          child: FilterDropdown(
            label: 'Издательство',
            value: q.publisherId,
            items: lookup.publisherItems,
            onChanged: (v) => go(q.copyWith(publisherId: v)),
          ),
        ),
        SizedBox(
          width: 100,
          child: DebouncedTextField(
            label: 'Год с',
            digitsOnly: true,
            value: q.yearFrom?.toString() ?? '',
            onChanged: (v) => go(q.copyWith(yearFrom: int.tryParse(v))),
          ),
        ),
        SizedBox(
          width: 100,
          child: DebouncedTextField(
            label: 'Год по',
            digitsOnly: true,
            value: q.yearTo?.toString() ?? '',
            onChanged: (v) => go(q.copyWith(yearTo: int.tryParse(v))),
          ),
        ),
      ],
      columns: [
        TableColumnSpec(
          label: 'Название',
          sortField: 'title',
          build: (b) => Text(b.title),
        ),
        TableColumnSpec(label: 'ISBN', build: (b) => Text(b.isbn)),
        TableColumnSpec(
          label: 'Год',
          sortField: 'year',
          numeric: true,
          build: (b) => Text('${b.year}'),
        ),
        TableColumnSpec(
          label: 'Страниц',
          sortField: 'pages',
          numeric: true,
          build: (b) => Text('${b.pages}'),
        ),
        TableColumnSpec(
          label: 'Издательство',
          build: (b) => Text(lookup.publisherName(b.publisherId)),
        ),
        TableColumnSpec(
          label: 'В наличии',
          numeric: true,
          build: (b) => Text('${b.copiesAvailable} из ${b.copiesTotal}'),
        ),
      ],
    );
  }
}

class BookDetailScreen extends StatelessWidget {
  final int id;

  const BookDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final lookup = context.watch<LookupNotifier>();
    final books = context.read<BookListNotifier>();
    return DetailView<Book>(
      title: 'Карточка книги',
      load: () => books.findById(id),
      notFoundText: 'Книга $id не найдена',
      editPath: auth.can(Permission.manageCatalog) ? '/books/$id/edit' : null,
      headline: (b) => b.title,
      fields: (b) => [
        (
          'Авторы',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final authorId in b.authorIds)
                ActionChip(
                  label: Text(lookup.authorName(authorId)),
                  onPressed: () => context.go('/authors/$authorId'),
                ),
            ],
          ),
        ),
        ('ISBN', Text(b.isbn)),
        ('Год издания', Text('${b.year}')),
        ('Страниц', Text('${b.pages}')),
        ('Издательство', Text(lookup.publisherName(b.publisherId))),
        ('Жанры', Text(b.genreIds.map(lookup.genreName).join(', '))),
        (
          'Экземпляры',
          Text('в наличии ${b.copiesAvailable} из ${b.copiesTotal}'),
        ),
        if (b.isDeleted) ('Удалена', Text('${b.deletedAt}')),
      ],
      actions: (b) => [
        if (auth.can(Permission.manageLoans))
          FilledButton.icon(
            onPressed: () => _issueLoan(context, b),
            icon: const Icon(Icons.outbox_outlined),
            label: const Text('Выдать книгу'),
          ),
      ],
    );
  }

  /// Оформление выдачи. Если свободных экземпляров нет, сервер отвечает
  /// 409, и пользователь видит понятное сообщение.
  Future<void> _issueLoan(BuildContext context, Book book) async {
    final books = context.read<BookListNotifier>();
    final messenger = ScaffoldMessenger.of(context);
    final readers = await context.read<ReaderListNotifier>().all();
    if (!context.mounted) return;
    int? readerId = readers.isEmpty ? null : readers.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Выдать «${book.title}»'),
          content: DropdownButtonFormField<int>(
            value: readerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Читатель',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final r in readers)
                DropdownMenuItem(value: r.id, child: Text(r.fullName)),
            ],
            onChanged: (v) => setState(() => readerId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: readerId == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Выдать'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || readerId == null) return;
    try {
      await books.issueLoan(bookId: book.id, readerId: readerId!);
      messenger.showSnackBar(const SnackBar(content: Text('Книга выдана')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Один экран на создание (id == null) и изменение книги.
class BookFormScreen extends StatelessWidget {
  final int? id;

  const BookFormScreen({super.key, this.id});

  bool get isEditing => id != null;

  @override
  Widget build(BuildContext context) {
    final books = context.read<BookListNotifier>();
    final lookup = context.read<LookupNotifier>();

    return EntityForm(
      title: isEditing ? 'Изменение книги' : 'Новая книга',
      submitLabel: isEditing ? 'Сохранить' : 'Создать',
      notFoundText: 'Книга $id не найдена',
      load: () async {
        await lookup.ensureLoaded(); // справочники берутся из кэша
        if (!isEditing) {
          return FormSetup({
            'title': '',
            'isbn': '',
            'year': '',
            'pages': '',
            'publisherId': null,
            'authorIds': <int>[],
            'genreIds': <int>[],
            'copiesTotal': '1',
          });
        }
        final book = await books.findById(id!);
        if (book == null) return null;
        return FormSetup(
          {
            'title': book.title,
            'isbn': book.isbn,
            'year': '${book.year}',
            'pages': '${book.pages}',
            'publisherId': book.publisherId,
            'authorIds': book.authorIds,
            'genreIds': book.genreIds,
            'copiesTotal': '${book.copiesTotal}',
          },
          {'book': book},
        );
      },
      fields: (setup, v) {
        return [
          TextFieldSpec(
            'title',
            'Название',
            validator: all([requiredField(), length(1, 200)]),
          ),
          TextFieldSpec(
            'isbn',
            'ISBN',
            hint: '978-5-17-100731-5',
            validator: all([requiredField(), isbn()]),
          ),
          TextFieldSpec(
            'year',
            'Год издания',
            numeric: true,
            validator: all([requiredField(), year(1450)]),
          ),
          TextFieldSpec(
            'pages',
            'Число страниц',
            numeric: true,
            validator: all([requiredField(), positive(10000)]),
          ),
          DropdownFieldSpec(
            'publisherId',
            'Издательство',
            items: lookup.publisherItems,
            requiredMessage: 'Выберите издательство',
          ),
          MultiSelectFieldSpec(
            'authorIds',
            'Авторы',
            items: lookup.authorItems,
            requiredMessage: 'Выберите хотя бы одного автора',
          ),
          MultiSelectFieldSpec(
            'genreIds',
            'Жанры',
            items: lookup.genreItems,
            requiredMessage: 'Выберите хотя бы один жанр',
          ),
          TextFieldSpec(
            'copiesTotal',
            'Экземпляров всего',
            numeric: true,
            validator: all([requiredField(), positive(1000)]),
          ),
        ];
      },
      // Уникальность ISBN проверяет сервер: ответ 422 разложится по полям.
      submit: (setup, v) async {
        final original = setup.data['book'] as Book?;
        await books.save(
          Book(
            id: id ?? 0,
            title: (v['title'] as String).trim(),
            isbn: (v['isbn'] as String).trim(),
            year: int.parse(v['year'] as String),
            pages: int.parse(v['pages'] as String),
            publisherId: v['publisherId'] as int,
            authorIds: v['authorIds'] as List<int>,
            genreIds: v['genreIds'] as List<int>,
            copiesTotal: int.parse(v['copiesTotal'] as String),
            copiesAvailable: original?.copiesAvailable ?? 0,
            deletedAt: original?.deletedAt,
          ),
        );
        return {};
      },
      onSaved: () => context.go(books.query.toUri().toString()),
    );
  }
}
