import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/admin_exams_mock_datasource.dart';
import '../../data/datasources/admin_exams_remote_datasource.dart';
import '../../data/repositories_impl/admin_exams_repository_impl.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../../domain/repositories/admin_exams_repository.dart';
import '../../domain/usecases/admin_exams_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final adminExamsDataSourceProvider = Provider<AdminExamsDataSource>((ref) {
  if (kUseLiveBackend) {
    return AdminExamsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return AdminExamsMockDataSource();
});

final adminExamsRepositoryProvider = Provider<AdminExamsRepository>(
  (ref) => AdminExamsRepositoryImpl(ref.watch(adminExamsDataSourceProvider)),
);

final getAdminExamsUseCaseProvider =
    Provider((ref) => GetAdminExamsUseCase(ref.watch(adminExamsRepositoryProvider)));
final saveExamUseCaseProvider = Provider((ref) => SaveExamUseCase(ref.watch(adminExamsRepositoryProvider)));
final setExamStatusUseCaseProvider =
    Provider((ref) => SetExamStatusUseCase(ref.watch(adminExamsRepositoryProvider)));
final deleteExamUseCaseProvider = Provider((ref) => DeleteExamUseCase(ref.watch(adminExamsRepositoryProvider)));

final getAdminQuestionsUseCaseProvider =
    Provider((ref) => GetAdminQuestionsUseCase(ref.watch(adminExamsRepositoryProvider)));
final saveQuestionUseCaseProvider =
    Provider((ref) => SaveQuestionUseCase(ref.watch(adminExamsRepositoryProvider)));
final deleteQuestionUseCaseProvider =
    Provider((ref) => DeleteQuestionUseCase(ref.watch(adminExamsRepositoryProvider)));

final adminExamsProvider = FutureProvider.autoDispose<List<AdminExamRow>>((ref) async {
  final result = await ref.read(getAdminExamsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final adminExamQuestionsProvider =
    FutureProvider.autoDispose.family<List<AdminQuestionRow>, String>((ref, examId) async {
  final result = await ref.read(getAdminQuestionsUseCaseProvider).call(examId);
  return result.fold((f) => throw f, (v) => v);
});
