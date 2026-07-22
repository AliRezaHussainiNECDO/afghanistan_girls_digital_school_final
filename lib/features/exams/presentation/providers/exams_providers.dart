import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/exams_mock_datasource.dart';
import '../../data/datasources/exams_remote_datasource.dart';
import '../../data/repositories_impl/exams_repository_impl.dart';
import '../../domain/entities/exam_entities.dart';
import '../../domain/repositories/exams_repository.dart';
import '../../domain/usecases/exams_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final examsDataSourceProvider = Provider<ExamsDataSource>((ref) {
  if (kUseLiveBackend) {
    return ExamsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ExamsMockDataSource();
});
final examsRepositoryProvider =
    Provider<ExamsRepository>((ref) => ExamsRepositoryImpl(ref.watch(examsDataSourceProvider)));

final getAvailableExamsUseCaseProvider =
    Provider((ref) => GetAvailableExamsUseCase(ref.watch(examsRepositoryProvider)));
final getQuestionsUseCaseProvider =
    Provider((ref) => GetQuestionsUseCase(ref.watch(examsRepositoryProvider)));
final submitAnswersUseCaseProvider =
    Provider((ref) => SubmitAnswersUseCase(ref.watch(examsRepositoryProvider)));
final getMyExamResultsUseCaseProvider =
    Provider((ref) => GetMyExamResultsUseCase(ref.watch(examsRepositoryProvider)));
final getExamAttemptReviewUseCaseProvider =
    Provider((ref) => GetExamAttemptReviewUseCase(ref.watch(examsRepositoryProvider)));

final availableExamsProvider = FutureProvider<List<ExamSummary>>((ref) async {
  final result = await ref.read(getAvailableExamsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final examQuestionsProvider = FutureProvider.family<List<ExamQuestion>, String>((ref, examId) async {
  final result = await ref.read(getQuestionsUseCaseProvider).call(examId);
  return result.fold((f) => throw f, (v) => v);
});

/// نتایج امتحانات رسمی — `null` یعنی خودِ کاربر واردشده (شاگرد)؛ مقدار
/// غیر-null یعنی شناسهٔ فرزند (استفادهٔ داشبورد والدین — همان داده،
/// هماهنگ با صفحهٔ شاگرد).
final myExamResultsProvider = FutureProvider.family<List<ExamResultSummary>, String?>((ref, studentId) async {
  final result = await ref.read(getMyExamResultsUseCaseProvider).call(studentId);
  return result.fold((f) => throw f, (v) => v);
});

final examAttemptReviewProvider = FutureProvider.family<ExamAttemptReview, String>((ref, attemptId) async {
  final result = await ref.read(getExamAttemptReviewUseCaseProvider).call(attemptId);
  return result.fold((f) => throw f, (v) => v);
});
