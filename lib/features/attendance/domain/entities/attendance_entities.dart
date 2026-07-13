import 'package:equatable/equatable.dart';

/// طبق بخش ۹.۲ سند.
enum AttendanceStatus { present, partial, absent, excused }

class AttendanceDay extends Equatable {
  final DateTime date;
  final AttendanceStatus status;
  const AttendanceDay({required this.date, required this.status});
  @override
  List<Object?> get props => [date, status];
}

class AttendanceSummary extends Equatable {
  final double ratePercent; // طبق فرمول بخش ۹.۳
  final List<AttendanceDay> recentDays;
  const AttendanceSummary({required this.ratePercent, required this.recentDays});
  @override
  List<Object?> get props => [ratePercent];
}
