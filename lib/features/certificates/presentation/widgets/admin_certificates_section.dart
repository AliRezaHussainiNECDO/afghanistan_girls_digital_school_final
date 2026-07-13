import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/user_management/domain/entities/student_entities.dart';
import '../../../admin/user_management/presentation/widgets/common_widgets.dart';
import '../../domain/entities/certificate.dart';
import '../providers/certificates_providers.dart';
import '../screens/certificate_viewer_screen.dart';
import 'certificate_view.dart';

/// بخش «گواهی‌نامه‌ها» در صفحهٔ معلومات شاگرد (پنل مدیر):
/// لیست گواهی‌نامه‌های ارسال‌شده + دکمهٔ «ارسال گواهی‌نامهٔ جدید» با
/// پیش‌نمایش زنده پیش از صدور.
class AdminCertificatesSection extends ConsumerWidget {
  final StudentDetail detail;
  const AdminCertificatesSection({super.key, required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certsAsync =
        ref.watch(certificatesForStudentProvider(detail.summary.id));

    return SectionCard(
      title: 'گواهی‌نامه‌های صادرشده',
      icon: Icons.workspace_premium_rounded,
      trailing: FilledButton.icon(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: AppPalette.greenDark,
        ),
        onPressed: () => _openIssueDialog(context, ref),
        icon: const Icon(Icons.send_rounded, size: 16),
        label: const Text('ارسال گواهی‌نامه', style: TextStyle(fontSize: 12)),
      ),
      child: certsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(),
        ),
        error: (e, _) =>
            Text('خطا: $e', style: const TextStyle(fontSize: 12)),
        data: (certs) => certs.isEmpty
            ? Text(
                'هنوز گواهی‌نامه‌ای برای این شاگرد صادر نشده. بعد از ختم هر صنف، از دکمهٔ بالا ارسال کنید.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600))
            : Column(
                children: [
                  for (final c in certs) _AdminCertRow(certificate: c),
                ],
              ),
      ),
    );
  }

  Future<void> _openIssueDialog(BuildContext context, WidgetRef ref) async {
    var grade = detail.summary.grade;
    final yearCtrl =
        TextEditingController(text: DateTime.now().year.toString());
    final avgCtrl = TextEditingController(
        text: detail.summary.gradeAverage.toStringAsFixed(0));
    var honor = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setState) {
            final preview = Certificate(
              id: 'preview',
              serial: 'AGDS-$grade-XXXXXX',
              studentId: detail.summary.id,
              studentName: detail.summary.fullName,
              grade: grade,
              yearLabel: yearCtrl.text.trim(),
              average: double.tryParse(avgCtrl.text.trim()) ??
                  detail.summary.gradeAverage,
              honor: honor,
              issuedAt: DateTime.now(),
              issuedBy: 'مدیریت مکتب',
            );
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('ارسال گواهی‌نامهٔ اتمام صنف'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // پیش‌نمایش زنده
                      CertificateView(certificate: preview),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: grade,
                              decoration: const InputDecoration(
                                  labelText: 'صنف تکمیل‌شده',
                                  border: OutlineInputBorder()),
                              items: [for (var g = 7; g <= 12; g++) g]
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text('صنف $g')))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => grade = v ?? grade),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: yearCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'سال تعلیمی',
                                  border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: avgCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'میانگین ٪',
                                  border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: honor,
                        decoration: const InputDecoration(
                            labelText: 'لقب افتخاری (اختیاری)',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('— بدون لقب —')),
                          DropdownMenuItem(
                              value: 'با درجهٔ اعلی',
                              child: Text('با درجهٔ اعلی')),
                          DropdownMenuItem(
                              value: 'با درجهٔ بسیار خوب',
                              child: Text('با درجهٔ بسیار خوب')),
                          DropdownMenuItem(
                              value: 'شاگرد ممتاز صنف',
                              child: Text('شاگرد ممتاز صنف')),
                        ],
                        onChanged: (v) => setState(() => honor = v ?? ''),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('انصراف')),
                FilledButton.icon(
                  style:
                      FilledButton.styleFrom(backgroundColor: AppPalette.greenDark),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('صدور و ارسال'),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (confirmed != true) return;
    await ref.read(certificateActionsProvider).issue(IssueCertificateParams(
          studentId: detail.summary.id,
          studentName: detail.summary.fullName,
          grade: grade,
          yearLabel: yearCtrl.text.trim(),
          average: double.tryParse(avgCtrl.text.trim()) ??
              detail.summary.gradeAverage,
          honor: honor,
        ));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppPalette.greenDark,
        behavior: SnackBarBehavior.floating,
        content: Text(
            'گواهی‌نامهٔ صنف $grade برای ${detail.summary.fullName} ارسال شد ✅'),
      ));
    }
  }
}

class _AdminCertRow extends ConsumerWidget {
  final Certificate certificate;
  const _AdminCertRow({required this.certificate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = certificate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFB8860B), Color(0xFFDDB65C)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صنف ${c.grade} — سال ${c.yearLabel}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                Text(
                  '٪${c.average.toStringAsFixed(0)}${c.honor.isNotEmpty ? ' · ${c.honor}' : ''} · ${c.issuedAt.year}/${c.issuedAt.month}/${c.issuedAt.day}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'مشاهده',
            icon: const Icon(Icons.visibility_rounded, size: 20),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CertificateViewerScreen(certificate: c))),
          ),
          IconButton(
            tooltip: 'ابطال گواهی‌نامه',
            icon: Icon(Icons.delete_outline_rounded,
                size: 20, color: Theme.of(context).colorScheme.error),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    title: const Text('ابطال گواهی‌نامه'),
                    content: Text(
                        'گواهی‌نامهٔ صنف ${c.grade} (${c.serial}) باطل شود؟'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('انصراف')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ابطال'),
                      ),
                    ],
                  ),
                ),
              );
              if (ok == true) {
                await ref.read(certificateActionsProvider).revoke(c.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
