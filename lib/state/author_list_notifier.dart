import '../models/author.dart';
import '../models/author_query.dart';
import '../repositories/author_repository.dart';
import 'list_notifier.dart';

class AuthorListNotifier extends ListNotifier<Author, AuthorQuery> {
  AuthorListNotifier(AuthorRepository repository, {super.onChanged})
    : super(repository, const AuthorQuery(), (a) => a.id);
}
