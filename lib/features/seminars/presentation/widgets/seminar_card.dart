import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../shared_models/seminar.dart';
import '../../domain/usecases/seminars_usecases.dart';
import '../providers/seminars_providers.dart';

/// کارت مدرن سمینار — مشترک بین شاگرد و والد.
/// منطق: ثبت‌نام فقط یک‌بار؛ در زمان جلسه دکمهٔ «پیوستن به جلسهٔ زنده».
class SeminarCard extends ConsumerWidget {
  final Seminar seminar;
  final String userId;
  final int index;

  /// Provider ای که بعد از ثبت‌نام باید تازه شود.
  final ProviderOrFamily refreshProvider;

  const SeminarCard({
    super.key,
    required this.seminar,
    required this.userId,
    required this.refreshProvider,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = seminar;
    final registered = s.isRegistered(userId);
    final live = s.isLiveNow;
    final seatsLeft = s.capacity != null ? (s.capacity! - s.registeredCount) : null;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: live ? AppColors.danger.withValues(alpha: 0.55) : scheme.outlineVariant,
          width: live ? 1.4 : 1,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // نوار بالایی گرادیانی
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: live
                    ? const LinearGradient(colors: [Color(0xFFE5484D), Color(0xFFB03038)])
                    : (s.audience == SeminarAudience.parents
                        ? AppColors.successGradient
                        : AppColors.heroGradientWarm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      live ? Icons.videocam_rounded : Icons.groups_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.instructorName,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (live) _LiveBadge(label: context.tr('seminars.live')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (s.description.isNotEmpty) ...[
                    Text(
                      s.description,
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.6),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_month_rounded,
                        label: _formatDate(context, s.scheduledStart),
                      ),
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label:
                            '${_two(s.scheduledStart.hour)}:${_two(s.scheduledStart.minute)} · ${s.durationMinutes} ${context.tr('seminars.minutes')}',
                      ),
                      if (seatsLeft != null)
                        _InfoChip(
                          icon: Icons.event_seat_rounded,
                          label: s.isFull
                              ? context.tr('seminars.full')
                              : context.tr('seminars.capacity', {'count': '$seatsLeft'}),
                          color: s.isFull ? scheme.errorContainer : scheme.tertiaryContainer,
                          textColor:
                              s.isFull ? scheme.onErrorContainer : scheme.onTertiaryContainer,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (registered)
                        Expanded(
                          child: live
                              ? _JoinLiveButton(
                                  onPressed: () => _joinLive(context, s),
                                  label: context.tr('seminars.join'),
                                )
                              : Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.green50,
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                    border: Border.all(
                                        color: AppColors.green500.withValues(alpha: 0.5)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppColors.green600, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.tr('seminars.registered'),
                                        style: const TextStyle(
                                            color: AppColors.green700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _countdownText(context, s),
                                        style: const TextStyle(
                                            color: AppColors.green600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                        )
                      else
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadii.md)),
                            ),
                            onPressed: (!s.isRegistrationOpen)
                                ? null
                                : () => _register(context, ref, s),
                            icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                            label: Text(
                              s.isFull
                                  ? context.tr('seminars.full')
                                  : context.tr('seminars.register'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 350.ms)
        .slideY(begin: 0.12, end: 0, delay: (index * 70).ms, duration: 350.ms, curve: Curves.easeOutCubic);
  }

  Future<void> _register(BuildContext context, WidgetRef ref, Seminar s) async {
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = await ref
        .read(registerSeminarUseCaseProvider)
        .call(RegisterSeminarParams(seminarId: s.id, userId: userId));
    result.fold(
      (f) => messenger.showSnackBar(
        SnackBar(
            content: Text(context.mounted
                ? localizeSeminarFailureMessage(context, f.message)
                : f.message),
            backgroundColor: scheme.error),
      ),
      (_) {
        ref.invalidate(refreshProvider);
        if (context.mounted) CelebrationOverlay.of(context)?.burst();
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(context.mounted
                        ? context.tr('seminars.registerSuccess')
                        : '')),
              ],
            ),
            backgroundColor: scheme.secondary,
          ),
        );
      },
    );
  }

  /// مسیر پیوستن به جلسهٔ زنده — به ترتیب اولویت:
  ///   ۱) پخش زندهٔ Cloudflare Stream (اگر استاد شروع کرده باشد)،
  ///   ۲) لینک جلسهٔ خارجی (Zoom/Meet/Jitsi) در مرورگر،
  ///   ۳) اتاق داخلی سمینار (پیش‌فرض).
  static Future<void> _joinLive(BuildContext context, Seminar s) async {
    // `isLiveNow` هم چک می‌شود (نه فقط `hasLiveStream`) تا اگر سمینار قبلاً
    // یک‌بار پخش زنده داشته و بعداً پایان یافته، کاربر به یک صفحهٔ پخشِ مرده
    // هدایت نشود.
    if (s.hasLiveStream && s.isLiveNow) {
      context.push(AppRoutes.seminarLive(s.id));
      return;
    }
    if (s.hasMeetingLink) {
      final uri = Uri.tryParse(s.meetingLink.trim());
      if (uri != null) {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('seminars.linkOpenFailed'))),
        );
      }
      return;
    }
    context.push(AppRoutes.seminarRoom(s.id));
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatDate(BuildContext context, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return context.tr('seminars.today');
    if (day == today.add(const Duration(days: 1))) return context.tr('seminars.tomorrow');
    return '${d.year}-${_two(d.month)}-${_two(d.day)}';
  }

  static String _countdownText(BuildContext context, Seminar s) {
    final diff = s.scheduledStart.difference(DateTime.now());
    if (diff.isNegative) return '';
    if (diff.inDays >= 1) {
      return context.tr('seminars.startsInDays', {'count': '${diff.inDays}'});
    }
    if (diff.inHours >= 1) {
      return context.tr('seminars.startsInHours', {'count': '${diff.inHours}'});
    }
    return context.tr('seminars.startsInMinutes', {'count': '${diff.inMinutes + 1}'});
  }
}

/// دکمهٔ قرمز تپندهٔ «پیوستن به جلسهٔ زنده».
class _JoinLiveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _JoinLiveButton({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.videocam_rounded, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.03, duration: 700.ms, curve: Curves.easeInOut);
  }
}

class _LiveBadge extends StatelessWidget {
  final String label;
  const _LiveBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 500.ms)
              .then()
              .fadeOut(duration: 500.ms),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final Color? textColor;
  const _InfoChip({required this.icon, required this.label, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor ?? scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: textColor ?? scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
