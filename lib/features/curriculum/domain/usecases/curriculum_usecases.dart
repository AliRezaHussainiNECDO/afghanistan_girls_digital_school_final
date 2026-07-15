import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/curriculum_entities.dart';
import '../repositories/curriculum_repository.dart';

class GetChaptersUseCase implements UseCase<List<Chapter>, String> {
  final CurriculumRepository repository;
  GetChaptersUseCase(this.repository);
  @override
  Future<Either<Failure, List<Chapter>>> call(String subjectId) => repository.getChapters(subjectId);
}

class GetLessonsUseCase implements UseCase<List<Lesson>, String> {
  final CurriculumRepository repository;
  GetLessonsUseCase(this.repository);
  @override
  Future<Either<Failure, List<Lesson>>> call(String chapterId) => repository.getLessons(chapterId);
}

class GetLessonUseCase implements UseCase<Lesson, String> {
  final CurriculumRepository repository;
  GetLessonUseCase(this.repository);
  @override
  Future<Either<Failure, Lesson>> call(String lessonId) => repository.getLesson(lessonId);
}

class MarkLessonViewedUseCase implements UseCase<LessonViewResult, String> {
  final CurriculumRepository repository;
  MarkLessonViewedUseCase(this.repository);
  @override
  Future<Either<Failure, LessonViewResult>> call(String lessonId) => repository.markLessonViewed(lessonId);
}
