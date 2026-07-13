import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/design_tokens.dart';
import 'permission_service.dart';

class _PermItem {
  final Permission permission;
  final IconData icon;
  final String title;
  final String subtitle;
  const _PermItem(this.permission, this.icon, this.title, this.subtitle);
}

const List<_PermItem> _items = [
  _PermItem(Permission.camera, Icons.photo_camera_rounded, 'دوربین', 'برای عکس پروفایل و ارسال عکس تکالیف'),
  _PermItem(Permission.microphone, Icons.mic_rounded, 'میکروفون', 'برای پیام صوتی و شرکت در سمینارها'),
  _PermItem(Permission.photos, Icons.photo_library_rounded, 'گالری تصاویر', 'برای انتخاب و ذخیرهٔ تصاویر و فایل‌ها'),
  _PermItem(Permission.notification, Icons.notifications_active_rounded, 'اعلان‌ها',
      'برای اطلاع از کتاب‌ها، امتحان‌ها و نمرات'),
];

/// بلوک شیت مدرن درخواست دسترسی‌های دستگاه.
class PermissionsSheet extends StatefulWidget {
  const PermissionsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => const PermissionsSheet(),
    );
  }

  /// فقط یک‌بار در اولین اجرا (و فقط روی موبایل) نمایش داده می‌شود.
  static Future<void> maybePrompt(BuildContext context) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('perms_prompted') ?? false) return;
    await prefs.setBool('perms_prompted', true);
    if (!context.mounted) return;
    await show(context);
  }

  @override
  State<PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<PermissionsSheet> {
  final Map<Permission, bool> _granted = {};
  bool _busy = false;

  Future<void> _requestAll() async {
    setState(() => _busy = true);
    final res = await PermissionService.requestCore();
    if (!mounted) return;
    setState(() {
      _granted
        ..clear()
        ..addAll(res);
      _busy = false;
    });
    final allSet = res.values.every((v) => v);
    if (allSet && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                boxShadow: AppShadows.warm,
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('دسترسی‌های برنامه',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('برای استفادهٔ کامل از امکانات، لطفاً به موارد زیر اجازه بده. هر زمان می‌توانی از تنظیمات تغییر بدهی.',
                style: TextStyle(fontSize: 12.5, height: 1.6, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 14),
            ..._items.map((it) {
              final granted = _granted[it.permission] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                      color: granted ? AppColors.green600.withValues(alpha: 0.5) : scheme.outlineVariant),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(it.icon, color: scheme.onPrimaryContainer, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(it.subtitle, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                  if (granted) const Icon(Icons.check_circle_rounded, color: AppColors.green600),
                ]),
              );
            }),
            const SizedBox(height: 4),
            FilledButton.icon(
              onPressed: _busy ? null : _requestAll,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_busy ? 'در حال درخواست…' : 'اجازه دادن'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('بعداً')),
          ],
        ),
      ),
    );
  }
}
