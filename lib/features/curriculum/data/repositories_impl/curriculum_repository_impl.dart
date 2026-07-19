import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../datasources/curriculum_remote_datasource.dart' show CurriculumDataSource;

class CurriculumRepositoryImpl implements CurriculumRepository {
  final CurriculumDataSource dataSource;
  CurriculumRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<Chapter>>> getChapters(String subjectId) async {
    try {
      return Right(await dataSource.getChapters(subjectId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Lesson>>> getLessons(String chapterId) async {
    try {
      return Right(await dataSource.getLessons(chapterId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lesson>> getLesson(String lessonId) async {
    try {
      return Right(await dataSource.getLesson(lessonId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LessonViewResult>> markLessonViewed(String lessonId) async {
    try {
      return Right(await dataSource.markLessonViewed(lessonId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LessonLearnedResult>> markLessonLearned(String lessonId) async {
    try {
      return Right(await dataSource.markLessonLearned(lessonId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
