import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/chapter_quiz_mock_datasource.dart';
import '../../data/datasources/chapter_quiz_remote_datasource.dart';
import '../../data/repositories_impl/chapter_quiz_repository_impl.dart';
import '../../domain/entities/chapter_quiz_entities.dart';
import '../../domain/repositories/chapter_quiz_repository.dart';
import '../../domain/usecases/chapter_quiz_usecases.dart';

final chapterQuizDataSourceProvider = Provider<ChapterQuizDataSource>((ref) {
  if (kUseLiveBackend) {
    return ChapterQuizRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ChapterQuizMockDataSource();
});

final chapterQuizRepositoryProvider =
    Provider<ChapterQuizRepository>((ref) => ChapterQuizRepositoryImpl(ref.watch(chapterQuizDataSourceProvider)));

final getChapterQuizUseCaseProvider =
    Provider((ref) => GetChapterQuizUseCase(ref.watch(chapterQuizRepositoryProvider)));
final submitChapterQuizUseCaseProvider =
    Provider((ref) => SubmitChapterQuizUseCase(ref.watch(chapterQuizRepositoryProvider)));

/// فورم آزمون فصل (پیش/پس از ارسال) — family بر اساس chapterId.
final chapterQuizProvider = FutureProvider.family<ChapterQuizForm, String>((ref, chapterId) async {
  final result = await ref.read(getChapterQuizUseCaseProvider).call(chapterId);
  return result.fold((f) => throw f, (v) => v);
});
