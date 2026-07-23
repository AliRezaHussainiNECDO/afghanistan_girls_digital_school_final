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

/// دامنهٔ مقصدِ اعلان — منبع واحد حقیقت برای «منطق هدف‌گیری اعلان‌ها»:
///
/// • [private] — فقط دقیقاً همان کاربری که رکورد سرور برایش ساخته شده حق
///   دیدن دارد؛ هرگز نباید Broadcast شود یا بین حساب‌های مختلف روی یک
///   دستگاه/نشست ادغام (merge) گردد. نمونه‌ها: نمره، پیام/چت خصوصی با
///   مشاور یا مدیر، اعلان حساب (پیوند والد، تأیید ایمیل)، کار خانگی
///   اختصاصیِ یک شاگرد.
/// • [targetedRole] — به همهٔ کاربرانِ یک نقش/گروه مشخص (مثلاً همهٔ
///   شاگردان یا همهٔ والدین) با Fan-out ارسال می‌شود: سرور برای هر گیرنده
///   یک ردیف مستقل در جدول `notifications` می‌سازد (نه یک ردیف مشترک).
///   نمونه: اعلان سمینار تازه، انتشار کتاب/امتحان تازه.
/// • [broadcastSchool] — کل مکتب؛ فعلاً در پایگاه‌داده پیاده نشده، برای
///   اعلان‌های عمومیِ آیندهٔ مدیریت در نظر گرفته شده.
enum NotificationScope { private, targetedRole, broadcastSchool }

extension NotificationKindScope on NotificationKind {
  /// نگاشت هر نوع اعلان به دامنهٔ مجازش — به‌جای پراکنده بودنِ این تصمیم در
  /// هر صفحه/فیچر، همین‌جا یک‌بار و به‌طور صریح تعریف شده است.
  NotificationScope get scope {
    switch (this) {
      case NotificationKind.grade:
      case NotificationKind.chat:
      case NotificationKind.account:
      case NotificationKind.homework:
        return NotificationScope.private;
      case NotificationKind.seminar:
      case NotificationKind.book:
      case NotificationKind.exam:
      case NotificationKind.safety:
      case NotificationKind.general:
        return NotificationScope.targetedRole;
    }
  }

  /// اعلان‌های «حساس» — دادهٔ خصوصی/شخصی دارند — که هرگز نباید در کش محلیِ
  /// مشترک یا merge بین حساب‌ها باقی بمانند (رجوع کنید به
  /// `NotificationCenter.setOwner` که این قاعده را عملاً تضمین می‌کند).
  bool get isSensitive =>
      scope == NotificationScope.private &&
      (this == NotificationKind.grade ||
          this == NotificationKind.chat ||
          this == NotificationKind.account);
}

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
