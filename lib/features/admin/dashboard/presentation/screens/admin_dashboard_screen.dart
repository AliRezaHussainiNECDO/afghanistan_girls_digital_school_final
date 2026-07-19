import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../chat/presentation/widgets/chat_ui_helpers.dart';
import '../../../system_health/presentation/widgets/system_health_section.dart';
import '../../domain/entities/admin_stats.dart';
import '../providers/admin_dashboard_providers.dart';

/// صفحهٔ اول داشبورد مدیر — «نبض زندهٔ مکتب»:
///   • هدر زنده با شمار آنلاین‌های همین حالا (ضربان حضور — migration 0032)
///   • شمار کاربران هر ۳ نقش (شاگرد/والد/استاد) با شمارندهٔ انیمیشنی
///   • فعالیت امروز (درس/امتحان/چت/کار خانگی/ثبت‌نام) به‌صورت زنده
///   • موارد نیازمند اقدام (بازبینی چت، هشدار ایمنی) با پرش مستقیم
///   • فهرست «همین حالا در مکتب» با نقطهٔ سبز تپنده
/// هر ۶ ثانیه بی‌صدا تازه می‌شود (Riverpod دادهٔ قبلی را نگه می‌دارد).
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      ref.invalidate(adminLiveStatsProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveAsync = ref.watch(adminLiveStatsProvider);
    final statsAsync = ref.watch(adminStatsProvider);

    return AppScaffold(
      title: context.tr('admin.dashboard'),
      role: AppUserRole.superAdmin,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminLiveStatsProvider);
          ref.invalidate(adminStatsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            liveAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(),
              ),
              error: (e, st) => ErrorView(error: e),
              data: (live) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LivePulseHeader(live: live),
                  const SizedBox(height: 16),
                  _RoleCountsRow(live: live),
                  const SizedBox(height: 16),
                  _TodayActivityStrip(live: live),
                  const SizedBox(height: 16),
                  _PendingActionsSection(live: live),
                  const SizedBox(height: 16),
                  _OnlineNowSection(live: live),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(context.tr('adminLive.overviewTitle'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, st) => ErrorView(error: e),
              data: (stats) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  _KpiCard(
                    icon: Icons.today_rounded,
                    label: context.tr('admin.activeToday'),
                    value: '${stats.activeToday}',
                    gradient: AppColors.successGradient,
                  ),
                  _KpiCard(
                    icon: Icons.warning_amber_rounded,
                    label: context.tr('admin.atRisk'),
                    value: '${stats.atRiskCount}',
                    gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFB4232A)]),
                  ),
                  _KpiCard(
                    icon: Icons.grade_rounded,
                    label: context.tr('dashboard.overallProgress'),
                    value: '${stats.avgScorePercent.toStringAsFixed(1)}%',
                    gradient: AppColors.heroGradientWarm,
                  ),
                  _KpiCard(
                    icon: Icons.groups_rounded,
                    label: context.tr('admin.totalStudents'),
                    value: '${stats.totalStudents}',
                    gradient: AppColors.heroGradient,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SystemHealthSection(),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

/// عدد با شمارش انیمیشنی — هر بار مقدار زنده تغییر کند، نرم می‌شمارد.
class _AnimatedCount extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const _AnimatedCount({required this.value, this.style});

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

/// نقطهٔ سبز تپنده — نشان «زنده».
class _PulsingDot extends StatelessWidget {
  final Color color;
  final double size;
  const _PulsingDot({this.color = const Color(0xFF33D17A), this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

/// هدر «نبض زندهٔ مکتب» — گرادیان قهرمان + شمار آنلاین همین حالا.
class _LivePulseHeader extends StatelessWidget {
  final AdminLiveStats live;
  const _LivePulseHeader({required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulsingDot(),
              const SizedBox(width: 8),
              Text(context.tr('adminLive.liveTitle'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.podcasts_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(context.tr('adminLive.liveBadge'),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AnimatedCount(
                value: live.onlineTotal,
                style: const TextStyle(
                    color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(context.tr('adminLive.onlineNowLabel'),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('adminLive.totalUsersLine', {'count': '${live.totalUsers}'}),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06);
  }
}

/// سه کارت نقش — شاگردان / والدین / استادان با شمارندهٔ انیمیشنی + آنلاین.
class _RoleCountsRow extends StatelessWidget {
  final AdminLiveStats live;
  const _RoleCountsRow({required this.live});

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        icon: Icons.school_rounded,
        label: context.tr('adminLive.roleStudents'),
        count: live.students,
        online: live.onlineStudents,
        gradient: AppColors.heroGradient,
      ),
      (
        icon: Icons.family_restroom_rounded,
        label: context.tr('adminLive.roleParents'),
        count: live.parents,
        online: live.onlineParents,
        gradient: AppColors.successGradient,
      ),
      (
        icon: Icons.co_present_rounded,
        label: context.tr('adminLive.roleInstructors'),
        count: live.instructors,
        online: live.onlineInstructors,
        gradient: AppColors.heroGradientWarm,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _RoleCard(
              icon: cards[i].icon,
              label: cards[i].label,
              count: cards[i].count,
              online: cards[i].online,
              gradient: cards[i].gradient,
            ).animate().fadeIn(delay: (80 * i).ms, duration: 300.ms).slideY(begin: 0.1),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final int online;
  final Gradient gradient;
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.online,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          _AnimatedCount(
            value: count,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingDot(size: 6, color: AppColors.green600),
                const SizedBox(width: 4),
                Text(
                  context.tr('adminLive.onlineChip', {'count': '$online'}),
                  style: const TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.green700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نوار «فعالیت امروز» — پنج شاخص زنده در یک ردیف قابل‌اسکرول.
class _TodayActivityStrip extends StatelessWidget {
  final AdminLiveStats live;
  const _TodayActivityStrip({required this.live});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (Icons.menu_book_rounded, context.tr('adminLive.todayLessons'), live.lessonsViewedToday, AppColors.info),
      (Icons.assignment_turned_in_rounded, context.tr('adminLive.todayExams'), live.examAttemptsToday, AppColors.orange600),
      (Icons.chat_bubble_rounded, context.tr('adminLive.todayMessages'), live.chatMessagesToday, AppColors.green600),
      (Icons.edit_note_rounded, context.tr('adminLive.todayHomeworks'), live.homeworksSubmittedToday, const Color(0xFF8E5BD0)),
      (Icons.person_add_alt_1_rounded, context.tr('adminLive.todayNewUsers'), live.newUsersToday, AppColors.gold600),
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
              Icon(Icons.bolt_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(context.tr('adminLive.todayTitle'),
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
                        _AnimatedCount(
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

/// «نیازمند اقدام شما» — بازبینی چت و هشدارهای ایمنی، با پرش مستقیم.
class _PendingActionsSection extends StatelessWidget {
  final AdminLiveStats live;
  const _PendingActionsSection({required this.live});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final calm = live.pendingChatReviews == 0 && live.pendingSafetyFlags == 0;
    if (calm) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.green50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.green100),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppColors.green600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(context.tr('adminLive.allCalm'),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.green700)),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }
    Widget actionCard({
      required IconData icon,
      required String label,
      required int count,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedCount(
                        value: count,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900, color: color),
                      ),
                      Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('adminLive.actionTitle'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        const SizedBox(height: 10),
        Row(
          children: [
            actionCard(
              icon: Icons.rate_review_rounded,
              label: context.tr('adminLive.actionChatReviews'),
              count: live.pendingChatReviews,
              color: AppColors.orange600,
              onTap: () => context.push(AppRoutes.adminChats),
            ),
            const SizedBox(width: 10),
            actionCard(
              icon: Icons.shield_rounded,
              label: context.tr('adminLive.actionSafety'),
              count: live.pendingSafetyFlags,
              color: AppColors.danger,
              onTap: () => context.push(AppRoutes.adminSafetyQueue),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06);
  }
}

/// «همین حالا در مکتب» — تازه‌ترین کاربران آنلاین/اخیر با هویت و نقش.
class _OnlineNowSection extends StatelessWidget {
  final AdminLiveStats live;
  const _OnlineNowSection({required this.live});

  String _roleLabel(BuildContext context, String role) => switch (role) {
        'parent' => context.tr('adminLive.roleParent'),
        'seminar_instructor' => context.tr('adminLive.roleInstructor'),
        _ => context.tr('adminLive.roleStudent'),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              const _PulsingDot(size: 8, color: AppColors.green600),
              const SizedBox(width: 6),
              Text(context.tr('adminLive.onlineListTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const Spacer(),
              Text(
                context.tr('adminLive.onlineChip', {'count': '${live.onlineTotal}'}),
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (live.recentOnline.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(context.tr('adminLive.onlineEmpty'),
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            )
          else
            ...live.recentOnline.take(8).toList().asMap().entries.map((e) {
              final u = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ChatAvatar(name: u.name, size: 36, avatarUrl: u.avatarUrl),
                        if (u.isOnline)
                          const PositionedDirectional(
                            bottom: -1,
                            end: -1,
                            child: _PulsingDot(size: 9, color: AppColors.green600),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12.5)),
                          Text(
                            u.gradeNumber != null
                                ? '${_roleLabel(context, u.role)} · ${context.tr('bulkImport.gradeOption', {'grade': '${u.gradeNumber}'})}'
                                : _roleLabel(context, u.role),
                            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      relativeTimeFa(context, u.lastSeenAt),
                      style: TextStyle(
                          fontSize: 10.5,
                          color: u.isOnline ? AppColors.green600 : scheme.onSurfaceVariant,
                          fontWeight: u.isOnline ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (50 * e.key).ms, duration: 250.ms).slideX(begin: 0.05);
            }),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Gradient gradient;
  const _KpiCard(
      {required this.icon, required this.label, required this.value, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const Spacer(),
          Text(value,
              style:
                  Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
