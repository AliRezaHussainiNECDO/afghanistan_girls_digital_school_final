import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/library_remote_datasource.dart' show LibraryDataSource;

class LibraryRepositoryImpl implements LibraryRepository {
  final LibraryDataSource dataSource;
  LibraryRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<Book>>> searchBooks(String query) async {
    try {
      return Right(await dataSource.search(query));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
