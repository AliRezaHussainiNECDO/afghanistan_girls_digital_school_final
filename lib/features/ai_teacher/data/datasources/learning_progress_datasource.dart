import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared_models/subject.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../domain/engine/book_section_utils.dart';
import '../../domain/entities/learning_progress.dart';

/// منبع دادهٔ «پیشرفت یادگیری» — کنار وضعیت گفتگوی معلم هوشمند
/// (ai_state_v2_*) ذخیره می‌شود تا درسِ خوانده‌شده حفظ و قابل ادامه باشد.
///
/// **صنف شاگرد اینجا هرگز به‌صورت محلی/مستقل ذخیره نمی‌شود** — منبع واحد
/// حقیقتِ صنف، `activeGradeProvider` (بر اساس حساب واقعی و پیشرفت رسمی
/// شاگرد) است و از بیرون به این کلاس داده می‌شود. همهٔ کلیدهای ذخیره‌سازی
/// با شمارهٔ صنف مشخص می‌شوند تا با ارتقای صنف، گفتگو/پیشرفت صنف قبلی با
/// صنف جدید قاطی نشود و هر صنف پیشرفت مستقل خودش را داشته باشد.
class LearningProgressDataSource {
  final CurriculumLibraryLocalDataSource library;
  LearningProgressDataSource(this.library);

  static String masteredKey(String subjectId, int grade) =>
      'ai_mastered_v2_g${grade}_$subjectId';
  static String lastStudiedKey(String subjectId, int grade) =>
      'ai_last_studied_v2_g${grade}_$subjectId';
  static String stateKey(String subjectId, int grade) =>
      'ai_state_v2_g${grade}_$subjectId';
  static String conversationKey(String subjectId, int grade) =>
      'ai_conversation_v2_g${grade}_$subjectId';

  /// ثبت فعالیت مطالعه (هر تعامل با معلم هوشمند).
  Future<void> recordActivity(String subjectId, int grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        lastStudiedKey(subjectId, grade), DateTime.now().toIso8601String());
  }

  /// ثبت «یادگرفته‌شدن» یک بخش (پس از پاسخ شاگرد به سوال معلم).
  Future<void> recordMastered(String subjectId, int grade) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(masteredKey(subjectId, grade)) ?? 0;
    await prefs.setInt(masteredKey(subjectId, grade), current + 1);
  }

  Future<SubjectLearningProgress> getForSubject(
      String subjectId, int grade) async {
    final prefs = await SharedPreferences.getInstance();

    // بخش‌های کتابِ صنف شاگرد (اگر نبود، همهٔ کتاب‌های مضمون).
    final books = await library.getBooksForSubject(subjectId);
    final gradeBooks = books.where((b) => b.gradeId == grade).toList();
    final effective = gradeBooks.isNotEmpty ? gradeBooks : books;
    final totalSections =
        BookSectionUtils.sectionsForBooks(effective).length;

    var sectionIndex = 0;
    final rawState = prefs.getString(stateKey(subjectId, grade));
    if (rawState != null) {
      try {
        sectionIndex =
            (jsonDecode(rawState) as Map)['sectionIndex'] as int? ?? 0;
      } catch (_) {}
    }

    final mastered = prefs.getInt(masteredKey(subjectId, grade)) ?? 0;
    final lastRaw = prefs.getString(lastStudiedKey(subjectId, grade));

    final subject = mockSubjects.firstWhere((s) => s.id == subjectId,
        orElse: () => mockSubjects.first);

    return SubjectLearningProgress(
      subjectId: subjectId,
      subjectNameFa: subject.nameFa,
      totalSections: totalSections,
      currentSectionIndex:
          totalSections == 0 ? 0 : sectionIndex.clamp(0, totalSections).toInt(),
      masteredSections:
          totalSections == 0 ? 0 : mastered.clamp(0, totalSections).toInt(),
      lastStudiedAt: lastRaw != null ? DateTime.tryParse(lastRaw) : null,
    );
  }

  /// پیشرفت همهٔ مضامین **صنف فعال واقعی شاگرد** — پایهٔ داشبورد و تقسیم
  /// اوقات هوشمند. `grade` باید از `activeGradeProvider` بیاید.
  Future<List<SubjectLearningProgress>> getAll(int grade) async {
    final result = <SubjectLearningProgress>[];
    for (final s in mockSubjects) {
      result.add(await getForSubject(s.id, grade));
    }
    return result;
  }
}
