import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/curriculum_entities.dart';

abstract class CurriculumRepository {
  Future<Either<Failure, List<Chapter>>> getChapters(String subjectId);
  Future<Either<Failure, List<Lesson>>> getLessons(String chapterId);
  Future<Either<Failure, Lesson>> getLesson(String lessonId);

  /// طبق `POST /lessons/{id}/view` بخش ۱۹.۳ — ثبت بازدید، ورودی منطق C1،
  /// و اهدای امتیاز فعالیت (Gamification).
  Future<Either<Failure, LessonViewResult>> markLessonViewed(String lessonId);
}
