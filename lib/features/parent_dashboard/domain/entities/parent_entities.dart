import 'package:equatable/equatable.dart';

class LinkedChild extends Equatable {
  final String studentId;
  final String displayName;
  const LinkedChild({required this.studentId, required this.displayName});
  @override
  List<Object?> get props => [studentId];
}

class ChildSubjectSummary extends Equatable {
  final String subjectNameFa;
  final String statusLabel; // completed/in_progress/locked — نمایش آماده از Backend
  final double? finalScore;
  const ChildSubjectSummary({required this.subjectNameFa, required this.statusLabel, this.finalScore});
  @override
  List<Object?> get props => [subjectNameFa];
}

/// خروجی Allow-list دقیق `GET /parents/{parentId}/children/{studentId}/summary`
/// — طبق بخش ۱۳ب.۳ سند (**فقط** فیلدهای زیر، نه یک Endpoint عمومی فیلترشده).
class ChildSummary extends Equatable {
  final String studentId;
  final String displayName;
  final int gradeNumber;
  final double gradeCompletionPercent;
  final double attendanceRatePercent;
  final List<ChildSubjectSummary> subjects;
  final List<String> achievements;
  final List<String> certificates;
  final List<String> upcomingSeminarTitles;

  const ChildSummary({
    required this.studentId,
    required this.displayName,
    required this.gradeNumber,
    required this.gradeCompletionPercent,
    required this.attendanceRatePercent,
    required this.subjects,
    required this.achievements,
    required this.certificates,
    required this.upcomingSeminarTitles,
  });

  @override
  List<Object?> get props => [studentId];
}
