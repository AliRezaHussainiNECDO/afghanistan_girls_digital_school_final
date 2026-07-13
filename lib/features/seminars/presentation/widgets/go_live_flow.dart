import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../shared_models/seminar.dart';
import '../../data/services/seminar_live_service.dart';
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
    messenger.showSnackBar(SnackBar(content: Text('خطا در شروع پخش زنده: $e')));
  }
}

/// انتخاب روش پخش: مستقیم از همین اپ (پیشنهادی) یا با نرم‌افزار بیرونی (OBS).
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
          const Text('پخش زنده آماده است',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('چگونه پخش می‌کنید؟',
              style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green500,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SeminarBroadcastScreen(
                      seminarId: seminar.id,
                      seminarTitle: seminar.title,
                      rtmpsUrl: r.rtmpsUrl,
                      streamKey: r.rtmpsKey,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.podcasts_rounded, size: 20),
              label: const Text('پخش مستقیم از همین اپ',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _showIngestSheet(context, r);
              },
              icon: const Icon(Icons.desktop_windows_rounded, size: 18),
              label: const Text('با نرم‌افزار بیرونی (OBS / Larix)'),
            ),
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
              const Expanded(
                child: Text('پخش زنده آماده است',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'این نشانی و کلید را در یک نرم‌افزار پخش (OBS در کامپیوتر یا Larix '
            'Broadcaster در موبایل) وارد کنید. به‌محض شروع، شاگردان/والدین پخش '
            'زنده را در اپ می‌بینند.',
            style: TextStyle(fontSize: 12.5, height: 1.7, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _CopyField(label: 'سرور (RTMPS URL)', value: result.rtmpsUrl),
          const SizedBox(height: 10),
          _CopyField(label: 'کلید پخش (Stream Key)', value: result.rtmpsKey, secret: true),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('باشه، متوجه شدم'),
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
                    const SnackBar(content: Text('کپی شد'), duration: Duration(seconds: 1)),
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
