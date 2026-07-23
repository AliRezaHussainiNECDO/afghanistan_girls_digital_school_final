import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/certificate.dart';
import '../providers/certificates_providers.dart';
import 'certificate_viewer_screen.dart';

/// لیست گواهی‌نامه‌ها — هم برای شاگرد («گواهی‌نامه‌های من») و هم برای والدین
/// (گواهی‌نامه‌های فرزند). هر کارت با پیش‌نمایش کوچک؛ لمس → نمایش کامل و دانلود.
class MyCertificatesScreen extends ConsumerWidget {
  /// اگر null باشد، گواهی‌نامه‌های کاربرِ واردشده نمایش داده می‌شود.
  final String? studentId;
  final String? studentName;
  final bool parentMode;

  const MyCertificatesScreen({
    super.key,
    this.studentId,
    this.studentName,
    this.parentMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final effectiveId = studentId ?? user?.id ?? '';
    final certsAsync = ref.watch(certificatesForStudentProvider(effectiveId));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: parentMode
          ? context.tr('certificates.forChild', {'name': studentName ?? context.tr('certificates.childFallback')})
          : context.tr('dashboard.myCertificates'),
      role: parentMode ? AppUserRole.parent : AppUserRole.student,
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // رفع اشکال: قبلاً خطا فقط یک متن ثابت بود (بدون تلاش مجدد)، و علاوه
        // بر آن، وقتی فهرست این شناسه خالی بود، صفحه یک بار دیگر همان
        // Endpoint خودِ کاربر را (`allCertificatesProvider`) صدا می‌زد —
        // دقیقاً همان `/students/me/certificates` که `certificatesForStudentProvider`
        // هم می‌زند؛ یعنی درخواست دوبرابری بی‌فایده برای یک نتیجهٔ همیشه یکسان
        // (نه واقعاً «همهٔ صادرشده‌ها»، چون بک‌اند چنین حالتی برای این مسیر
        // ندارد). این «فال‌بک نمایشی» حذف شد.
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(certificatesForStudentProvider(effectiveId)),
        ),
        data: (certs) {
          final effective = certs;
          if (effective.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.workspace_premium_rounded,
                        size: 46, color: scheme.outline),
                  ),
                  const SizedBox(height: 16),
                  Text(context.tr('certificates.noneYetTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('certificates.noneYetBody'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final cert in effective) ...[
                _CertificateCard(certificate: cert),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Certificate certificate;
  const _CertificateCard({required this.certificate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = certificate;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CertificateViewerScreen(certificate: c))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              // نشان طلایی
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFB8860B), Color(0xFFDDB65C)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFB8860B).withValues(alpha: .35),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('certificates.gradeCompletionTitle', {'grade': '${c.grade}'}),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('certificates.yearAverageLine', {
                        'year': c.yearLabel,
                        'average': c.average.toStringAsFixed(0),
                        'honor': c.honor.isNotEmpty ? ' · ${c.honor}' : '',
                      }),
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(c.serial,
                        style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant
                                .withValues(alpha: .7))),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(Icons.visibility_rounded,
                      size: 20, color: scheme.primary),
                  const SizedBox(height: 4),
                  Text(context.tr('certificates.viewAndDownload'),
                      style: TextStyle(
                          fontSize: 9.5, color: scheme.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
