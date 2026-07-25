import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/final_exam_mock_datasource.dart';
import '../../data/datasources/final_exam_remote_datasource.dart';
import '../../data/repositories_impl/final_exam_repository_impl.dart';
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/repositories/final_exam_repository.dart';
import '../../domain/usecases/final_exam_usecases.dart';

final finalExamDataSourceProvider = Provider<FinalExamDataSource>((ref) {
  if (kUseLiveBackend) {
    return FinalExamRemoteDataSource(ref.watch(apiClientProvider));
  }
  return FinalExamMockDataSource();
});

final finalExamRepositoryProvider =
    Provider<FinalExamRepository>((ref) => FinalExamRepositoryImpl(ref.watch(finalExamDataSourceProvider)));

final getFinalExamAvailabilityUseCaseProvider =
    Provider((ref) => GetFinalExamAvailabilityUseCase(ref.watch(finalExamRepositoryProvider)));
final getFinalExamQuestionsUseCaseProvider =
    Provider((ref) => GetFinalExamQuestionsUseCase(ref.watch(finalExamRepositoryProvider)));
final submitFinalExamUseCaseProvider =
    Provider((ref) => SubmitFinalExamUseCase(ref.watch(finalExamRepositoryProvider)));
final getMyFinalExamResultsUseCaseProvider =
    Provider((ref) => GetMyFinalExamResultsUseCase(ref.watch(finalExamRepositoryProvider)));
final getFinalExamAttemptReviewUseCaseProvider =
    Provider((ref) => GetFinalExamAttemptReviewUseCase(ref.watch(finalExamRepositoryProvider)));

final finalExamAvailabilityProvider = FutureProvider.autoDispose<FinalExamAvailability>((ref) async {
  final result = await ref.watch(getFinalExamAvailabilityUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final finalExamQuestionsProvider = FutureProvider.family<List<FinalExamQuestion>, String>((ref, examId) async {
  final result = await ref.read(getFinalExamQuestionsUseCaseProvider).call(examId);
  return result.fold((f) => throw f, (v) => v);
});

final myFinalExamResultsProvider = FutureProvider.autoDispose.family<List<FinalExamResultSummary>, String?>((ref, studentId) async {
  final result = await ref.watch(getMyFinalExamResultsUseCaseProvider).call(studentId);
  return result.fold((f) => throw f, (v) => v);
});

final finalExamAttemptReviewProvider = FutureProvider.family<FinalExamAttemptReview, String>((ref, attemptId) async {
  final result = await ref.read(getFinalExamAttemptReviewUseCaseProvider).call(attemptId);
  return result.fold((f) => throw f, (v) => v);
});
