import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared_models/seminar.dart';
import '../../data/services/seminar_live_service.dart';
import '../../domain/usecases/seminars_usecases.dart';
import '../providers/seminars_providers.dart';
import '../screens/seminar_broadcast_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// جریان مشترک «شروع پخش زنده» — استفادهٔ مجدد در پنل استاد و مدیر.
///
/// ۱) go-live روی Cloudflare Stream را صدا می‌زند،
/// ۲) [onWentLive] را برای تازه‌سازی فهرست اجرا می‌کند،
/// ۳) شیت انتخاب روش پخش (درون‌اپ / OBS) را نشان می‌دهد،
/// ۴) اگر Stream پیکربندی نشده باشد، به اتاق داخلی برمی‌گردد (fail-safe).
/// ═══════════════════════════════════════════════════════════════════════════
Future<void> startSeminarLive(
  BuildContext context,
  WidgetRef ref,
  Seminar seminar, {
  VoidCallback? onWentLive,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  // رفع اشکال هماهنگی: اگر استاد از قبل یک لینک جلسهٔ خارجی (Zoom/Meet/
  // Jitsi خودش) برای این سمینار ثبت کرده، یعنی میزبانی را خودش بیرون از اپ
  // انجام می‌دهد. قبلاً در این حالت هم دکمهٔ «شروع سمینار» یک پخش زندهٔ
  // Cloudflare Stream خالی می‌ساخت (که کسی در آن پخش نمی‌کرد) و کارت
  // شاگرد/والد را به‌جای بازکردنِ لینک واقعی، به همان پخشِ بی‌محتوا هدایت
  // می‌کرد (چون `hasLiveStream` روی true می‌رفت). حالا در این حالت فقط
  // وضعیت روی سرور «زنده» می‌شود و لینک واقعی برای خودِ استاد هم باز می‌شود.
  if (seminar.hasMeetingLink) {
    final result = await ref
        .read(setSeminarStatusUseCaseProvider)
        .call(SetSeminarStatusParams(seminarId: seminar.id, status: SeminarStatus.live));
    result.fold(
      (f) => messenger.showSnackBar(
          SnackBar(content: Text(localizeSeminarFailureMessage(context, f.message)))),
      (_) {
        onWentLive?.call();
        messenger.showSnackBar(SnackBar(
          content: Text(context.tr('liveStream.announcedOpeningLink')),
        ));
        final uri = Uri.tryParse(seminar.meetingLink.trim());
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: AppColors.green500),
    ),
  );
  try {
    final result = await ref.read(seminarLiveServiceProvider).goLive(seminar.id);
    if (context.mounted) Navigator.of(context).pop(); // بستن لودینگ
    onWentLive?.call();
    if (context.mounted) {
      await _showLiveChoice(context, seminar, result);
    }
  } on LiveStreamException catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (e.isNotConfigured) {
      if (context.mounted) context.push(AppRoutes.seminarRoom(seminar.id));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(context.tr('liveStream.startError', {'error': '$e'}))));
    }
  }
}

/// انتخاب روش پخش.
///
/// رفع ریشه‌ای اشکال «استاد هنگام شروع سمینار از برنامه خارج می‌شود»: تحقیق
/// روی ردیاب مشکلات پکیج `apivideo_live_stream` (که مسیر «پخش مستقیم از
/// همین اپ» از آن استفاده می‌کند) نشان داد این یک Crash بومی (SIGSEGV در
/// libssl هنگام اتصال RTMPS) روی برخی دستگاه‌ها/نسخه‌های اندروید است که خودِ
/// سازندهٔ پکیج هم تأیید کرده در سطح کتابخانه رفع‌شدنی نیست (Issue #29:
/// «I don't see anything to fix the issue you face»). چون این خرابی در کد
/// بومی رخ می‌دهد، هیچ try/catch یا `runZonedGuarded` سمت Dart نمی‌تواند
/// جلویش را بگیرد — پس تنها راه واقعیِ حذف ریشهٔ مشکل این است که این مسیر
/// خطرناک دیگر به‌طور پیش‌فرض به استاد پیشنهاد نشود.
///
/// به همین دلیل ترتیب/برجستگی گزینه‌ها این‌جا عمداً برعکس نسخهٔ قبلی است:
/// «نرم‌افزار بیرونی (OBS/Larix)» — که هرگز کد بومی این پکیج را صدا نمی‌زند و
/// در عمل هیچ‌گاه این‌طور Crash نکرده — حالا گزینهٔ سبز/پیشنهادی است. «پخش
/// مستقیم از اپ» به گزینهٔ دوم با برچسب «تجربی» و هشدار صریح تبدیل شده. محافظ
/// Crash در `SeminarBroadcastScreen` هم به‌عنوان لایهٔ دفاعی دوم برای کسی که
/// همچنان مسیر تجربی را انتخاب کند، فعال می‌ماند.
Future<void> _showLiveChoice(BuildContext context, Seminar seminar, GoLiveResult r) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(context.tr('liveStream.readyTitle'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(context.tr('liveStream.howToBroadcast'),
              style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          // گزینهٔ پیشنهادی/پیش‌فرض تازه: نرم‌افزار بیرونی (OBS/Larix) — کد
          // بومی پرتصادف apivideo_live_stream را اصلاً صدا نمی‌زند.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green500,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showIngestSheet(context, r);
              },
              icon: const Icon(Icons.desktop_windows_rounded, size: 20),
              label: Text(context.tr('liveStream.broadcastExternal'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(context.tr('liveStream.recommendedBadge'),
                style: const TextStyle(fontSize: 11, color: AppColors.green500, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                // اگر دفعهٔ قبل ورود به این صفحه با Crash بومی تمام شده باشد،
                // صفحه به‌جای باز کردن دوباره‌، `true` برمی‌گرداند تا این‌جا
                // مستقیم شیت «پخش با نرم‌افزار خارجی» باز شود (لایهٔ دفاعی دوم).
                final preferExternal = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => SeminarBroadcastScreen(
                      seminarId: seminar.id,
                      seminarTitle: seminar.title,
                      rtmpsUrl: r.rtmpsUrl,
                      streamKey: r.rtmpsKey,
                    ),
                  ),
                );
                if (preferExternal == true && context.mounted) {
                  _showIngestSheet(context, r);
                }
              },
              icon: const Icon(Icons.podcasts_rounded, size: 18),
              label: Text(context.tr('liveStream.broadcastFromApp')),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(context.tr('liveStream.inAppRiskWarning'),
                style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant, height: 1.5)),
          ),
        ],
      ),
    ),
  );
}

/// شیت اطلاعات پخش برای پخش با نرم‌افزار بیرونی — نشانی RTMPS و کلید.
Future<void> _showIngestSheet(BuildContext context, GoLiveResult r) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _IngestSheet(result: r),
  );
}

class _IngestSheet extends StatelessWidget {
  final GoLiveResult result;
  const _IngestSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sensors_rounded, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.tr('liveStream.readyTitle'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('liveStream.ingestInstructions'),
            style: TextStyle(fontSize: 12.5, height: 1.7, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _CopyField(label: context.tr('liveStream.serverUrlLabel'), value: result.rtmpsUrl),
          const SizedBox(height: 10),
          _CopyField(label: context.tr('liveStream.streamKeyLabel'), value: result.rtmpsKey, secret: true),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('liveStream.gotIt')),
            ),
          ),
        ],
      ),
    );
  }
}

/// فیلد فقط‌خواندنی با دکمهٔ «کپی».
class _CopyField extends StatefulWidget {
  final String label;
  final String value;
  final bool secret;
  const _CopyField({required this.label, required this.value, this.secret = false});

  @override
  State<_CopyField> createState() => _CopyFieldState();
}

class _CopyFieldState extends State<_CopyField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = widget.secret && !_revealed
        ? '•' * (widget.value.isEmpty ? 8 : widget.value.length.clamp(6, 24))
        : widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shown.isEmpty ? '—' : shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace'),
                ),
              ),
              if (widget.secret)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 18),
                  onPressed: () => setState(() => _revealed = !_revealed),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('common.copied')), duration: const Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
