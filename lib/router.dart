import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'models/author_query.dart';
import 'models/book_query.dart';
import 'models/permissions.dart';
import 'models/simple_query.dart';
import 'screens/auth_screens.dart';
import 'screens/author_screens.dart';
import 'screens/book_screens.dart';
import 'screens/genre_screens.dart';
import 'screens/home_screen.dart';
import 'screens/loan_admin_screens.dart';
import 'screens/publisher_screens.dart';
import 'screens/reader_screens.dart';
import 'state/auth_notifier.dart';

GoRouter buildRouter(AuthNotifier auth) {
  /// Проверка роли на уровне маршрута: чужой адрес ведёт на экран отказа.
  String? need(Permission p, GoRouterState s) => auth.can(p)
      ? null
      : '/forbidden?from=${Uri.encodeComponent(s.uri.toString())}';

  /// Маршруты сущности: список, создание, карточка, изменение.
  GoRoute entity(
    String path, {
    required Permission view,
    required Permission edit,
    required Widget Function(Map<String, String> params) list,
    required Widget Function(int id) detail,
    required Widget Function(int? id) form,
  }) {
    int idOf(GoRouterState s) =>
        int.tryParse(s.pathParameters['id'] ?? '') ?? -1;
    return GoRoute(
      path: path,
      redirect: (_, s) => need(view, s),
      builder: (_, s) => list(s.uri.queryParameters),
      routes: [
        GoRoute(
          path: 'new',
          redirect: (_, s) => need(edit, s),
          builder: (_, _) => form(null),
        ),
        GoRoute(
          path: ':id',
          builder: (_, s) => detail(idOf(s)),
          routes: [
            GoRoute(
              path: 'edit',
              redirect: (_, s) => need(edit, s),
              builder: (_, s) => form(idOf(s)),
            ),
          ],
        ),
      ],
    );
  }

  return GoRouter(
    // Маршрутизатор пересчитывает redirect при каждом notifyListeners().
    refreshListenable: auth,
    initialLocation: '/',
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      // Не вошёл и идёт на закрытый экран — на вход, запомнив адрес.
      if (!loggedIn && !isPublic) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      // Вошёл — возвращаем туда, откуда отправили на вход.
      if (loggedIn && isPublic) {
        return state.uri.queryParameters['from'] ?? '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forbidden', builder: (_, _) => const ForbiddenScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      entity(
        '/books',
        view: Permission.viewCatalog,
        edit: Permission.manageCatalog,
        list: (p) => BooksScreen(query: BookQuery.fromQueryParameters(p)),
        detail: (id) => BookDetailScreen(id: id),
        form: (id) => BookFormScreen(id: id),
      ),
      entity(
        '/authors',
        view: Permission.viewCatalog,
        edit: Permission.manageCatalog,
        list: (p) => AuthorsScreen(query: AuthorQuery.fromQueryParameters(p)),
        detail: (id) => AuthorDetailScreen(id: id),
        form: (id) => AuthorFormScreen(id: id),
      ),
      entity(
        '/genres',
        view: Permission.viewCatalog,
        edit: Permission.manageCatalog,
        list: (p) => GenresScreen(query: SimpleQuery.parse(genreQuery, p)),
        detail: (id) => GenreDetailScreen(id: id),
        form: (id) => GenreFormScreen(id: id),
      ),
      entity(
        '/publishers',
        view: Permission.viewCatalog,
        edit: Permission.manageCatalog,
        list: (p) =>
            PublishersScreen(query: SimpleQuery.parse(publisherQuery, p)),
        detail: (id) => PublisherDetailScreen(id: id),
        form: (id) => PublisherFormScreen(id: id),
      ),
      entity(
        '/readers',
        view: Permission.manageReaders,
        edit: Permission.manageReaders,
        list: (p) => ReadersScreen(query: SimpleQuery.parse(readerQuery, p)),
        detail: (id) => ReaderDetailScreen(id: id),
        form: (id) => ReaderFormScreen(id: id),
      ),
      GoRoute(
        path: '/loans',
        redirect: (_, s) => need(Permission.manageLoans, s),
        builder: (_, s) => LoansScreen(
          query: SimpleQuery.parse(loanQuery, s.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/my-loans',
        redirect: (_, s) => need(Permission.ownLoans, s),
        builder: (_, s) => MyLoansScreen(
          query: SimpleQuery.parse(myLoanQuery, s.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/admin/users',
        redirect: (_, s) => need(Permission.manageUsers, s),
        builder: (_, s) => UsersScreen(
          query: SimpleQuery.parse(userQuery, s.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: '/admin/stats',
        redirect: (_, s) => need(Permission.viewStats, s),
        builder: (_, _) => const StatsScreen(),
      ),
    ],
  );
}
