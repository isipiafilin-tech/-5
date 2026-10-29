import '../models/app_user.dart';
import '../models/genre.dart';
import '../models/loan.dart';
import '../models/publisher.dart';
import '../models/reader.dart';
import '../models/simple_query.dart';
import '../repositories/book_repository.dart';
import '../repositories/api_catalog_repositories.dart';
import 'list_notifier.dart';

class GenreListNotifier extends ListNotifier<Genre, SimpleQuery> {
  GenreListNotifier(GenreRepository repository, {super.onChanged})
    : super(repository, genreQuery, (g) => g.id);
}

class PublisherListNotifier extends ListNotifier<Publisher, SimpleQuery> {
  final BookRepository _books;

  PublisherListNotifier(
    PublisherRepository repository,
    this._books, {
    super.onChanged,
  }) : super(repository, publisherQuery, (p) => p.id);

  /// Издательство нельзя удалить, пока на него ссылаются книги.
  @override
  Future<String?> deleteBlockReason(int id) async {
    final count = await _books.countByPublisher(id);
    if (count == 0) return null;
    final name = (await findById(id))?.name ?? '#$id';
    return 'Нельзя удалить издательство «$name»: на него ссылаются '
        '$count ${_booksWord(count)}. Сначала укажите у этих книг другое '
        'издательство.';
  }

  static String _booksWord(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'книга';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'книги';
    }
    return 'книг';
  }
}

class ReaderListNotifier extends ListNotifier<Reader, SimpleQuery> {
  ReaderListNotifier(ReaderRepository repository, {super.onChanged})
    : super(repository, readerQuery, (r) => r.id);
}

class LoanListNotifier extends ListNotifier<Loan, SimpleQuery> {
  final LoanRepository _loans;

  LoanListNotifier(this._loans, [SimpleQuery query = loanQuery])
    : super(_loans, query, (l) => l.id);

  Future<void> close(int id) async {
    await _loans.close(id);
    await load();
  }

  Future<void> extend(Loan loan, {int days = 14}) async {
    await _loans.extend(loan, days);
    await load();
  }
}

/// Отдельный экземпляр для экрана «Мои выдачи».
class MyLoanListNotifier extends LoanListNotifier {
  MyLoanListNotifier(LoanRepository loans) : super(loans, myLoanQuery);
}

class UserListNotifier extends ListNotifier<AppUser, SimpleQuery> {
  UserListNotifier(UserRepository repository)
    : super(repository, userQuery, (u) => u.id);
}

class StatsNotifier {
  final StatsRepository _stats;

  StatsNotifier(this._stats);

  Future<List<(String, int)>> load() => _stats.load();
}
