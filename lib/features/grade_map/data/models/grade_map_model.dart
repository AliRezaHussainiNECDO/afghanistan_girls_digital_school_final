import '../../domain/entities/grade_map.dart';

class GradeMapModel extends GradeMap {
  const GradeMapModel({
    required super.gradeNumber,
    super.activeGradeNumber,
    required super.gradeLocked,
    required super.gradeAveragePercent,
    required super.attendanceRatePercent,
    required super.subjects,
    super.allSubjectsComplete,
    super.examPassed,
    super.examBestScore,
    super.canPromote,
  });

  factory GradeMapModel.fromJson(Map<String, dynamic> json) => GradeMapModel(
        gradeNumber: json['gradeNumber'] as int,
        activeGradeNumber: json['activeGradeNumber'] as int?,
        gradeLocked: json['gradeLocked'] as bool,
        gradeAveragePercent: (json['gradeAveragePercent'] as num).toDouble(),
        attendanceRatePercent: (json['attendanceRatePercent'] as num).toDouble(),
        subjects: (json['subjects'] as List)
            .map((e) => GradeMapSubjectEntry(
                  subjectId: e['subjectId'] as String,
                  subjectNameFa: e['subjectNameFa'] as String,
                  // رفع اشکال: بدون `orElse`، هر رشتهٔ وضعیتِ ناشناخته/نامنتظره از
                  // سرور (مثلاً یک مقدار جدید که هنوز به این enum اضافه نشده) کل
                  // پارس‌کردن نقشهٔ صنف را با یک StateError کرش می‌کرد. اکنون به‌جای
                  // کرش، محافظه‌کارانه `locked` نمایش داده می‌شود.
                  status: SubjectProgressStatus.values.firstWhere(
                    (s) => s.name == e['status'],
                    orElse: () => SubjectProgressStatus.locked,
                  ),
                  finalScore: (e['finalScore'] as num?)?.toDouble(),
                  completionPercent: (e['completionPercent'] as num? ?? 0).toDouble(),
                ))
            .toList(),
        allSubjectsComplete: json['allSubjectsComplete'] as bool? ?? false,
        examPassed: json['examPassed'] as bool? ?? false,
        examBestScore: (json['examBestScore'] as num?)?.toDouble(),
        canPromote: json['canPromote'] as bool? ?? false,
      );
}
