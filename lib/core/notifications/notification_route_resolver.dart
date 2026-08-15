import '../../app/router/app_routes.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../shared_models/app_notification.dart';

/// منبع واحد حقیقت برای «مقصدِ باز شدن یک اعلان» — بر اساس `kind` +
/// `relatedId` + نقش کاربر (بخش ۱۳.۱ سند).
///
/// این منطق قبلاً فقط داخل `_NotificationsScreenState._routeFor` بود (یعنی
/// فقط وقتی کاربر از داخل لیستِ درون‌اپیِ اعلان‌ها لمس می‌کرد کار می‌کرد).
/// حالا به یک تابع top-level مستقل منتقل شده تا هندلر Push واقعی سیستم‌عامل
/// (`onMessageOpenedApp`/`getInitialMessage` در `push_notifications_service.dart`)
/// هم بتواند از همان قاعدهٔ مسیریابی استفاده کند — رفع اشکال «لمس اعلان
/// Push هیچ‌جا را باز نمی‌کرد».
///
/// اگر مقصد مشخصی نباشد `null` برمی‌گرداند (یعنی فقط اپ باز شود، بدون
/// ناوبری خاص).
///
/// رفع اشکال: قبلاً این تابع فقط `role` می‌گرفت، پس نمی‌توانست بین Super
/// Admin و یک زیرمدیرِ دارای Permission مشخص (`manage_exams`،
/// `manage_safety_chat`، `manage_seminars`، ...) فرق بگذارد — یعنی زیرمدیرِ
/// دارای همان Permission روی لمس اعلانِ مرتبط به‌جایی هدایت نمی‌شد، درحالی‌که
/// از Drawer به همان صفحه دسترسی داشت. حالا `AppUser` کامل گرفته می‌شود و از
/// `user.hasPermission(...)` استفاده می‌شود — دقیقاً همان قاعده‌ای که Drawer
/// و `redirect` روتر (`AppRoutes.adminRoutePermission`) استفاده می‌کنند، تا
/// هر سه‌جا هماهنگ بمانند.
String? resolveNotificationRoute(NotificationKind kind, String? relatedId, AppUser user) {
  final rid = relatedId;
  final role = user.role;
  switch (kind) {
    case NotificationKind.chat:
      if (rid == null) return null;
      return switch (role) {
        AppUserRole.superAdmin || AppUserRole.admin => AppRoutes.adminChatThread(rid),
        AppUserRole.student => AppRoutes.chatThread(rid),
        AppUserRole.parent => AppRoutes.parentContactAdmin,
        AppUserRole.seminarInstructor => AppRoutes.instructorContactAdmin,
      };
    case NotificationKind.exam:
      if (role == AppUserRole.student) return AppRoutes.exams;
      if (user.hasPermission('manage_exams')) return AppRoutes.adminExamsManagement;
      return null;
    case NotificationKind.homework:
      return role == AppUserRole.student ? AppRoutes.homework : null;
    case NotificationKind.seminar:
      return switch (role) {
        AppUserRole.student => AppRoutes.seminars,
        AppUserRole.parent => AppRoutes.parentSeminars,
        AppUserRole.seminarInstructor => AppRoutes.instructorHome,
        AppUserRole.superAdmin || AppUserRole.admin =>
          user.hasPermission('manage_seminars') ? AppRoutes.adminSeminars : null,
      };
    case NotificationKind.safety:
      if (!user.hasPermission('manage_safety_chat')) return null;
      return rid != null ? AppRoutes.adminStudentDetail(rid) : AppRoutes.adminSafetyQueue;
    case NotificationKind.account:
      // مدیریتِ خودِ حساب‌های کاربری («کیست فلان کاربر») هنوز فقط برای
      // Super Admin است — این با `manage_users` یکی نیست (آن دسترسی
      // فهرست/جزئیات را می‌دهد، نه لزوماً تغییرات حساسِ حساب).
      if (role == AppUserRole.superAdmin) {
        final parts = rid?.split(':');
        if (parts != null && parts.length == 2) {
          final (r, userId) = (parts[0], parts[1]);
          return switch (r) {
            'student' => AppRoutes.adminStudentDetail(userId),
            'parent' => AppRoutes.adminParentDetail(userId),
            'seminar_instructor' => AppRoutes.adminInstructorDetail(userId),
            _ => AppRoutes.adminUsers,
          };
        }
        return AppRoutes.adminUsers;
      }
      return role == AppUserRole.student ? AppRoutes.profile : null;
    case NotificationKind.book:
      return role == AppUserRole.student ? AppRoutes.library : null;
    case NotificationKind.grade:
      return switch (role) {
        AppUserRole.parent => AppRoutes.parentScores,
        AppUserRole.student => AppRoutes.exams,
        _ => null,
      };
    case NotificationKind.general:
      return null;
  }
}

/// تبدیل رشتهٔ خام `kind` (که در Payload سرور/`data` پیام FCM می‌آید — مثلاً
/// `"exam"`, `"chat"`) به `NotificationKind`. مقدار ناشناخته/خالی → `general`
/// (بی‌اثر، فقط اپ باز می‌شود).
NotificationKind notificationKindFromString(String? raw) {
  switch (raw) {
    case 'book':
      return NotificationKind.book;
    case 'exam':
      return NotificationKind.exam;
    case 'grade':
      return NotificationKind.grade;
    case 'seminar':
      return NotificationKind.seminar;
    case 'safety':
      return NotificationKind.safety;
    case 'chat':
      return NotificationKind.chat;
    case 'homework':
      return NotificationKind.homework;
    case 'account':
      return NotificationKind.account;
    default:
      return NotificationKind.general;
  }
}
