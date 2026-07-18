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

// رفع اشکال ریشه‌ای «نصاب هنوز دیتای قبلی/صنف اشتباه را نشان می‌دهد»:
//
// ۱) این سه Provider قبلاً `ref.read(...UseCaseProvider)` را صدا می‌زدند —
//    یعنی هیچ‌وقت به تغییر Providerهای بالادست (`curriculumDataSourceProvider`
//    که با تغییر صنف واقعی شاگرد در `authSessionProvider` عوض می‌شود) گوش
//    نمی‌دادند. نتیجه: بعد از ارتقای صنف، تا وقتی برنامه کاملاً بسته/باز
//    نمی‌شد، همان فصل‌ها/درس‌های صنف قبلی از کش نشان داده می‌شدند. با
//    `ref.watch` این وابستگی درست برقرار می‌شود.
// ۲) این سه Provider `.family` ساده بودند (بدون `autoDispose`) — یعنی بعد
//    از اولین بار خواندن یک مضمون/فصل/درس، نتیجه برای کل عمر برنامه در
//    حافظه می‌ماند و هیچ اقدام مدیر (آپلود/ویرایش/حذف کتاب، «پاک‌سازی کامل
//    نصاب»، اصلاح متن معکوس، ویرایش دستی درس در CMS) هرگز آن را باطل
//    نمی‌کرد — چون invalidate باید در تک‌تک همان صفحات مدیریتی هم فراخوانی
//    می‌شد و به‌مرور فراموش/گم می‌شد. با `autoDispose`، به‌محض اینکه شاگرد از
//    آن صفحه خارج شود (فصل‌ها/درس‌ها دیگر روی صفحه نیست)، مقدار کش‌شده دور
//    ریخته می‌شود و دفعهٔ بعد که همان مضمون را باز کند، دوباره از سرور
//    خوانده می‌شود — یعنی همیشه آخرین نصاب واقعی (و مطابق همان صنف) دیده
//    می‌شود، بدون نیاز به invalidate دستی در هر نقطهٔ ممکنِ تغییر محتوا.
final chaptersProvider = FutureProvider.autoDispose.family<List<Chapter>, String>((ref, subjectId) async {
  final result = await ref.watch(getChaptersUseCaseProvider).call(subjectId);
  return result.fold((f) => throw f, (v) => v);
});

final lessonsProvider = FutureProvider.autoDispose.family<List<Lesson>, String>((ref, chapterId) async {
  final result = await ref.watch(getLessonsUseCaseProvider).call(chapterId);
  return result.fold((f) => throw f, (v) => v);
});

final lessonProvider = FutureProvider.autoDispose.family<Lesson, String>((ref, lessonId) async {
  final result = await ref.watch(getLessonUseCaseProvider).call(lessonId);
  return result.fold((f) => throw f, (v) => v);
});
