import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../domain/entities/cms_entities.dart';
import '../../domain/usecases/cms_usecases.dart';
import '../providers/cms_providers.dart';
import 'cms_shared.dart';

/// تب «کدهای استادان» در CMS مدیر (بخش ۲.۲ سند: افزودن استاد فقط توسط
/// Super Admin).
///
/// جریان کامل:
/// ۱. مدیر با نام/تخصص استادِ موردنظر یک کد یک‌بارمصرف `TCH-XXXXXX` می‌سازد
///    و آن را کاپی/ارسال می‌کند.
/// ۲. استاد در صفحهٔ راجستر ← «استاد سمینار» با همان کد حسابش را فعال
///    می‌کند.
/// ۳. وضعیت کد اینجا زنده به‌روز می‌شود.
///
/// رفع اشکال: قبلاً این تب مستقیماً یک انبار محلیِ گوشیِ مدیر
/// (`InstructorInviteStore`) را می‌ساخت و می‌خواند — کاملاً جدا از
/// `/api/v1/admin/invite-codes` واقعی. یعنی هر کدی که مدیر اینجا می‌ساخت،
/// هرگز در جدول واقعی `invite_codes` سرور ثبت نمی‌شد، پس صفحهٔ راجستر
/// استاد (که مستقیماً از همان جدول واقعی می‌خواند) همیشه می‌گفت «کد نامعتبر
/// است». اکنون این تب دقیقاً از همان مسیر واحد و واقعی «کدهای دعوت شاگرد»
/// عبور می‌کند، فقط با `type: 'instructor'`.
class InstructorCodesTab extends ConsumerStatefulWidget {
  const InstructorCodesTab({super.key});

  @override
  ConsumerState<InstructorCodesTab> createState() => _InstructorCodesTabState();
}

class _InstructorCodesTabState extends ConsumerState<InstructorCodesTab> {
  String _query = '';

  Future<void> _showGenerateDialog() async {
    final labelController = TextEditingController();
    final confirmed = await showDialog<bool>(
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
                'کد یک‌بارمصرف است.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('لغو')),
          FilledButton.icon(
            icon: const Icon(Icons.vpn_key_rounded, size: 18),
            label: const Text('ساخت کد'),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(generateInviteCodesUseCaseProvider).call(GenerateInviteCodesParams(
            count: 1,
            batchLabel: labelController.text.trim(),
            type: 'instructor',
          ));
      ref.invalidate(cmsInviteCodesProvider('instructor'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('کد جدید ساخته شد — از فهرست پایین کپی و به استاد بدهید'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final codesAsync = ref.watch(cmsInviteCodesProvider('instructor'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_instructor_codes',
        onPressed: _showGenerateDialog,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('کد استاد جدید'),
      ),
      body: codesAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(cmsInviteCodesProvider('instructor')),
        ),
        data: (allCodes) {
          final codes = allCodes
              .where((c) =>
                  _query.isEmpty ||
                  c.code.contains(_query.toUpperCase()) ||
                  c.batchLabel.contains(_query) ||
                  c.usedByName.contains(_query))
              .toList();
          return Column(
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
                            onRevoke: c.status == 'unused'
                                ? () async {
                                    await ref.read(revokeInviteCodeUseCaseProvider).call(c.id);
                                    ref.invalidate(cmsInviteCodesProvider('instructor'));
                                  }
                                : null,
                          )
                              .animate()
                              .fadeIn(delay: (30 * i).ms, duration: 260.ms)
                              .slideY(begin: 0.08);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InstructorCodeCard extends StatelessWidget {
  final CmsInviteCodeRow invite;
  final VoidCallback onCopy;
  final VoidCallback? onRevoke;
  const _InstructorCodeCard({required this.invite, required this.onCopy, this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (statusLabel, statusColor) = switch (invite.status) {
      'used' => ('استفاده‌شده', AppColors.green600),
      'revoked' => ('باطل‌شده', scheme.error),
      'expired' => ('منقضی', AppColors.ink500),
      _ => ('فعال', AppColors.info),
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
                    if (invite.batchLabel.isNotEmpty)
                      Text(invite.batchLabel,
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
          if (invite.status == 'used' && invite.usedByName.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.green600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text('فعال‌شده توسط: ${invite.usedByName}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ] else if (invite.status == 'unused' && invite.expiresAt != null)
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
