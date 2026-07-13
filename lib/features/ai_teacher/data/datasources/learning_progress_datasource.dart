import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared_models/subject.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../domain/engine/book_section_utils.dart';
import '../../domain/entities/learning_progress.dart';

/// منبع دادهٔ «پیشرفت یادگیری» — کنار وضعیت گفتگوی معلم هوشمند
/// (ai_state_v1_*) ذخیره می‌شود تا درسِ خوانده‌شده حفظ و قابل ادامه باشد.
class LearningProgressDataSource {
  final CurriculumLibraryLocalDataSource library;
  LearningProgressDataSource(this.library);

  static const kGradeKey = 'student_grade_v1';
  static String masteredKey(String subjectId) => 'ai_mastered_v1_$subjectId';
  static String lastStudiedKey(String subjectId) =>
      'ai_last_studied_v1_$subjectId';
  static String stateKey(String subjectId) => 'ai_state_v1_$subjectId';

  Future<int> getStudentGrade() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kGradeKey) ?? 7;
  }

  Future<void> setStudentGrade(int grade) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kGradeKey, grade);
  }

  /// ثبت فعالیت مطالعه (هر تعامل با معلم هوشمند).
  Future<void> recordActivity(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        lastStudiedKey(subjectId), DateTime.now().toIso8601String());
  }

  /// ثبت «یادگرفته‌شدن» یک بخش (پس از پاسخ شاگرد به سوال معلم).
  Future<void> recordMastered(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(masteredKey(subjectId)) ?? 0;
    await prefs.setInt(masteredKey(subjectId), current + 1);
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
    final rawState = prefs.getString(stateKey(subjectId));
    if (rawState != null) {
      try {
        sectionIndex =
            (jsonDecode(rawState) as Map)['sectionIndex'] as int? ?? 0;
      } catch (_) {}
    }

    final mastered = prefs.getInt(masteredKey(subjectId)) ?? 0;
    final lastRaw = prefs.getString(lastStudiedKey(subjectId));

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

  /// پیشرفت همهٔ مضامین صنف شاگرد — پایهٔ داشبورد و تقسیم اوقات هوشمند.
  Future<List<SubjectLearningProgress>> getAll() async {
    final grade = await getStudentGrade();
    final result = <SubjectLearningProgress>[];
    for (final s in mockSubjects) {
      result.add(await getForSubject(s.id, grade));
    }
    return result;
  }
}
