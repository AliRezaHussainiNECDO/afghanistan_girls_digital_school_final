import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
// نکته: فقط `seminarRegistrationsProvider` از این فایل import می‌شود — هم
// این فایل و هم `instructor_providers.dart` یک Provider هم‌نام دیگر
// (`setSeminarStatusUseCaseProvider`) با پارامترهای متفاوت دارند؛ `show`
// عمدی از برخورد نام هنگام کامپایل جلوگیری می‌کند.
import '../../../seminars/presentation/providers/seminars_providers.dart'
    show seminarRegistrationsProvider;
import '../../../seminars/presentation/widgets/go_live_flow.dart';
import '../../../seminars/presentation/widgets/seminar_editor_dialog.dart';
import '../../domain/usecases/instructor_usecases.dart';
import '../providers/instructor_providers.dart';

/// پنل استاد سمینار — «داشبورد استاد»:
///   • هدر قهرمان با نام استاد + شمار زندهٔ سمینارهایش (یا پیام «همین حالا
///     زنده!» وقتی یکی از سمینارهایش در حال پخش است)
///   • نوار آمار (مجموع/پیش‌رو/زنده/ثبت‌نام‌ها/پایان‌یافته)
///   • کارت درخشان «سمینار بعدی شما» با دکمهٔ مستقیم شروع/پیوستن
///   • دسترسی سریع به بخش‌های دیگر (حافظهٔ جمعی، تماس با مدیر، اعلان‌ها، پروفایل)
///   • فهرست کامل سمینارها با ساخت/ویرایش/حذف/شروع پخش زنده
/// هر ۳۰ ثانیه بی‌صدا بازسازی می‌شود (بدون فراخوانی سرور) تا شمارش معکوس و
/// وضعیت «زنده‌شدن» خودکار سمینارها همیشه به‌روز بمانند — طبق درخواست کاربر:
/// داشبورد باید «خیلی پویا» باشد.
class InstructorHomeScreen extends ConsumerStatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  ConsumerState<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends ConsumerState<InstructorHomeScreen> {
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seminarsAsync = ref.watch(myInstructorSeminarsProvider);
    final instructor = ref.watch(authSessionProvider);
    final scheme = Theme.of(context).colorScheme;

    // نام واقعی استادِ واردشده برای سربرگ خوش‌آمدگویی — هماهنگ با همان
    // الگوی داشبورد شاگرد/والد/مدیر (نه یک متن ثابت).
    final instructorName = (instructor?.firstName.trim().isNotEmpty ?? false)
        ? instructor!.firstName.trim()
        : ((instructor?.displayName.trim().isNotEmpty ?? false)
            ? instructor!.displayName.trim()
            : '');

    return AppScaffold(
      title: context.tr('instructor.mySeminars'),
      role: AppUserRole.seminarInstructor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSeminar(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('instructor.createSeminar')),
      ),
      body: Column(
        children: [
          // بنر تأیید ایمیل — تا زمانی که استاد ایمیلش را تأیید نکرده.
          const EmailVerificationBanner(),
          Expanded(
            child: seminarsAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(myInstructorSeminarsProvider),
              ),
              data: (seminars) {
                final stats = _InstructorStats.from(seminars);
                final spotlight = _pickSpotlightSeminar(seminars);
                // تفکیک «در انتظار» از «آرشیف» — رجوع کنید به توضیح بالا.
                final pendingSeminars = seminars.where((s) => !s.isArchived).toList();
                final archivedSeminars = seminars.where((s) => s.isArchived).toList()
                  ..sort((a, b) => (b.archivedAt ?? b.scheduledStart)
                      .compareTo(a.archivedAt ?? a.scheduledStart));
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myInstructorSeminarsProvider),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      _InstructorHeroHeader(name: instructorName, stats: stats),
                      const SizedBox(height: 18),
                      _InstructorStatsStrip(stats: stats),
                      const SizedBox(height: 16),
                      if (spotlight != null) ...[
                        _NextSeminarSpotlight(
                          seminar: spotlight,
                          onStart: () => _startLive(context, spotlight),
                        ).animate().fadeIn(duration: 320.ms).slideY(
                            begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 18),
                      ],
                      Row(
                        children: [
                          Icon(Icons.apps_rounded, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(context.tr('dashboard.mainSections'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _InstructorQuickSectionsGrid()
                          .animate()
                          .fadeIn(delay: 60.ms, duration: 400.ms)
                          .slideY(begin: 0.10, end: 0, delay: 60.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                      const SizedBox(height: 20),
                      Text(context.tr('instructor.pendingSeminars'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 10),
                      if (pendingSeminars.isEmpty) ...[
                        const SizedBox(height: 8),
                        EmptyView(
                          message: context.tr('instructor.noSeminars'),
                          icon: Icons.groups_outlined,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 240,
                            child: AppPrimaryButton(
                              label: context.tr('instructor.createSeminar'),
                              icon: Icons.add_rounded,
                              onPressed: () => _createSeminar(context),
                            ),
                          ),
                        ),
                      ] else
                        for (var i = 0; i < pendingSeminars.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _InstructorSeminarCard(seminar: pendingSeminars[i], index: i),
                        ],
                      // ── آرشیف: رفع اشکال «سمینارها هیچ‌وقت آرشیف نمی‌شوند» —
                      // سمینارهایی که سرور خودکار به `archived` منتقل کرده
                      // (به‌همراه گزارش هوش مصنوعی) این‌جا جدا از فهرست
                      // «در انتظار» بالا نمایش داده می‌شوند تا آن فهرست با
                      // گذشت زمان شلوغ/گمراه‌کننده نشود.
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, size: 18, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(context.tr('instructor.archivedSeminars'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (archivedSeminars.isEmpty)
                        EmptyView(
                          message: context.tr('instructor.noArchivedSeminars'),
                          icon: Icons.inventory_2_outlined,
                        )
                      else
                        for (var i = 0; i < archivedSeminars.length; i++) ...[
                          if (i > 0) const SizedBox(height: 14),
                          _ArchivedSeminarCard(seminar: archivedSeminars[i], index: i),
                        ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSeminar(BuildContext context) async {
    final user = ref.read(authSessionProvider);
    if (user == null) return;
    final result = await showSeminarEditorDialog(context);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final created = await ref.read(createSeminarUseCaseProvider).call(
          CreateSeminarParams(
            instructorId: user.id,
            instructorName: user.displayName,
            title: result.title,
            description: result.description,
            scheduledStart: result.scheduledStart,
            durationMinutes: result.durationMinutes,
            capacity: result.capacity,
            audience: result.audience,
            meetingLink: result.meetingLink,
          ),
        );
    created.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(
          SnackBar(content: Text(context.mounted ? context.tr('instructor.created') : '')),
        );
      },
    );
  }

  /// شروع/میزبانی پخش زنده از کارت درخشان «سمینار بعدی شما».
  Future<void> _startLive(BuildContext context, Seminar seminar) {
    return startSeminarLive(context, ref, seminar,
        onWentLive: () => ref.invalidate(myInstructorSeminarsProvider));
  }
}

/// آمار خلاصهٔ محاسبه‌شده از فهرست سمینارهای استاد — سرور آمار جداگانه‌ای
/// برای این پنل ندارد، پس همه چیز از همان دادهٔ سمینارها که در دست است
/// محاسبه می‌شود (بدون فراخوانی اضافی به سرور).
class _InstructorStats {
  final int total;
  final int upcoming;
  final int live;
  final int ended;
  final int totalRegistrations;

  const _InstructorStats({
    required this.total,
    required this.upcoming,
    required this.live,
    required this.ended,
    required this.totalRegistrations,
  });

  factory _InstructorStats.from(List<Seminar> seminars) {
    var upcoming = 0, live = 0, ended = 0, regs = 0;
    for (final s in seminars) {
      regs += s.registeredCount;
      if (s.isLiveNow) {
        live++;
      } else if (s.hasEnded) {
        ended++;
      } else if (s.status != SeminarStatus.draft) {
        upcoming++;
      }
    }
    return _InstructorStats(
      total: seminars.length,
      upcoming: upcoming,
      live: live,
      ended: ended,
      totalRegistrations: regs,
    );
  }
}

/// نزدیک‌ترین سمیناری که هنوز پایان نیافته — سمینارهای زنده همیشه اولویت
/// دارند؛ در غیر آن صورت زودترین سمینار پیش‌رو انتخاب می‌شود. پیش‌نویس‌ها
/// (draft) در این انتخاب نادیده گرفته می‌شوند چون هنوز آماده/منتشر نشده‌اند.
Seminar? _pickSpotlightSeminar(List<Seminar> seminars) {
  final candidates =
      seminars.where((s) => !s.hasEnded && s.status != SeminarStatus.draft).toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    if (a.isLiveNow != b.isLiveNow) return a.isLiveNow ? -1 : 1;
    return a.scheduledStart.compareTo(b.scheduledStart);
  });
  return candidates.first;
}

/// متن شمارش معکوس/وضعیت یک سمینار — «همین حالا زنده» یا «۳ روز دیگر» و…
String _countdownLabel(BuildContext context, Seminar s) {
  if (s.isLiveNow) return context.tr('seminars.live');
  final diff = s.scheduledStart.difference(DateTime.now());
  if (diff.isNegative) return context.tr('seminars.ended');
  if (diff.inDays >= 1) {
    return context.tr('seminars.startsInDays', {'count': '${diff.inDays}'});
  }
  if (diff.inHours >= 1) {
    return context.tr('seminars.startsInHours', {'count': '${diff.inHours}'});
  }
  return context.tr('seminars.startsInMinutes', {'count': '${diff.inMinutes + 1}'});
}

class _InstructorSeminarCard extends ConsumerWidget {
  final Seminar seminar;
  final int index;
  const _InstructorSeminarCard({required this.seminar, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = seminar;
    final live = s.isLiveNow;
    final canHost = !s.hasEnded && s.status != SeminarStatus.draft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: live ? AppColors.danger.withValues(alpha: 0.55) : scheme.outlineVariant,
          width: live ? 1.4 : 1,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: live
                      ? const LinearGradient(
                          colors: [Color(0xFFE5484D), Color(0xFFB03038)])
                      : (s.audience == SeminarAudience.parents
                          ? AppColors.successGradient
                          : AppColors.heroGradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  live ? Icons.videocam_rounded : Icons.groups_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _StatusChip(status: s.effectiveStatus),
                        _MiniChip(
                          icon: Icons.calendar_month_rounded,
                          label:
                              '${s.scheduledStart.year}-${_two(s.scheduledStart.month)}-${_two(s.scheduledStart.day)} ${_two(s.scheduledStart.hour)}:${_two(s.scheduledStart.minute)}',
                        ),
                        _MiniChip(
                          icon: Icons.schedule_rounded,
                          label: '${s.durationMinutes}m',
                        ),
                        _MiniChip(
                          icon: Icons.how_to_reg_rounded,
                          label: s.capacity != null
                              ? '${s.registeredCount}/${s.capacity}'
                              : '${s.registeredCount}',
                          onTap: () => _showRegistrants(context, ref),
                        ),
                        _MiniChip(
                          icon: s.audience == SeminarAudience.parents
                              ? Icons.family_restroom_rounded
                              : Icons.school_rounded,
                          label: s.audience == SeminarAudience.parents
                              ? context.tr('seminars.forParents')
                              : context.tr('seminars.forStudents'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _edit(context, ref);
                    case 'delete':
                      _confirmDelete(context, ref);
                    case 'end':
                      _setStatus(context, ref, SeminarStatus.ended);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(context.tr('common.edit')),
                    ]),
                  ),
                  if (live)
                    PopupMenuItem(
                      value: 'end',
                      child: Row(children: [
                        const Icon(Icons.stop_circle_rounded,
                            size: 18, color: AppColors.danger),
                        const SizedBox(width: 10),
                        Text(context.tr('room.endSeminar')),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
                      const SizedBox(width: 10),
                      Text(context.tr('common.delete')),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          if (canHost) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: live ? AppColors.danger : AppColors.green500,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                onPressed: () => _startLive(context, ref),
                icon: Icon(
                  live ? Icons.videocam_rounded : Icons.play_circle_rounded,
                  size: 18,
                ),
                label: Text(
                  live
                      ? context.tr('instructor.hostLive')
                      : context.tr('instructor.startSeminar'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 350.ms)
        .slideY(begin: 0.1, end: 0, delay: (index * 70).ms, duration: 350.ms);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// نمایش فهرست ثبت‌نامی‌های همین سمینار در یک شیت پایینی — رفع اشکال
  /// «استاد نمی‌تواند ببیند چه کسی ثبت‌نام کرده» (رجوع کنید به مستندِ
  /// [_MiniChip]).
  void _showRegistrants(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InstructorRegistrantsSheet(seminar: seminar),
    );
  }

  /// شروع/میزبانی پخش زنده — از جریان مشترک `startSeminarLive` استفاده می‌کند
  /// (go-live روی Cloudflare Stream، انتخاب پخش درون‌اپ/OBS، و برگشت امن).
  Future<void> _startLive(BuildContext context, WidgetRef ref) {
    return startSeminarLive(context, ref, seminar,
        onWentLive: () => ref.invalidate(myInstructorSeminarsProvider));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showSeminarEditorDialog(context, existing: seminar);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(updateSeminarUseCaseProvider).call(
          UpdateSeminarParams(
            id: seminar.id,
            title: result.title,
            description: result.description,
            scheduledStart: result.scheduledStart,
            durationMinutes: result.durationMinutes,
            capacity: result.capacity,
            audience: result.audience,
            meetingLink: result.meetingLink,
          ),
        );
    updated.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('instructor.updated') : '')));
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('instructor.deleteSeminar')),
        content: Text(seminar.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(deleteSeminarUseCaseProvider).call(seminar.id);
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('instructor.deleted') : '')));
      },
    );
  }

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, SeminarStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(setSeminarStatusUseCaseProvider)
        .call(SetSeminarStatusParams(id: seminar.id, status: status));
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) => ref.invalidate(myInstructorSeminarsProvider),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SeminarStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = status == SeminarStatus.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? AppColors.danger : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        context.tr('seminars.status.${status.name}'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isLive ? Colors.white : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// کارت یک سمینارِ آرشیف‌شده — عنوان + تاریخ آرشیف + گزارش هوش مصنوعیِ
/// خلاصهٔ برگزاری (رجوع کنید به `generateSeminarArchiveReport` سرور). چون
/// گزارش می‌تواند نسبتاً طولانی باشد، به‌طور پیش‌فرض جمع‌شده (Collapsed) و
/// با لمس باز می‌شود.
class _ArchivedSeminarCard extends StatefulWidget {
  final Seminar seminar;
  final int index;
  const _ArchivedSeminarCard({required this.seminar, required this.index});

  @override
  State<_ArchivedSeminarCard> createState() => _ArchivedSeminarCardState();
}

class _ArchivedSeminarCardState extends State<_ArchivedSeminarCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.seminar;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_rounded, color: scheme.onSurfaceVariant, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    if (s.archivedAt != null)
                      Text(
                        '${context.tr('instructor.archivedOn')} ${_fmtDate(s.archivedAt!)}',
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          if (_expanded && s.aiReportFa.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(context.tr('instructor.aiReportLabel'),
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800, color: scheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(s.aiReportFa, style: const TextStyle(fontSize: 12.5, height: 1.7)),
                ],
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (widget.index * 60).ms, duration: 300.ms)
        .slideY(begin: 0.08, end: 0, delay: (widget.index * 60).ms, duration: 300.ms);
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  /// رفع اشکال «تفاوت با پنل مدیر»: قبلاً استاد هیچ راهی برای دیدن فهرست
  /// ثبت‌نامی‌های سمینار خودش نداشت (فقط عدد، بدون امکان لمس)، در حالی که
  /// همان Endpoint (`GET /seminars/:id/registrations`) و همان
  /// `seminarRegistrationsProvider` که پنل مدیر استفاده می‌کند، از قبل روی
  /// سرور مالکیت را چک می‌کند و برای استاد هم کار می‌کند. با دادن [onTap]
  /// همین چیپ هم مثل مدیر قابل‌لمس می‌شود.
  final VoidCallback? onTap;
  const _MiniChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onTap != null ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: onTap != null ? FontWeight.w700 : FontWeight.normal,
                  color: onTap != null ? scheme.primary : scheme.onSurfaceVariant)),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(borderRadius: BorderRadius.circular(AppRadii.pill), onTap: onTap, child: chip);
  }
}

/// شیت فهرست ثبت‌نامی‌های سمینار برای استاد — همان الگوی پنل مدیر
/// (`admin_seminars_screen.dart`'s `_RegistrantsSheet`)، روی همان
/// `seminarRegistrationsProvider`/Endpoint مشترک.
class _InstructorRegistrantsSheet extends ConsumerWidget {
  final Seminar seminar;
  const _InstructorRegistrantsSheet({required this.seminar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(seminarRegistrationsProvider(seminar.id));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.35,
      builder: (ctx, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration:
                BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Icon(Icons.how_to_reg_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      context.tr('adminSeminars.registrationsTitle', {'title': seminar.title}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: () => ref.invalidate(seminarRegistrationsProvider(seminar.id)),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.tr('adminSeminars.fetchError', {'error': '$e'}),
                      textAlign: TextAlign.center),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(context.tr('adminSeminars.noRegistrationsYet')),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          (r.name.trim().isNotEmpty && r.name != '—')
                              ? r.name.trim().substring(0, 1)
                              : '?',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(r.role == 'parent'
                          ? context.tr('seminars.forParents')
                          : r.role == 'student'
                              ? context.tr('seminars.forStudents')
                              : (r.role.isEmpty ? '—' : r.role)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// نقطهٔ سرخ تپنده — نشان «سمینار زنده» در هدر قهرمان. اندازه همیشه ۱۰ است
/// (هیچ‌جا اندازهٔ دیگری داده نمی‌شود — رفع لینت unused_element_parameter).
class _LivePulseDot extends StatelessWidget {
  final double size = 10;
  const _LivePulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
            begin: const Offset(0.75, 0.75),
            end: const Offset(1.15, 1.15),
            duration: 800.ms,
            curve: Curves.easeInOut)
        .fade(begin: 0.6, end: 1);
  }
}

/// عدد با شمارش انیمیشنی — هر بار مقدار تغییر کند نرم می‌شمارد (هماهنگ با
/// همان جلوهٔ داشبورد مدیر/شاگرد).
class _InstructorAnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const _InstructorAnimatedCount({required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// هدر قهرمان داشبورد استاد — گرادیان گرم معمولی، یا قرمزِ فوری وقتی یکی از
/// سمینارهایش همین حالا زنده است (بیشترین اولویت بصری، چون نیاز به توجه دارد).
class _InstructorHeroHeader extends StatelessWidget {
  final String name;
  final _InstructorStats stats;
  const _InstructorHeroHeader({required this.name, required this.stats});

  @override
  Widget build(BuildContext context) {
    final hasLive = stats.live > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: hasLive
            ? const LinearGradient(colors: [Color(0xFFE5484D), Color(0xFFB03038)])
            : AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: hasLive
            ? [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty) ...[
            Text(
              context.tr('dashboard.welcomeBack', {'name': name}),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (hasLive) ...[
                const _LivePulseDot(),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(Icons.groups_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                hasLive ? context.tr('seminars.live') : context.tr('instructor.overviewTitle'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _InstructorAnimatedCount(
                value: hasLive ? stats.live : stats.total,
                style: const TextStyle(
                    color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  hasLive ? context.tr('seminars.live') : context.tr('instructor.totalSeminars'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }
}

/// نوار «آمار سمینارهای شما» — پنج شاخص در یک ردیف قابل‌اسکرول، هماهنگ با
/// الگوی همین نوار در داشبورد مدیر (`_TodayActivityStrip`).
class _InstructorStatsStrip extends StatelessWidget {
  final _InstructorStats stats;
  const _InstructorStatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (Icons.groups_rounded, context.tr('instructor.totalSeminars'), stats.total, AppColors.info),
      (Icons.event_available_rounded, context.tr('seminars.upcoming'), stats.upcoming, AppColors.orange600),
      (Icons.videocam_rounded, context.tr('seminars.live'), stats.live, AppColors.danger),
      (Icons.how_to_reg_rounded, context.tr('instructor.registrations'), stats.totalRegistrations, AppColors.green600),
      (Icons.check_circle_rounded, context.tr('seminars.ended'), stats.ended, AppColors.ink500),
    ];
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
              Icon(Icons.bar_chart_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(context.tr('instructor.overviewTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: items[i].$4.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Column(
                      children: [
                        Icon(items[i].$1, size: 18, color: items[i].$4),
                        const SizedBox(height: 6),
                        _InstructorAnimatedCount(
                          value: items[i].$3,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900, color: items[i].$4),
                        ),
                        const SizedBox(height: 2),
                        Text(items[i].$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ).animate().fadeIn(delay: (60 * i).ms, duration: 250.ms).scale(
                      begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// کارت درخشان «سمینار بعدی شما» — نزدیک‌ترین سمینارِ هنوز پایان‌نیافته،
/// با شمارش معکوس زنده و دکمهٔ مستقیم شروع/میزبانیِ پخش.
class _NextSeminarSpotlight extends StatelessWidget {
  final Seminar seminar;
  final VoidCallback onStart;
  const _NextSeminarSpotlight({required this.seminar, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = seminar;
    final live = s.isLiveNow;
    final canHost = !s.hasEnded && s.status != SeminarStatus.draft;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: live ? AppColors.danger.withValues(alpha: 0.55) : scheme.outlineVariant,
          width: live ? 1.4 : 1,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(context.tr('instructor.nextSeminar'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: live
                      ? const LinearGradient(colors: [Color(0xFFE5484D), Color(0xFFB03038)])
                      : (s.audience == SeminarAudience.parents
                          ? AppColors.successGradient
                          : AppColors.heroGradientWarm),
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
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: live ? AppColors.danger : scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _countdownLabel(context, s),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: live ? AppColors.danger : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canHost) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: live ? AppColors.danger : AppColors.green500,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                onPressed: onStart,
                icon: Icon(live ? Icons.videocam_rounded : Icons.play_circle_rounded, size: 18),
                label: Text(
                  live ? context.tr('instructor.hostLive') : context.tr('instructor.startSeminar'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// یک بخش در گرید «دسترسی سریع» داشبورد استاد — آیکن، کلید ترجمه، مسیر و
/// رنگ. منبع حقیقت همان `_instructorItems` در `app_drawer.dart` است (منهای
/// خودِ «سمینارها» چون همین صفحه است).
class _InstructorSectionItem {
  final IconData icon;
  final String labelKey;
  final String route;
  final Color color;
  const _InstructorSectionItem(this.icon, this.labelKey, this.route, this.color);
}

class _InstructorQuickSectionsGrid extends StatelessWidget {
  const _InstructorQuickSectionsGrid();

  static const _sections = [
    _InstructorSectionItem(
        Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory, AppColors.ink700),
    _InstructorSectionItem(
        Icons.support_agent_rounded, 'nav.contactAdmin', AppRoutes.instructorContactAdmin, AppColors.info),
    _InstructorSectionItem(
        Icons.notifications_rounded, 'nav.notifications', AppRoutes.instructorNotifications, AppColors.gold600),
    _InstructorSectionItem(
        Icons.person_rounded, 'nav.profile', AppRoutes.instructorProfile, AppColors.green700),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.86,
      children: [
        for (final s in _sections)
          Material(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              onTap: () => context.push(s.route),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(s.icon, color: s.color, size: 21),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr(s.labelKey),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

