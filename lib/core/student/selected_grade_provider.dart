import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/progression/data/progression_store.dart';

/// صنوف قابل انتخاب برای شاگرد (۷ الی ۱۲) — طبق ساختار نصاب رسمی.
const List<int> kStudentGrades = [7, 8, 9, 10, 11, 12];

/// «انبار ارتقا» به‌صورت Provider — تا هر تغییر (ارتقا/کاهش صنف، تکمیل مضمون،
/// نتیجهٔ امتحان) به‌طور خودکار تمام صفحه‌های وابسته را بازسازی کند.
/// **توجه:** فقط در حالت Mock (`kUseLiveBackend == false`) منبع حقیقت است؛
/// در حالت Backend واقعی، صنف فعال از `authSessionProvider` می‌آید (پایین).
final progressionStoreProvider =
    ChangeNotifierProvider<ProgressionStore>((ref) => ProgressionStore.instance);

/// **منبع واحد حقیقتِ «صنف فعال» شاگرد.**
///
/// رفع اشکال: قبلاً این مقدار همیشه از «انبار ارتقای» محلی گوشی
/// (ProgressionStore) خوانده می‌شد — حتی وقتی برنامه به Backend واقعی وصل
/// بود — یعنی «نصاب درسی» می‌توانست صنفی نشان دهد که هیچ ربطی به
/// `current_grade` واقعیِ ثبت‌شده در دیتابیس نداشت (با نصب مجدد یا روی
/// گوشی دیگر از بین می‌رفت). اکنون:
///  • Backend واقعی → صنف واقعی کاربر (`authSessionProvider`، که پس از هر
///    ارتقای واقعی سرور بلافاصله به‌روز می‌شود — بخش auth_providers.dart).
///  • حالت Mock/آفلاین (فاز ۱) → همان رفتار قبلی از ProgressionStore.
final activeGradeProvider = Provider<int>((ref) {
  final user = ref.watch(authSessionProvider);

  if (kUseLiveBackend) {
    final grade = user?.currentGrade ?? kStudentGrades.first;
    return kStudentGrades.contains(grade) ? grade : kStudentGrades.first;
  }

  final store = ref.watch(progressionStoreProvider);
  final fallback = user?.currentGrade ?? kStudentGrades.first;
  final grade = store
      .progressFor(user?.id ?? 'me',
          fallbackGrade: kStudentGrades.contains(fallback) ? fallback : kStudentGrades.first)
      .currentGrade;
  return kStudentGrades.contains(grade) ? grade : kStudentGrades.first;
});

/// صنف انتخاب‌شدهٔ فعلی برای «مرور». مقدار اولیه = صنف فعال؛ شاگرد می‌تواند
/// صنوف تکمیل‌شدهٔ پایین‌تر را هم مرور کند، اما با ارتقا/کاهش صنف، انتخاب
/// خودکار به صنف فعال جدید منتقل می‌شود.
class SelectedGradeNotifier extends StateNotifier<int> {
  SelectedGradeNotifier(super.initial);

  void select(int grade) {
    if (kStudentGrades.contains(grade)) state = grade;
  }

  /// همگام‌سازی با صنف فعال جدید (پس از ارتقا یا کاهش صنف).
  void syncWithActive(int activeGrade) {
    if (kStudentGrades.contains(activeGrade)) state = activeGrade;
  }
}

final selectedGradeProvider = StateNotifierProvider<SelectedGradeNotifier, int>((ref) {
  final notifier = SelectedGradeNotifier(ref.read(activeGradeProvider));
  // با تغییر صنف فعال (ارتقا پس از امتحان، یا اقدام مدیر)، انتخاب به صنف
  // جدید به‌روز می‌شود تا داشبورد و نصاب همیشه صنف درست را نشان دهند.
  ref.listen<int>(activeGradeProvider, (previous, next) {
    if (previous != next) notifier.syncWithActive(next);
  });
  return notifier;
});
