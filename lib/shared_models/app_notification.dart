import 'package:equatable/equatable.dart';

/// اعلان — طبق جدول `notifications` بخش ۱۷.۶ سند.
enum NotificationPriority { low, medium, high }

/// نوع رویداد اعلان — برای انتخاب آیکن/رنگ متناسب در UI و همچنین تعیین
/// مقصد باز شدن هنگام لمس (بخش «رفع اشکال بازشدن اعلان» — پایین).
///
/// رفع اشکال: `homework` و `account` قبلاً هر دو زیر یک `general` مشترک
/// ثبت می‌شدند و از هم قابل‌تشخیص نبودند — یعنی سمت کلاینت هیچ راهی نداشت
/// بفهمد لمس یک اعلان «general» باید صفحهٔ کار خانگی را باز کند یا پروفایل
/// (برای تأیید درخواست پیوند والد) را. حالا هرکدام kind اختصاصی خودشان را
/// دارند.
enum NotificationKind { book, exam, grade, seminar, safety, general, chat, homework, account }

class AppNotification extends Equatable {
  final String id;
  final String titleFa;
  final String bodyFa;
  final NotificationPriority priority;
  final DateTime createdAt;
  final bool read;
  final NotificationKind kind;

  /// شناسهٔ رکورد مرتبط (مثلاً examId، conversationId، seminarId، یا برای
  /// اعلان‌های kind='account' به مدیر: `"role:userId"`) — برای هدایت مستقیم
  /// به همان محتوا هنگام لمس اعلان. ممکن است null باشد (مثلاً اعلان‌های
  /// عمومی که مقصد مشخصی ندارند).
  final String? relatedId;

  const AppNotification({
    required this.id,
    required this.titleFa,
    required this.bodyFa,
    required this.priority,
    required this.createdAt,
    this.read = false,
    this.kind = NotificationKind.general,
    this.relatedId,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        titleFa: titleFa,
        bodyFa: bodyFa,
        priority: priority,
        createdAt: createdAt,
        read: read ?? this.read,
        kind: kind,
        relatedId: relatedId,
      );

  @override
  List<Object?> get props => [id, read];
}
