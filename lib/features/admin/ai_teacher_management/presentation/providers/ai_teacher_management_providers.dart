import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../data/datasources/ai_teacher_management_local_datasource.dart';
import '../../data/repositories_impl/ai_teacher_management_repository_impl.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/repositories/ai_teacher_management_repository.dart';
import '../../domain/usecases/ai_teacher_management_usecases.dart';

final aiTeacherMgmtDataSourceProvider =
    Provider((ref) => const AiTeacherManagementLocalDataSource());
final aiTeacherMgmtRepositoryProvider = Provider<AiTeacherManagementRepository>(
  (ref) => AiTeacherManagementRepositoryImpl(ref.watch(aiTeacherMgmtDataSourceProvider)),
);
final getAiTeacherConfigsUseCaseProvider =
    Provider((ref) => GetAiTeacherConfigsUseCase(ref.watch(aiTeacherMgmtRepositoryProvider)));
final updatePersonaUseCaseProvider =
    Provider((ref) => UpdatePersonaUseCase(ref.watch(aiTeacherMgmtRepositoryProvider)));

final aiTeacherConfigsProvider = FutureProvider<List<AiTeacherConfig>>((ref) async {
  final result = await ref.read(getAiTeacherConfigsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});
