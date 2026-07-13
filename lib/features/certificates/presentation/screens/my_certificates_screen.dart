import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
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
    final allAsync = ref.watch(allCertificatesProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: parentMode
          ? 'گواهی‌نامه‌های ${studentName ?? 'فرزند'}'
          : 'گواهی‌نامه‌های من',
      role: parentMode ? AppUserRole.parent : AppUserRole.student,
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
        data: (certs) {
          // حالت نمایشی: اگر برای این شناسه گواهی‌ای نبود، همهٔ صادرشده‌ها
          // نشان داده می‌شود (تا بک‌اند واقعی، شناسه‌های Mock متفاوت‌اند).
          var effective = certs;
          var demoFallback = false;
          if (certs.isEmpty) {
            final all = allAsync.valueOrNull ?? [];
            if (all.isNotEmpty) {
              effective = all;
              demoFallback = true;
            }
          }
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
                  const Text('هنوز گواهی‌نامه‌ای صادر نشده',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    'بعد از ختم موفقانهٔ هر صنف، گواهی‌نامهٔ رسمی از طرف مدیر برایت ارسال می‌شود 🌸',
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
              if (demoFallback)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('(حالت نمایشی — همهٔ گواهی‌نامه‌های صادرشده)',
                      style: TextStyle(
                          fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
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
                    Text('گواهی‌نامهٔ اتمام صنف ${c.grade}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      'سال ${c.yearLabel} · میانگین ٪${c.average.toStringAsFixed(0)}${c.honor.isNotEmpty ? ' · ${c.honor}' : ''}',
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
                  Text('مشاهده و دانلود',
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
