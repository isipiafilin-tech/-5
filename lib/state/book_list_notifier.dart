import '../models/book.dart';
import '../models/book_query.dart';
import '../repositories/api_catalog_repositories.dart';
import '../repositories/book_repository.dart';
import 'list_notifier.dart';

class BookListNotifier extends ListNotifier<Book, BookQuery> {
  final BookRepository _books;
  final LoanRepository _loans;

  BookListNotifier(this._books, this._loans, {super.onChanged})
    : super(_books, const BookQuery(), (b) => b.id);

  Future<int> countByPublisher(int publisherId) =>
      _books.countByPublisher(publisherId);

  /// Выдача книги читателю; 409 — если нет свободных экземпляров.
  Future<void> issueLoan({required int bookId, required int readerId}) async {
    await _loans.issue(bookId: bookId, readerId: readerId);
    if (status != LoadStatus.idle) await load();
  }
}
