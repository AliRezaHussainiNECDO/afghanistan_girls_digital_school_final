import '../../domain/entities/grade_map.dart';

class GradeMapModel extends GradeMap {
  const GradeMapModel({
    required super.gradeNumber,
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
        gradeLocked: json['gradeLocked'] as bool,
        gradeAveragePercent: (json['gradeAveragePercent'] as num).toDouble(),
        attendanceRatePercent: (json['attendanceRatePercent'] as num).toDouble(),
        subjects: (json['subjects'] as List)
            .map((e) => GradeMapSubjectEntry(
                  subjectId: e['subjectId'] as String,
                  subjectNameFa: e['subjectNameFa'] as String,
                  status: SubjectProgressStatus.values.firstWhere((s) => s.name == e['status']),
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
