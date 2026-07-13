import 'package:equatable/equatable.dart';

/// طبق بخش ۱۵.۵ سند («صف بازبینی ایمنی»).
enum SafetyItemType { chatFlag, aiEscalation, chatReport, atRisk }

enum SafetyItemStatus { open, reviewed, dismissed, escalated }

class SafetyQueueItem extends Equatable {
  final String id;
  final SafetyItemType type;
  final String summary;
  final bool highPriority;
  final SafetyItemStatus status;

  // ── فیلدهای جزئیات برای صفحهٔ بازبینی مدیر ──
  /// نام دانش‌آموز مرتبط (یا منبع رویداد).
  final String studentName;

  /// صنف/زمینهٔ دانش‌آموز.
  final String studentGrade;

  /// منبع رویداد (مثلاً «چت هم‌صنفی»، «AI Teacher — ریاضی»، «سیستم حاضری»).
  final String source;

  /// زمان ثبت رویداد.
  final DateTime detectedAt;

  /// متن/گزیدهٔ کامل محتوای پرچم‌خورده که مدیر باید ببیند.
  final String detail;

  /// دلیل ماشینی/کلمهٔ فیلترشده که باعث ثبت در صف شده است.
  final String triggerReason;

  SafetyQueueItem({
    required this.id,
    required this.type,
    required this.summary,
    required this.highPriority,
    required this.status,
    this.studentName = '',
    this.studentGrade = '',
    this.source = '',
    DateTime? detectedAt,
    this.detail = '',
    this.triggerReason = '',
  }) : detectedAt = detectedAt ?? DateTime(2026, 1, 1);

  SafetyQueueItem copyWith({SafetyItemStatus? status}) => SafetyQueueItem(
        id: id,
        type: type,
        summary: summary,
        highPriority: highPriority,
        status: status ?? this.status,
        studentName: studentName,
        studentGrade: studentGrade,
        source: source,
        detectedAt: detectedAt,
        detail: detail,
        triggerReason: triggerReason,
      );

  @override
  List<Object?> get props => [id, status];
}
