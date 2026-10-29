import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/dates.dart';
import '../models/loan.dart';
import '../models/simple_query.dart';
import '../state/catalog_notifiers.dart';
import '../widgets/catalog_scaffold.dart';
import '../widgets/entity_list_screen.dart';
import '../widgets/entity_table.dart';
import '../widgets/feedback.dart';

List<TableColumnSpec<Loan>> _loanColumns({required bool withReader}) => [
  TableColumnSpec(label: 'Книга', build: (l) => Text(l.bookTitle)),
  if (withReader)
    TableColumnSpec(label: 'Читатель', build: (l) => Text(l.readerName)),
  TableColumnSpec(
    label: 'Выдана',
    sortField: 'issuedAt',
    build: (l) => Text(formatDate(l.issuedAt)),
  ),
  TableColumnSpec(
    label: 'Вернуть до',
    sortField: 'dueAt',
    build: (l) => Text(formatDate(l.dueAt)),
  ),
  TableColumnSpec(label: 'Состояние', build: (l) => Text(l.statusLabel)),
];

/// Рабочее место библиотекаря: все выдачи и их закрытие.
class LoansScreen extends StatelessWidget {
  final SimpleQuery query;

  const LoansScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final loans = context.watch<LoanListNotifier>();
    return EntityListScreen<Loan, SimpleQuery>(
      title: 'Выдачи',
      searchLabel: null,
      query: query,
      notifier: loans,
      idOf: (l) => l.id,
      isDeleted: (l) => l.isDeleted,
      titleOf: (l) => l.bookTitle,
      canEdit: false,
      canAdmin: false,
      openable: false,
      columns: _loanColumns(withReader: true),
      extraActions: (l) => [
        if (l.isOpen)
          IconButton(
            tooltip: 'Закрыть выдачу',
            icon: const Icon(Icons.assignment_return_outlined),
            onPressed: () => runWithMessage(
              context,
              () => loans.close(l.id),
              success: 'Выдача закрыта',
            ),
          ),
      ],
    );
  }
}

/// Выдачи текущего читателя и продление срока.
class MyLoansScreen extends StatelessWidget {
  final SimpleQuery query;

  const MyLoansScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    final loans = context.watch<MyLoanListNotifier>();
    return EntityListScreen<Loan, SimpleQuery>(
      title: 'Мои выдачи',
      searchLabel: null,
      query: query,
      notifier: loans,
      idOf: (l) => l.id,
      isDeleted: (l) => l.isDeleted,
      titleOf: (l) => l.bookTitle,
      canEdit: false,
      canAdmin: false,
      openable: false,
      columns: _loanColumns(withReader: false),
      extraActions: (l) => [
        if (l.isOpen)
          IconButton(
            tooltip: 'Продлить на 14 дней',
            icon: const Icon(Icons.update),
            onPressed: () => runWithMessage(
              context,
              () => loans.extend(l),
              success: 'Срок продлён',
            ),
          ),
      ],
    );
  }
}

/// Пользователи системы (только администратор).
class UsersScreen extends StatelessWidget {
  final SimpleQuery query;

  const UsersScreen({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return EntityListScreen<AppUser, SimpleQuery>(
      title: 'Пользователи',
      searchLabel: null,
      query: query,
      notifier: context.watch<UserListNotifier>(),
      idOf: (u) => u.id,
      isDeleted: (_) => false,
      titleOf: (u) => u.username,
      canEdit: false,
      canAdmin: false,
      openable: false,
      columns: [
        TableColumnSpec(
          label: 'Логин',
          sortField: 'username',
          build: (u) => Text(u.username),
        ),
        TableColumnSpec(
          label: 'ФИО',
          sortField: 'fullName',
          build: (u) => Text(u.fullName),
        ),
        TableColumnSpec(label: 'Почта', build: (u) => Text(u.email)),
        TableColumnSpec(
          label: 'Роль',
          sortField: 'role',
          build: (u) => Text(u.role.label),
        ),
      ],
    );
  }
}

/// Статистика (только администратор).
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<List<(String, int)>> _future = context
      .read<StatsNotifier>()
      .load();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CatalogScaffold(
      title: 'Статистика',
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Не удалось загрузить: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(
                      () => _future = context.read<StatsNotifier>().load(),
                    ),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (label, value) in snapshot.data!)
                  SizedBox(
                    width: 220,
                    child: Card.outlined(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$value', style: textTheme.displaySmall),
                            Text(label),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
