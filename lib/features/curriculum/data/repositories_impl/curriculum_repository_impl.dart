import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Lesson>>> getLessons(String chapterId) async {
    try {
      return Right(await dataSource.getLessons(chapterId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lesson>> getLesson(String lessonId) async {
    try {
      return Right(await dataSource.getLesson(lessonId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LessonViewResult>> markLessonViewed(String lessonId) async {
    try {
      return Right(await dataSource.markLessonViewed(lessonId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, LessonLearnedResult>> markLessonLearned(String lessonId) async {
    try {
      return Right(await dataSource.markLessonLearned(lessonId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // رفع اشکال «برنامه شکست می‌خورد» (که واقعیتش یک خطای فنی خام بود، نه
  // کرش): قبلاً همهٔ متدهای بالا با `ServerFailure(e.toString())` یک
  // `ApiException` را مستقیم به‌صورت متن خام (مثل
  // `ApiException(ApiErrorType.forbidden, status: 403, code: LESSON_LOCKED, ...)`)
  // به کاربر نشان می‌دادند. همان الگوی درستِ استفاده‌شده در
  // `homework_repository_impl.dart` اینجا هم پیاده شد: پیام تمیز/محلی‌سازی‌شدهٔ
  // سرور استخراج می‌شود، نه dump فنی کل Exception.
  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
