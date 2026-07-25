import 'package:flutter/material.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../audit_logs/domain/entities/audit_log_entry.dart';

/// برچسب/آیکون/رنگ هر نوع رویداد لاگ بازبینی — منبع مشترک بین «مرکز عملیات
/// و لاگ بازبینی»، «پروندهٔ مدیر» و ویجت «فعالیت اخیر من» در داشبورد، تا
/// نگاشت هر actionType فقط یک‌جا نگهداری شود.
String activityActionLabel(BuildContext context, String t) {
  switch (t) {
    case 'ai_invocation':
      return context.tr('auditLogs.actionAiInvocation');
    case 'login_success':
      return context.tr('auditLogs.actionLoginSuccess');
    case 'login_failed':
      return context.tr('auditLogs.actionLoginFailed');
    case 'login_blocked':
      return context.tr('auditLogs.actionLoginBlocked');
    case 'logout':
      return context.tr('auditLogs.actionLogout');
    case 'user_register':
      return context.tr('auditLogs.actionUserRegister');
    case 'user_status_change':
      return context.tr('auditLogs.actionUserStatusChange');
    case 'invite_code_issue':
      return context.tr('auditLogs.actionInviteCodeIssue');
    case 'invite_code_revoke':
      return context.tr('auditLogs.actionInviteCodeRevoke');
    case 'password_reset_link':
      return context.tr('auditLogs.actionPasswordResetLink');
    case 'content_status_change':
      return context.tr('auditLogs.actionContentStatusChange');
    case 'content_delete':
      return context.tr('auditLogs.actionContentDelete');
    case 'curriculum_wipe':
      return context.tr('auditLogs.actionCurriculumWipe');
    case 'safety_resolve':
      return context.tr('auditLogs.actionSafetyResolve');
    case 'parent_link_request':
      return context.tr('auditLogs.actionParentLinkRequest');
    case 'parent_link_decision':
      return context.tr('auditLogs.actionParentLinkDecision');
    case 'certificate_issue':
      return context.tr('auditLogs.actionCertificateIssue');
    case 'certificate_revoke':
      return context.tr('auditLogs.actionCertificateRevoke');
    case 'exam_delete':
      return context.tr('auditLogs.actionExamDelete');
    case 'admin_create':
      return context.tr('admin.activityAdminCreate');
    case 'admin_permissions_update':
      return context.tr('admin.activityPermissionsUpdate');
    case 'admin_status_change':
      return context.tr('admin.activityAdminStatusChange');
    default:
      return t;
  }
}

IconData activityActionIcon(String t) {
  switch (t) {
    case 'ai_invocation':
      return Icons.smart_toy_rounded;
    case 'login_success':
      return Icons.login_rounded;
    case 'login_failed':
    case 'login_blocked':
      return Icons.gpp_bad_rounded;
    case 'logout':
      return Icons.logout_rounded;
    case 'user_register':
      return Icons.person_add_alt_1_rounded;
    case 'user_status_change':
    case 'admin_status_change':
      return Icons.manage_accounts_rounded;
    case 'invite_code_issue':
    case 'invite_code_revoke':
      return Icons.qr_code_2_rounded;
    case 'password_reset_link':
      return Icons.lock_reset_rounded;
    case 'content_status_change':
      return Icons.publish_rounded;
    case 'content_delete':
      return Icons.delete_forever_rounded;
    case 'curriculum_wipe':
      return Icons.local_fire_department_rounded;
    case 'safety_resolve':
      return Icons.shield_rounded;
    case 'parent_link_request':
    case 'parent_link_decision':
      return Icons.family_restroom_rounded;
    case 'certificate_issue':
      return Icons.workspace_premium_rounded;
    case 'certificate_revoke':
      return Icons.remove_moderator_rounded;
    case 'exam_delete':
      return Icons.delete_sweep_rounded;
    case 'admin_create':
      return Icons.person_add_alt_1_rounded;
    case 'admin_permissions_update':
      return Icons.tune_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

Color activityActionColor(AuditLogEntry e) {
  if (e.isHighPriority || e.category == AuditCategory.security) return AppColors.danger;
  if (e.category == AuditCategory.sensitive) return AppColors.gold600;
  return AppColors.green600;
}
