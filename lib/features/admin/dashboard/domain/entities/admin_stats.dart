import 'package:equatable/equatable.dart';

/// طبق بخش ۱۵.۱ سند (KPI ها).
class AdminStats extends Equatable {
  final int totalStudents;
  final int activeToday;
  final int atRiskCount;
  final double avgScorePercent;
  final Map<int, int> gradeDistribution; // grade -> count

  const AdminStats({
    required this.totalStudents,
    required this.activeToday,
    required this.atRiskCount,
    required this.avgScorePercent,
    required this.gradeDistribution,
  });

  @override
  List<Object?> get props => [totalStudents, activeToday];
}
