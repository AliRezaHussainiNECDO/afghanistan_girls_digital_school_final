/// Bottom Sheet اکشن‌های مدیریتی — Registry توسعه‌پذیر (اصل ۸ بخش ۱.۲):
/// نیازمندی آیندهٔ مدیر = افزودن یک AdminActionItem جدید به لیست، بدون
/// تغییر در ساختار موجود. هر اکشن با reason در audit_logs سرور ثبت می‌شود.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_entities.dart';
import '../providers/student_management_providers.dart';
import 'common_widgets.dart';

class AdminActionItem {
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool destructive;
  final bool requiresTypedConfirmation;
  final bool enabled;
  final Future<String?> Function(WidgetRef ref, String studentId, String reason)
      execute;

  const AdminActionItem({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.execute,
    this.destructive = false,
    this.requiresTypedConfirmation = false,
    this.enabled = true,
  });
}

List<AdminActionItem> buildAdminActions(StudentDetail detail) {
  final suspended = detail.summary.status == AccountStatus.suspended;
  return [
    AdminActionItem(
      id: 'reset_password',
      label: 'ارسال لینک ریست رمز',
      subtitle: 'لینک بازیابی به ایمیل شاگرد فرستاده می‌شود (رمز نمایش داده نمی‌شود)',
      icon: Icons.lock_reset,
      execute: (ref, id, _) =>
          ref.read(studentActionsProvider.notifier).sendPasswordReset(id),
    ),
    if (!suspended)
      AdminActionItem(
        id: 'suspend',
        label: 'مسدود کردن حساب',
        subtitle: 'شاگرد تا رفع مسدودیت نمی‌تواند وارد شود',
        icon: Icons.block,
        destructive: true,
        execute: (ref, id, reason) =>
            ref.read(studentActionsProvider.notifier).suspend(id, reason),
      )
    else
      AdminActionItem(
        id: 'activate',
        label: 'رفع مسدودیت حساب',
        subtitle: 'حساب دوباره فعال می‌شود',
        icon: Icons.lock_open,
        execute: (ref, id, reason) =>
            ref.read(studentActionsProvider.notifier).activate(id, reason),
      ),
    AdminActionItem(
      id: 'soft_delete',
      label: 'حذف حساب (Soft Delete)',
      subtitle: 'حساب غیرفعال و پنهان می‌شود؛ داده‌ها طبق بخش ۱۵.۲ حفظ می‌ماند',
      icon: Icons.delete_forever,
      destructive: true,
      requiresTypedConfirmation: true,
      execute: (ref, id, reason) =>
          ref.read(studentActionsProvider.notifier).softDelete(id, reason),
    ),
    // ── جای‌گیر برای نیازمندی‌های آینده — فقط آیتم جدید اضافه کنید ──
    // نمونه‌ها: ارسال پیام مستقیم، انتقال صنف (Admin Override بخش ۶)،
    // مشاهدهٔ گفتگوهای AI (بخش ۱۰.۴)، افزودن به صف بازبینی ایمنی (بخش ۱۵.۵)
  ];
}

Future<void> showAdminActionsSheet(
    BuildContext context, WidgetRef ref, StudentDetail detail) {
  final actions = buildAdminActions(detail);
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('اکشن‌های مدیریتی — ${detail.summary.fullName}',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...actions.map((a) => ListTile(
                enabled: a.enabled,
                leading: CircleAvatar(
                  backgroundColor: (a.destructive
                          ? AppPalette.red
                          : AppPalette.green)
                      .withOpacity(.12),
                  child: Icon(a.icon,
                      size: 20,
                      color:
                          a.destructive ? AppPalette.red : AppPalette.greenDark),
                ),
                title: Text(a.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: a.destructive ? AppPalette.red : null)),
                subtitle: Text(a.subtitle, style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmAndRun(context, ref, detail, a);
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}

Future<void> _confirmAndRun(BuildContext context, WidgetRef ref,
    StudentDetail detail, AdminActionItem action) async {
  final reasonCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final name = detail.summary.fullName;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(action.label),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(action.subtitle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'دلیل (در Audit Log ثبت می‌شود)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            if (action.requiresTypedConfirmation) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                decoration: InputDecoration(
                  labelText: 'برای تأیید، نام شاگرد «$name» را بنویسید',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
              style: action.destructive
                  ? FilledButton.styleFrom(backgroundColor: AppPalette.red)
                  : null,
              onPressed: reasonCtrl.text.trim().isNotEmpty &&
                      (!action.requiresTypedConfirmation ||
                          confirmCtrl.text.trim() == name)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('تأیید'),
            ),
          ],
        ),
      ),
    ),
  );

  if (ok != true || !context.mounted) return;

  final error =
      await action.execute(ref, detail.summary.id, reasonCtrl.text.trim());
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error == null ? AppPalette.greenDark : AppPalette.red,
    content: Text(error ?? '«${action.label}» با موفقیت انجام شد'),
  ));

  // پس از حذف، بازگشت به لیست
  if (error == null && action.id == 'soft_delete' && context.mounted) {
    Navigator.of(context).pop();
  }
}
