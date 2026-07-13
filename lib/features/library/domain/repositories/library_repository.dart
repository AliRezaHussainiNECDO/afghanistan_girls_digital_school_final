import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/book.dart';

abstract class LibraryRepository {
  Future<Either<Failure, List<Book>>> searchBooks(String query);
}
