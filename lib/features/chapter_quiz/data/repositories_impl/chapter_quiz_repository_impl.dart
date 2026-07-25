import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/chapter_quiz_entities.dart';
import '../../domain/repositories/chapter_quiz_repository.dart';
import '../datasources/chapter_quiz_remote_datasource.dart' show ChapterQuizDataSource;

class ChapterQuizRepositoryImpl implements ChapterQuizRepository {
  final ChapterQuizDataSource dataSource;
  ChapterQuizRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, ChapterQuizForm>> getQuiz(String chapterId) async {
    try {
      return Right(await dataSource.getQuiz(chapterId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ChapterQuizResult>> submit(
      String chapterId, Map<String, int> answers, Map<String, String> textAnswers) async {
    try {
      return Right(await dataSource.submit(chapterId, answers, textAnswers));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
