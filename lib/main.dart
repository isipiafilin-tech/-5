import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/auth_api.dart';
import 'core/config.dart';
import 'repositories/api_book_repository.dart';
import 'repositories/api_catalog_repositories.dart';
import 'repositories/author_repository.dart';
import 'repositories/book_repository.dart';
import 'router.dart';
import 'state/auth_notifier.dart';
import 'state/author_list_notifier.dart';
import 'state/book_list_notifier.dart';
import 'state/catalog_notifiers.dart';
import 'state/lookup_notifier.dart';
import 'widgets/inactivity_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Сессия восстанавливается до построения виджетов.
  final auth = AuthNotifier(await SharedPreferences.getInstance(), AuthApi());
  await auth.restore();

  final dio = buildDio(
    token: () => auth.accessToken,
    refreshTokens: auth.refreshTokens,
    onAuthFailed: () => auth.logout(reason: AuthNotifier.expiredReason),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<Dio>.value(value: dio),
        ProxyProvider<Dio, BookRepository>(
          update: (_, dio, _) => ApiBookRepository(dio),
        ),
        ProxyProvider<Dio, AuthorRepository>(
          update: (_, dio, _) => ApiAuthorRepository(dio),
        ),
        ProxyProvider<Dio, GenreRepository>(
          update: (_, dio, _) => ApiGenreRepository(dio),
        ),
        ProxyProvider<Dio, PublisherRepository>(
          update: (_, dio, _) => ApiPublisherRepository(dio),
        ),
        ProxyProvider<Dio, ReaderRepository>(
          update: (_, dio, _) => ApiReaderRepository(dio),
        ),
        ProxyProvider<Dio, LoanRepository>(
          update: (_, dio, _) => ApiLoanRepository(dio),
        ),
        ProxyProvider<Dio, UserRepository>(
          update: (_, dio, _) => ApiUserRepository(dio),
        ),
        ProxyProvider<Dio, StatsRepository>(
          update: (_, dio, _) => ApiStatsRepository(dio),
        ),
        ChangeNotifierProvider(
          create: (c) => LookupNotifier(
            c.read<GenreRepository>(),
            c.read<PublisherRepository>(),
            c.read<AuthorRepository>(),
          )..ensureLoaded(),
        ),
        // Изменения жанров, издательств и авторов обновляют справочники.
        ChangeNotifierProvider(
          create: (c) => BookListNotifier(
            c.read<BookRepository>(),
            c.read<LoanRepository>(),
            onChanged: c.read<LookupNotifier>().refresh,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => AuthorListNotifier(
            c.read<AuthorRepository>(),
            onChanged: c.read<LookupNotifier>().refresh,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => GenreListNotifier(
            c.read<GenreRepository>(),
            onChanged: c.read<LookupNotifier>().refresh,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => PublisherListNotifier(
            c.read<PublisherRepository>(),
            c.read<BookRepository>(),
            onChanged: c.read<LookupNotifier>().refresh,
          ),
        ),
        ChangeNotifierProvider(
          create: (c) => ReaderListNotifier(c.read<ReaderRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => LoanListNotifier(c.read<LoanRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => MyLoanListNotifier(c.read<LoanRepository>()),
        ),
        ChangeNotifierProvider(
          create: (c) => UserListNotifier(c.read<UserRepository>()),
        ),
        Provider(create: (c) => StatsNotifier(c.read<StatsRepository>())),
      ],
      child: LibraryApp(router: buildRouter(auth)),
    ),
  );
}

class LibraryApp extends StatelessWidget {
  final GoRouter router;

  const LibraryApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return MaterialApp.router(
      title: 'Библиотека',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
      // Выход по неактивности отслеживается только у вошедшего пользователя.
      builder: (context, child) => auth.isAuthenticated
          ? InactivityWatcher(
              timeout: inactivityTimeout,
              warning: inactivityWarning,
              onTimeout: () =>
                  auth.logout(reason: AuthNotifier.inactivityReason),
              child: child!,
            )
          : child!,
    );
  }
}
