import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/ai_teacher_management_data_source.dart';
import '../../data/datasources/ai_teacher_management_local_datasource.dart';
import '../../data/datasources/ai_teacher_management_remote_datasource.dart';
import '../../data/repositories_impl/ai_teacher_management_repository_impl.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/entities/ai_teacher_stats.dart';
import '../../domain/repositories/ai_teacher_management_repository.dart';
import '../../domain/usecases/ai_teacher_management_usecases.dart';

/// رفع اشکال: قبلاً همیشه از دادهٔ محلی (SharedPreferences) استفاده می‌شد و
/// این بخش هرگز به سرور/دیتابیس وصل نبود. اکنون مانند بقیهٔ ماژول‌ها با
/// سوییچ `kUseLiveBackend` بین محلی (فاز ۱ / آفلاین) و Backend واقعی جابه‌جا
/// می‌شود.
final aiTeacherMgmtDataSourceProvider = Provider<AiTeacherManagementDataSource>((ref) {
  if (kUseLiveBackend) {
    return AiTeacherManagementRemoteDataSource(ref.watch(apiClientProvider));
  }
  return const AiTeacherManagementLocalDataSource();
});
final aiTeacherMgmtRepositoryProvider = Provider<AiTeacherManagementRepository>(
  (ref) => AiTeacherManagementRepositoryImpl(ref.watch(aiTeacherMgmtDataSourceProvider)),
);
final getAiTeacherConfigsUseCaseProvider =
    Provider((ref) => GetAiTeacherConfigsUseCase(ref.watch(aiTeacherMgmtRepositoryProvider)));
final updatePersonaUseCaseProvider =
    Provider((ref) => UpdatePersonaUseCase(ref.watch(aiTeacherMgmtRepositoryProvider)));
final getAiTeacherStatsUseCaseProvider =
    Provider((ref) => GetAiTeacherStatsUseCase(ref.watch(aiTeacherMgmtRepositoryProvider)));

final aiTeacherConfigsProvider = FutureProvider<List<AiTeacherConfig>>((ref) async {
  final result = await ref.read(getAiTeacherConfigsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

/// آمار حقیقی معلم هوشمند — برای کارت‌های بالای پنل «مدیریت معلم هوشمند».
final aiTeacherStatsProvider = FutureProvider<AiTeacherStats>((ref) async {
  final result = await ref.read(getAiTeacherStatsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});
