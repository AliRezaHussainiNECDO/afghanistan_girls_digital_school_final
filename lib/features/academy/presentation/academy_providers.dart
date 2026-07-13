import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/network_providers.dart';
import '../../../core/student/selected_grade_provider.dart';
import '../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/academy_store.dart';
import '../data/ai_assessment_service.dart';
import '../domain/academy_entities.dart';

/// انبار مشترک و سرویس هوش مصنوعی.
final academyStoreProvider = Provider<AcademyStore>((ref) => AcademyStore());

/// همگام‌سازی اولیهٔ آکادمی با سرور. در حالت Live، کلاینت API به انبار داده
/// شده و داده‌ها از سرور بارگذاری می‌شوند؛ همهٔ Providerهای خواندن پیش از
/// برگرداندن داده منتظر این می‌مانند تا کش از سرور پر شود.
final academyHydrationProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(academyStoreProvider);
  if (kUseLiveBackend) {
    store.configure(ref.watch(apiClientProvider));
    await store.hydrate();
  }
  return true;
});

final aiAssessmentServiceProvider = Provider<AiAssessmentService>(
  (ref) => AiAssessmentService(ref.watch(activeAiEngineProvider)),
);

/// شاگرد فعلی — از نشست کاربر ساخته می‌شود و صنفِ فعالش از
/// `activeGradeProvider` (منبع واحد حقیقت) گرفته می‌شود؛ بنابراین پس از
/// ارتقا خودکار به‌روز می‌شود و نیازی به invalidate دستی نیست.
final currentStudentProvider = Provider<StudentProfile>((ref) {
  final user = ref.watch(authSessionProvider);
  if (user == null) return ref.watch(academyStoreProvider).studentById('st2');
  final grade = ref.watch(activeGradeProvider);
  return StudentProfile(id: user.id, displayName: user.displayName, gradeIds: [grade]);
});

// ─────────────────────── کتاب‌ها ───────────────────────
/// همهٔ کتاب‌ها (نمای مدیر — شامل پیش‌نویس‌ها).
final cmsBooksListProvider = FutureProvider<List<LibraryBook>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  return ref.watch(academyStoreProvider).getBooks();
});

/// جستجوی کتابخانهٔ شاگرد.
final librarySearchProvider = StateProvider<String>((ref) => '');

/// کتاب‌های منتشرشده برای شاگرد (فقط published).
final publishedBooksProvider = FutureProvider<List<LibraryBook>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  final q = ref.watch(librarySearchProvider);
  return ref.watch(academyStoreProvider).getBooks(publishedOnly: true, query: q);
});

// ─────────────────────── بانک سؤالات ───────────────────────
final cmsQuestionsListProvider = FutureProvider<List<BankQuestion>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  return ref.watch(academyStoreProvider).getQuestions();
});

// ─────────────────────── امتحانات (شاگرد) ───────────────────────
final studentExamsProvider = FutureProvider<List<SubjectExam>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  final student = ref.watch(currentStudentProvider);
  return ref.watch(academyStoreProvider).getSubjectExams(gradeIds: student.gradeIds);
});

/// سؤالات یک امتحان مشخص؛ کلید = "subject#gradeId".
final examQuestionsProvider = FutureProvider.family<List<BankQuestion>, String>((ref, key) async {
  await ref.watch(academyHydrationProvider.future);
  final parts = key.split('#');
  final subject = parts[0];
  final gradeId = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return ref.watch(academyStoreProvider).getExamQuestions(subject, gradeId);
});

// ─────────────────────── پاسخ‌ها ───────────────────────
/// همهٔ پاسخ‌های ثبت‌شده (نمای مدیر).
final allSubmissionsProvider = FutureProvider<List<Submission>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  return ref.watch(academyStoreProvider).getSubmissions();
});

/// پاسخ‌های شاگرد فعلی (نتایج خودش).
final mySubmissionsProvider = FutureProvider<List<Submission>>((ref) async {
  await ref.watch(academyHydrationProvider.future);
  final student = ref.watch(currentStudentProvider);
  return ref.watch(academyStoreProvider).getSubmissions(studentId: student.id);
});

/// پاسخ‌های یک شاگرد مشخص (نمای والد)؛ کلید = studentId.
final submissionsByStudentProvider =
    FutureProvider.family<List<Submission>, String>((ref, studentId) async {
  await ref.watch(academyHydrationProvider.future);
  return ref.watch(academyStoreProvider).getSubmissions(studentId: studentId);
});
