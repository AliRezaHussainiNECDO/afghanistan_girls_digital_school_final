import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/instructor/instructor_invite_store.dart';
import 'cms_shared.dart';

/// انبار کدهای استادان به‌صورت Provider — با هر تغییر (ساخت/ابطال/مصرف کد
/// هنگام ثبت‌نام استاد) لیست مدیر بلافاصله بازسازی می‌شود.
final instructorInviteStoreProvider =
    ChangeNotifierProvider<InstructorInviteStore>((ref) => InstructorInviteStore.instance);

/// تب «کدهای استادان» در CMS مدیر (بخش ۲.۲ سند: افزودن استاد فقط توسط
/// Super Admin).
///
/// جریان کامل:
/// ۱. مدیر با نام/تخصص استادِ موردنظر یک کد یک‌بارمصرف `TCH-XXXXXX`
///    (اعتبار ۱۴ روز) می‌سازد و آن را کاپی/ارسال می‌کند.
/// ۲. استاد در صفحهٔ راجستر ← «استاد سمینار» با همان کد حسابش را فعال
///    می‌کند.
/// ۳. وضعیت کد اینجا زنده به‌روز می‌شود: استفاده‌نشده → استفاده‌شده (با نام،
///    ایمیل و تخصص واقعی استاد) — قابلیت بازبینی کامل برای مدیر.
class InstructorCodesTab extends ConsumerStatefulWidget {
  const InstructorCodesTab({super.key});

  @override
  ConsumerState<InstructorCodesTab> createState() => _InstructorCodesTabState();
}

class _InstructorCodesTabState extends ConsumerState<InstructorCodesTab> {
  String _query = '';

  Future<void> _showGenerateDialog() async {
    final labelController = TextEditingController();
    final created = await showDialog<InstructorInviteCode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('کد دعوت استاد جدید'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'برای چه کسی؟ (نام استاد / تخصص)',
                hintText: 'مثلاً: استاد نادری — مهارت‌های زندگی',
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'کد یک‌بارمصرف است و ۱۴ روز اعتبار دارد.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لغو')),
          FilledButton.icon(
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: const Text('ساخت کد'),
            onPressed: () {
              final invite = InstructorInviteStore.instance
                  .issueCode(label: labelController.text.trim());
              Navigator.pop(dialogContext, invite);
            },
          ),
        ],
      ),
    );
    if (created != null && mounted) {
      // کد تازه‌ساخته بلافاصله برای ارسال به استاد کاپی می‌شود.
      await Clipboard.setData(ClipboardData(text: created.code));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('کد «${created.code}» ساخته و کاپی شد — آن را به استاد بدهید'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(instructorInviteStoreProvider);
    final codes = store.codes
        .where((c) =>
            _query.isEmpty ||
            c.code.contains(_query.toUpperCase()) ||
            c.label.contains(_query) ||
            c.usedByName.contains(_query))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_instructor_codes',
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('کد استاد جدید'),
      ),
      body: Column(
        children: [
          CmsSearchBar(onChanged: (v) => setState(() => _query = v.trim())),
          Expanded(
            child: codes.isEmpty
                ? const CmsEmptyView()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    itemCount: codes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = codes[i];
                      return _InstructorCodeCard(
                        invite: c,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: c.code));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('«${c.code}» کاپی شد'),
                            behavior: SnackBarBehavior.floating,
                          ));
                        },
                        onRevoke: c.status == InstructorCodeStatus.unused
                            ? () => InstructorInviteStore.instance.revoke(c.id)
                            : null,
                      )
                          .animate()
                          .fadeIn(delay: (30 * i).ms, duration: 260.ms)
                          .slideY(begin: 0.08);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InstructorCodeCard extends StatelessWidget {
  final InstructorInviteCode invite;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;
  const _InstructorCodeCard({required this.invite, required this.onCopy, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (invite.status) {
      InstructorCodeStatus.used => ('استفاده‌شده', AppColors.green600),
      InstructorCodeStatus.revoked => ('باطل‌شده', scheme.error),
      InstructorCodeStatus.unused =>
        invite.expired ? ('منقضی', AppColors.ink500) : ('فعال', AppColors.info),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradientWarm,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.co_present_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invite.code,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
                    if (invite.label.isNotEmpty)
                      Text(invite.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── جزئیات: چه کسی استفاده کرد / چند روز اعتبار مانده ──
          if (invite.status == InstructorCodeStatus.used) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.green600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('فعال‌شده توسط: ${invite.usedByName}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${invite.usedByEmail}${invite.usedSpecialty.isEmpty ? '' : ' · تخصص: ${invite.usedSpecialty}'}',
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ] else if (invite.status == InstructorCodeStatus.unused && !invite.expired)
            Text('اعتبار: ${invite.remainingDays} روز دیگر',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('کاپی'),
              ),
              if (onRevoke != null)
                TextButton.icon(
                  onPressed: onRevoke,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('ابطال'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
