import '../../domain/entities/grade_map.dart';
import '../../../../shared_models/subject.dart';
import '../../../progression/data/progression_store.dart';
import 'grade_map_remote_datasource.dart' show GradeMapDataSource;

/// DataSource ساختگی نقشهٔ صنوف — جایگزین‌شونده با Remote واقعی در فاز ۳
/// (`GET /api/v1/students/{id}/grade-map` — بخش ۱۹.۲).
///
/// **اصلاح:** به‌جای دادهٔ ثابت (صنف ۹ hard-coded)، نقشه از «انبار ارتقا»
/// (ProgressionStore) ساخته می‌شود — همان منبعی که نصاب درسی استفاده می‌کند.
/// بنابراین صنفِ نمایش‌داده‌شده همیشه صنف فعال واقعی شاگرد است و پس از
/// ارتقا خودکار به‌روز می‌شود. در فاز ۳ همین نقش را Backend ایفا می‌کند.
class GradeMapMockDataSource implements GradeMapDataSource {
  @override
  Future<GradeMap> getGradeMap(String studentId, {int fallbackGrade = 7}) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final p = ProgressionStore.instance
        .progressFor(studentId, fallbackGrade: fallbackGrade);

    final subjects = mockSubjects.map((subject) {
      final completion = (p.completion[subject.id] ?? 0).clamp(0, 100).toDouble();
      final SubjectProgressStatus status;
      if (completion >= 100) {
        status = SubjectProgressStatus.completed;
      } else if (completion > 0) {
        status = SubjectProgressStatus.inProgress;
      } else {
        status = SubjectProgressStatus.unlocked;
      }
      return GradeMapSubjectEntry(
        subjectId: subject.id,
        subjectNameFa: subject.nameFa,
        status: status,
        finalScore: completion >= 100 ? completion : null,
        completionPercent: completion,
      );
    }).toList();

    return GradeMap(
      gradeNumber: p.currentGrade, // صنف فعال واقعی — نه مقدار ثابت
      gradeLocked: false,
      gradeAveragePercent: p.overallCompletion,
      attendanceRatePercent: 91.2, // حاضری هنوز mock است (فاز ۳: از Backend)
      subjects: subjects,
      allSubjectsComplete: p.allSubjectsComplete,
      examPassed: p.examPassed,
      examBestScore: p.examTaken ? p.examScore : null,
      canPromote: p.canPromote,
    );
  }
}
