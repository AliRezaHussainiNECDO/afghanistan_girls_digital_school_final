import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/design_tokens.dart';
import '../../features/admin/dashboard/presentation/providers/admin_dashboard_providers.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/curriculum/presentation/widgets/points_badge.dart';
import '../../features/instructor/presentation/providers/instructor_providers.dart';
import '../../features/parent_dashboard/presentation/providers/parent_providers.dart';
import '../../features/student_dashboard/presentation/providers/dashboard_providers.dart';
import '../localization/app_localizations.dart';
import 'info_stat_chip.dart';
import 'user_avatar.dart';

class _DrawerItem {
  final IconData icon;
  final String labelKey;
  final String route;
  const _DrawerItem(this.icon, this.labelKey, this.route);
}

const _studentItems = [
  _DrawerItem(Icons.home_rounded, 'nav.home', AppRoutes.studentHome),
  _DrawerItem(Icons.map_rounded, 'nav.gradeMap', AppRoutes.gradeMap),
  _DrawerItem(Icons.menu_book_rounded, 'nav.curriculum', AppRoutes.curriculum),
  _DrawerItem(Icons.assignment_turned_in_rounded, 'nav.homework', AppRoutes.homework),
  _DrawerItem(Icons.volunteer_activism_rounded, 'nav.advisor', AppRoutes.advisor),
  _DrawerItem(Icons.assignment_rounded, 'nav.exams', AppRoutes.exams),
  _DrawerItem(Icons.event_available_rounded, 'nav.attendance', AppRoutes.attendance),
  _DrawerItem(Icons.local_library_rounded, 'nav.library', AppRoutes.library),
  _DrawerItem(Icons.groups_rounded, 'nav.seminars', AppRoutes.seminars),
  _DrawerItem(Icons.chat_bubble_rounded, 'nav.chat', AppRoutes.chat),
  _DrawerItem(Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory),
  _DrawerItem(Icons.notifications_rounded, 'nav.notifications', AppRoutes.notifications),
  _DrawerItem(Icons.person_rounded, 'nav.profile', AppRoutes.profile),
];

const _adminItems = [
  _DrawerItem(Icons.dashboard_rounded, 'admin.dashboard', AppRoutes.adminDashboard),
  _DrawerItem(Icons.people_rounded, 'admin.users', AppRoutes.adminUsers),
  _DrawerItem(Icons.edit_note_rounded, 'admin.cms', AppRoutes.adminCms),
  _DrawerItem(Icons.quiz_rounded, 'admin.examsManagement', AppRoutes.adminExamsManagement),
  _DrawerItem(Icons.smart_toy_rounded, 'admin.aiTeacherManagement', AppRoutes.adminAiTeacher),
  _DrawerItem(Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory),
  _DrawerItem(Icons.forum_rounded, 'admin.chatMonitoring', AppRoutes.adminChats),
  _DrawerItem(Icons.shield_rounded, 'admin.safetyQueue', AppRoutes.adminSafetyQueue),
  _DrawerItem(Icons.radar_rounded, 'admin.auditLogs', AppRoutes.adminAuditLogs),
  _DrawerItem(Icons.fact_check_rounded, 'admin.submissions', AppRoutes.adminSubmissions),
  _DrawerItem(Icons.groups_rounded, 'admin.seminars', AppRoutes.adminSeminars),
  _DrawerItem(Icons.bar_chart_rounded, 'admin.reports', AppRoutes.adminReports),
  _DrawerItem(Icons.notifications_rounded, 'nav.notifications', AppRoutes.adminNotifications),
  _DrawerItem(Icons.person_rounded, 'nav.profile', AppRoutes.adminProfile),
];

const _parentItems = [
  _DrawerItem(Icons.family_restroom_rounded, 'nav.parentDashboard', AppRoutes.parentDashboard),
  _DrawerItem(Icons.grade_rounded, 'parent.scores', AppRoutes.parentScores),
  _DrawerItem(Icons.groups_rounded, 'parent.seminars', AppRoutes.parentSeminars),
  _DrawerItem(Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory),
  _DrawerItem(Icons.support_agent_rounded, 'nav.contactAdmin', AppRoutes.parentContactAdmin),
  _DrawerItem(Icons.notifications_rounded, 'nav.notifications', AppRoutes.parentNotifications),
  _DrawerItem(Icons.person_rounded, 'nav.profile', AppRoutes.parentProfile),
];

const _instructorItems = [
  _DrawerItem(Icons.groups_rounded, 'nav.instructor', AppRoutes.instructorHome),
  _DrawerItem(Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory),
  _DrawerItem(Icons.support_agent_rounded, 'nav.contactAdmin', AppRoutes.instructorContactAdmin),
  _DrawerItem(Icons.notifications_rounded, 'nav.notifications', AppRoutes.instructorNotifications),
  _DrawerItem(Icons.person_rounded, 'nav.profile', AppRoutes.instructorProfile),
];

String _roleLabel(BuildContext context, AppUserRole role) {
  switch (role) {
    case AppUserRole.superAdmin:
      return context.tr('admin.dashboard');
    case AppUserRole.parent:
      return context.tr('auth.roleParent');
    case AppUserRole.seminarInstructor:
      return context.tr('nav.instructor');
    case AppUserRole.student:
      return context.tr('auth.roleStudent');
  }
}

/// منوی کناری وابسته به نقش — طبق ماتریس مجوزها بخش ۲.۲ سند. سربرگ گرادیانی
/// گرم + آواتار حلقه‌دار + آیتم‌های پیل‌مانند با نشانگر انتخاب.
class AppDrawer extends ConsumerWidget {
  final AppUserRole role;

  const AppDrawer({super.key, required this.role});

  List<_DrawerItem> get _items {
    switch (role) {
      case AppUserRole.superAdmin:
        return _adminItems;
      case AppUserRole.parent:
        return _parentItems;
      case AppUserRole.seminarInstructor:
        return _instructorItems;
      case AppUserRole.student:
        return _studentItems;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    // صفحاتی که با Navigator.push (خارج از درخت GoRoute) باز می‌شوند،
    // GoRouterState ندارند — در آن حالت مسیر خالی می‌ماند تا Drawer بدون
    // خطای «There is no GoRouterState above the current context» کار کند.
    String currentRoute = '';
    try {
      currentRoute = GoRouterState.of(context).matchedLocation;
    } catch (_) {}

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: AppColors.sunriseGradient,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                boxShadow: AppShadows.warm,
              ),
              child: Stack(
                children: [
                  // ── دایره‌های تزئینیِ محوِ پس‌زمینه — حس مدرن/پویا ──
                  Positioned(
                    top: -30,
                    right: -24,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -36,
                    left: -18,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: UserAvatar(
                                    radius: 29,
                                    backgroundColor: Colors.white,
                                    foregroundColor: scheme.primary,
                                  ),
                                ).animate().scale(
                                      begin: const Offset(0.5, 0.5),
                                      end: const Offset(1, 1),
                                      duration: 420.ms,
                                      curve: Curves.easeOutBack,
                                    ),
                                // نشان تأیید ایمیل — همان وضعیت واقعیِ
                                // `AppUser.emailVerified` که در بخش پروفایل
                                // هم استفاده می‌شود؛ اینجا فقط یک اشارهٔ
                                // بصریِ سریع است.
                                if (user != null)
                                  Positioned(
                                    bottom: -2,
                                    left: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: user.emailVerified ? AppColors.green500 : AppColors.gold500,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.6),
                                      ),
                                      child: Icon(
                                        user.emailVerified ? Icons.verified_rounded : Icons.priority_high_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: 260.ms, duration: 260.ms),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (user?.fullName.trim().isNotEmpty ?? false) ? user!.fullName : (user?.displayName ?? ''),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(AppRadii.pill),
                                    ),
                                    child: Text(
                                      _roleLabel(context, role),
                                      style:
                                          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // ── معلومات اضافیِ نقش‌محور — طبق درخواست کاربر، به‌ویژه
                        // برای شاگرد (صنف + امتیاز/سطح فعالیت)، تا سربرگ منو
                        // حالت پیشرفته‌تری بگیرد. برای هر نقش از منبع واقعیِ
                        // همان داشبورد خوانده می‌شود (نه دادهٔ ساختگی). ──
                        if (user != null) ...[
                          const SizedBox(height: 14),
                          _RoleExtraInfo(role: role, user: user),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: _items.map((item) {
                  final selected = currentRoute == item.route;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: selected ? scheme.primaryContainer : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go(item.route);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 22,
                                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    context.tr(item.labelKey),
                                    style: TextStyle(
                                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList().animate(interval: 45.ms).fadeIn(duration: 260.ms).slideX(
                    begin: 0.12, end: 0, duration: 260.ms, curve: Curves.easeOutCubic),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () async {
                    await ref.read(authSessionProvider.notifier).logout();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 22, color: scheme.error),
                        const SizedBox(width: 14),
                        Text(
                          context.tr('common.logout'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: scheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ردیف معلومات اضافیِ سربرگ Drawer — بسته به نقش، از Provider واقعیِ همان
/// داشبورد می‌خواند تا سربرگ منو در همهٔ داشبوردها یک حس پیشرفته و «زنده»
/// داشته باشد (نه فقط نام/نقش ثابت):
///   • شاگرد: صنف فعلی + امتیاز فعالیت/سطح (همان منبع خانهٔ شاگرد).
///   • والد: تعداد فرزندان متصل‌شدهٔ تأییدشده.
///   • مدیر کل: تعداد شاگردان ثبت‌نامی + فعال امروز (همان KPI داشبورد مدیر).
///   • استاد سمینار: تعداد سمینارهای خودش.
/// در حالت بارگذاری، اسکلت محو نشان می‌دهد؛ در خطا، بی‌صدا چیزی نشان
/// نمی‌دهد تا باز شدن منو هرگز به‌خاطر یک درخواست شبکه ناکام مسدود نشود.
class _RoleExtraInfo extends ConsumerWidget {
  final AppUserRole role;
  final AppUser user;
  const _RoleExtraInfo({required this.role, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (role) {
      case AppUserRole.student:
        final summaryAsync = ref.watch(dashboardSummaryProvider(user.id));
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              InfoStatChip(
                icon: Icons.school_rounded,
                dense: true,
                light: true,
                label: context.tr('profile.grade'),
                value: user.currentGrade != null ? '${user.currentGrade}' : '—',
              ),
              const SizedBox(width: 8),
              summaryAsync.when(
                loading: () => const InfoStatChipSkeleton(light: true, dense: true),
                error: (_, __) => const SizedBox.shrink(),
                data: (summary) => PointsBadge(
                  pointsTotal: summary.pointsTotal,
                  pointsLevel: summary.pointsLevel,
                  pointsLevelTitleFa: summary.pointsLevelTitleFa,
                  light: true,
                  compact: true,
                ),
              ),
            ],
          ),
        );

      case AppUserRole.parent:
        final childrenAsync = ref.watch(linkedChildrenProvider);
        return childrenAsync.when(
          loading: () => const InfoStatChipSkeleton(light: true, dense: true),
          error: (_, __) => const SizedBox.shrink(),
          data: (children) => InfoStatChip(
            icon: Icons.family_restroom_rounded,
            dense: true,
            light: true,
            label: context.tr('profile.linkedChildren'),
            value: '${children.length}',
          ),
        );

      case AppUserRole.superAdmin:
        final statsAsync = ref.watch(adminStatsProvider);
        return statsAsync.when(
          loading: () => const InfoStatChipSkeleton(light: true, dense: true),
          error: (_, __) => const SizedBox.shrink(),
          data: (stats) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InfoStatChip(
                  icon: Icons.groups_rounded,
                  dense: true,
                  light: true,
                  label: context.tr('admin.totalStudents'),
                  value: '${stats.totalStudents}',
                ),
                const SizedBox(width: 8),
                InfoStatChip(
                  icon: Icons.bolt_rounded,
                  dense: true,
                  light: true,
                  label: context.tr('admin.activeToday'),
                  value: '${stats.activeToday}',
                ),
              ],
            ),
          ),
        );

      case AppUserRole.seminarInstructor:
        final seminarsAsync = ref.watch(myInstructorSeminarsProvider);
        return seminarsAsync.when(
          loading: () => const InfoStatChipSkeleton(light: true, dense: true),
          error: (_, __) => const SizedBox.shrink(),
          data: (seminars) => InfoStatChip(
            icon: Icons.groups_rounded,
            dense: true,
            light: true,
            label: context.tr('profile.mySeminars'),
            value: '${seminars.length}',
          ),
        );
    }
  }
}
