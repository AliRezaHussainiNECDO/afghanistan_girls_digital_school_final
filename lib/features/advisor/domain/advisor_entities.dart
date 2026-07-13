import 'package:equatable/equatable.dart';

/// فرستندهٔ پیام در گفتگوی «مشاور هوشمند».
enum AdvisorRole { student, advisor }

/// یک پیام در گفتگوی مشاوره.
class AdvisorMessage extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final AdvisorRole role;
  final String text;
  final DateTime createdAt;

  /// آیا این پیام نشانهٔ نگرانی/حساسیت دارد و باید توجه مدیر را جلب کند؟
  final bool flagged;

  /// برچسب موضوع (روانی/اجتماعی/خانوادگی/تحصیلی/روزمره/عمومی).
  final String topic;

  const AdvisorMessage({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.role,
    required this.text,
    required this.createdAt,
    this.flagged = false,
    this.topic = 'عمومی',
  });

  @override
  List<Object?> get props => [id];
}

/// خلاصهٔ گفتگوی یک شاگرد (برای فهرست مدیر).
class AdvisorThreadSummary extends Equatable {
  final String studentId;
  final String studentName;
  final int messageCount;
  final DateTime lastAt;
  final bool hasFlag;

  const AdvisorThreadSummary({
    required this.studentId,
    required this.studentName,
    required this.messageCount,
    required this.lastAt,
    required this.hasFlag,
  });

  @override
  List<Object?> get props => [studentId, messageCount, lastAt, hasFlag];
}
