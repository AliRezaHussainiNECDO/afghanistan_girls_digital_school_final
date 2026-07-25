import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/admin_final_exam_mock_datasource.dart';
import '../../data/datasources/admin_final_exam_remote_datasource.dart';
import '../../data/repositories_impl/admin_final_exam_repository_impl.dart';
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/repositories/admin_final_exam_repository.dart';
import '../../domain/usecases/admin_final_exam_usecases.dart';

final adminFinalExamDataSourceProvider = Provider<AdminFinalExamDataSource>((ref) {
  if (kUseLiveBackend) {
    return AdminFinalExamRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AdminFinalExamMockDataSource();
});

final adminFinalExamRepositoryProvider =
    Provider<AdminFinalExamRepository>((ref) => AdminFinalExamRepositoryImpl(ref.watch(adminFinalExamDataSourceProvider)));

final getAdminFinalExamsUseCaseProvider = Provider((ref) => GetAdminFinalExamsUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final createFinalExamUseCaseProvider = Provider((ref) => CreateFinalExamUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final setFinalExamStatusUseCaseProvider = Provider((ref) => SetFinalExamStatusUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final deleteFinalExamUseCaseProvider = Provider((ref) => DeleteFinalExamUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final getAdminFinalExamQuestionsUseCaseProvider =
    Provider((ref) => GetAdminFinalExamQuestionsUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final saveFinalExamQuestionUseCaseProvider =
    Provider((ref) => SaveFinalExamQuestionUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final deleteFinalExamQuestionUseCaseProvider =
    Provider((ref) => DeleteFinalExamQuestionUseCase(ref.watch(adminFinalExamRepositoryProvider)));
final generateFinalExamQuestionsUseCaseProvider =
    Provider((ref) => GenerateFinalExamQuestionsUseCase(ref.watch(adminFinalExamRepositoryProvider)));

final adminFinalExamsProvider = FutureProvider.autoDispose.family<List<AdminFinalExamRow>, int?>((ref, gradeNumber) async {
  final result = await ref.watch(getAdminFinalExamsUseCaseProvider).call(GetAdminFinalExamsParams(gradeNumber: gradeNumber));
  return result.fold((f) => throw f, (v) => v);
});

final adminFinalExamQuestionsProvider = FutureProvider.autoDispose.family<List<AdminFinalExamQuestionRow>, String>((ref, finalExamId) async {
  final result = await ref.watch(getAdminFinalExamQuestionsUseCaseProvider).call(finalExamId);
  return result.fold((f) => throw f, (v) => v);
});
