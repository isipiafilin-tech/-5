import '../models/author.dart';
import '../models/author_query.dart';
import 'entity_repository.dart';

abstract interface class AuthorRepository
    implements EntityRepository<Author, AuthorQuery> {}
