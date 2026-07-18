import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/grade_map_mock_datasource.dart';
import '../../data/datasources/grade_map_remote_datasource.dart';
import '../../data/repositories_impl/grade_map_repository_impl.dart';
import '../../domain/entities/grade_map.dart';
import '../../domain/repositories/grade_map_repository.dart';
import '../../domain/usecases/get_grade_map_usecase.dart';
import '../../../progression/data/progression_store.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final gradeMapDataSourceProvider = Provider<GradeMapDataSource>((ref) {
  if (kUseLiveBackend) {
    return GradeMapRemoteDataSource(ref.watch(apiClientProvider));
  }
  return GradeMapMockDataSource();
});

final gradeMapRepositoryProvider = Provider<GradeMapRepository>(
  (ref) => GradeMapRepositoryImpl(ref.watch(gradeMapDataSourceProvider)),
);

final getGradeMapUseCaseProvider =
    Provider((ref) => GetGradeMapUseCase(ref.watch(gradeMapRepositoryProvider)));

/// کلید این Provider — شناسهٔ شاگرد + **کدام صنف** (رفع اشکال: قبلاً فقط
/// `studentId` کلید بود، پس همیشه یک نتیجهٔ کش‌شدهٔ واحد برای همهٔ صنوف
/// وجود داشت و «وضعیت ارتقا»/«نقشهٔ صنف» برای هر صنفِ مرورشده‌ای عیناً همان
/// وضعیت صنف فعال را نشان می‌داد).
typedef GradeMapKey = ({String studentId, int grade});

/// طبق مثال دقیق بخش ۲۴.۵ سند.
///
/// **اصلاح:** با watch کردن «انبار ارتقا»، نقشهٔ صنوف پس از هر ارتقا/تغییر
/// پیشرفت خودکار تازه می‌شود. همچنین اکنون به‌ازای هر صنفِ درخواست‌شده
/// (نه فقط صنف فعال) به‌طور جداگانه کش/واکشی می‌شود.
final gradeMapProvider = FutureProvider.autoDispose.family<GradeMap, GradeMapKey>((ref, key) async {
  ref.watch(progressionStoreProvider); // بازخوانی خودکار پس از ارتقا
  // اطمینان از اینکه رکورد پیشرفت با صنفِ درست (صنف راجستر کاربر) ساخته شود.
  final fallback = ref.watch(authSessionProvider)?.currentGrade ?? 7;
  ProgressionStore.instance.progressFor(key.studentId, fallbackGrade: fallback);
  final useCase = ref.watch(getGradeMapUseCaseProvider);
  final result = await useCase(GetGradeMapParams(studentId: key.studentId, grade: key.grade));
  return result.fold((failure) => throw failure, (gradeMap) => gradeMap);
});
