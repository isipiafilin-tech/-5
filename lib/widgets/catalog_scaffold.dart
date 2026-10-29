import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/permissions.dart';
import '../state/auth_notifier.dart';
import '../state/lookup_notifier.dart';

/// Разделы приложения и право, нужное для каждого.
const appSections = [
  ('Главная', '/', Icons.home_outlined, null),
  ('Книги', '/books', Icons.menu_book_outlined, Permission.viewCatalog),
  ('Авторы', '/authors', Icons.person_outline, Permission.viewCatalog),
  ('Жанры', '/genres', Icons.category_outlined, Permission.viewCatalog),
  (
    'Издательства',
    '/publishers',
    Icons.business_outlined,
    Permission.viewCatalog,
  ),
  ('Мои выдачи', '/my-loans', Icons.bookmark_outline, Permission.ownLoans),
  ('Читатели', '/readers', Icons.badge_outlined, Permission.manageReaders),
  ('Выдачи', '/loans', Icons.swap_horiz, Permission.manageLoans),
  (
    'Пользователи',
    '/admin/users',
    Icons.manage_accounts_outlined,
    Permission.manageUsers,
  ),
  ('Статистика', '/admin/stats', Icons.bar_chart, Permission.viewStats),
];

/// Каркас экранов: меню разделов текущей роли, имя пользователя и выход.
class CatalogScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  const CatalogScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    context.read<LookupNotifier>().ensureLoaded();
    final user = auth.user;
    final location = GoRouterState.of(context).uri.path;
    final sections = [
      for (final s in appSections)
        if (s.$4 == null || auth.can(s.$4!)) s,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('${user.fullName} · ${user.role.label}'),
            ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: sections.indexWhere((s) => s.$2 == location),
        onDestinationSelected: (i) {
          Navigator.pop(context);
          context.go(sections[i].$2);
        },
        children: [
          const SizedBox(height: 16),
          for (final s in sections)
            NavigationDrawerDestination(icon: Icon(s.$3), label: Text(s.$1)),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(child: body),
    );
  }
}
