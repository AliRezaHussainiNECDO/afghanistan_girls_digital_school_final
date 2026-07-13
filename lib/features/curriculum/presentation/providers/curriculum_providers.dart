import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/curriculum_mock_datasource.dart';
import '../../data/datasources/curriculum_remote_datasource.dart';
import '../../data/repositories_impl/curriculum_repository_impl.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../../domain/repositories/curriculum_repository.dart';
import '../../domain/usecases/curriculum_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final curriculumDataSourceProvider = Provider<CurriculumDataSource>((ref) {
  if (kUseLiveBackend) {
    final grade = ref.watch(authSessionProvider)?.currentGrade ?? 7;
    return CurriculumRemoteDataSource(ref.watch(apiClientProvider), grade);
  }
  return CurriculumMockDataSource();
});

final curriculumRepositoryProvider = Provider<CurriculumRepository>(
  (ref) => CurriculumRepositoryImpl(ref.watch(curriculumDataSourceProvider)),
);

final getChaptersUseCaseProvider =
    Provider((ref) => GetChaptersUseCase(ref.watch(curriculumRepositoryProvider)));
final getLessonsUseCaseProvider =
    Provider((ref) => GetLessonsUseCase(ref.watch(curriculumRepositoryProvider)));
final getLessonUseCaseProvider =
    Provider((ref) => GetLessonUseCase(ref.watch(curriculumRepositoryProvider)));
final markLessonViewedUseCaseProvider =
    Provider((ref) => MarkLessonViewedUseCase(ref.watch(curriculumRepositoryProvider)));

final chaptersProvider = FutureProvider.family<List<Chapter>, String>((ref, subjectId) async {
  final result = await ref.read(getChaptersUseCaseProvider).call(subjectId);
  return result.fold((f) => throw f, (v) => v);
});

final lessonsProvider = FutureProvider.family<List<Lesson>, String>((ref, chapterId) async {
  final result = await ref.read(getLessonsUseCaseProvider).call(chapterId);
  return result.fold((f) => throw f, (v) => v);
});

final lessonProvider = FutureProvider.family<Lesson, String>((ref, lessonId) async {
  final result = await ref.read(getLessonUseCaseProvider).call(lessonId);
  return result.fold((f) => throw f, (v) => v);
});
