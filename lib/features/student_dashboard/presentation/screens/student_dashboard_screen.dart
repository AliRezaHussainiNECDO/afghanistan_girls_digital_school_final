import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/student/grade_widgets.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../curriculum/presentation/widgets/points_badge.dart';
import '../../../study_plan/presentation/widgets/today_schedule_card.dart';
import '../providers/dashboard_providers.dart';

String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final studentId = user?.id ?? 'unknown';
    final summaryAsync = ref.watch(dashboardSummaryProvider(studentId));
    final grade = ref.watch(selectedGradeProvider);
    final scheme = Theme.of(context).colorScheme;

    // نام واقعی شاگردِ واردشده (نه نام ثابت داده‌های نمونه) برای سربرگ.
    final greetingName = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : ((user?.displayName.trim().isNotEmpty ?? false)
            ? user!.displayName.trim()
            : '');

    return AppScaffold(
      title: context.tr('nav.home'),
      role: AppUserRole.student,
      body: summaryAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(dashboardSummaryProvider(studentId)),
        ),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // --- بنر تأیید ایمیل (تا زمانی که کاربر ایمیلش را تأیید نکرده) ---
            const EmailVerificationBanner(),
            // --- سربرگ خوش‌آمدگویی + حلقهٔ پیشرفت ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppShadows.warm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('dashboard.welcomeBack', {
                            'name': greetingName.isNotEmpty ? greetingName : summary.studentDisplayName
                          }),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr('dashboard.overallProgress'),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        // ── امتیاز فعالیت (Gamification) — طبق `getPointsSummary` سرور ──
                        // نسخهٔ پویا/زیبا: عدد با انیمیشن شمارشی بالا می‌رود،
                        // نشان می‌تپد، و نوار پیشرفت واقعی «چند امتیاز تا سطح
                        // بعدی» نشان داده می‌شود (طبق درخواست کاربر).
                        StudentPointsHero(
                          pointsTotal: summary.pointsTotal,
                          pointsLevel: summary.pointsLevel,
                          pointsLevelTitleFa: summary.pointsLevelTitleFa,
                          nextLevelAt: summary.pointsNextLevelAt,
                          nextLevelTitleFa: summary.pointsNextLevelTitleFa,
                          progressToNextPercent: summary.pointsProgressToNextPercent,
                        ),
                      ],
                    ),
                  ),
                  _ProgressRing(percent: summary.overallProgressPercent),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 420.ms)
                .slideY(begin: 0.12, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 18),

            // ── بخش‌های اصلی برنامه — هماهنگ با مینوی کشویی شاگرد ──
            // طبق درخواست صاحب پروژه: صفحهٔ اول شاگرد باید با بخش‌های اصلی
            // مینوی شاگردان (منبع حقیقت: `_studentItems` در `app_drawer.dart`)
            // هماهنگ باشد تا هر بخش، بدون باز کردن منو، مستقیماً از خانه
            // قابل دسترس باشد. عنوان‌ها از همان کلیدهای ترجمهٔ `nav.*` مینو
            // خوانده می‌شوند تا هرگز بین منو و خانه ناهماهنگی پیش نیاید.
            Row(
              children: [
                Icon(Icons.apps_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(context.tr('dashboard.mainSections'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            const _MainSectionsGrid()
                .animate()
                .fadeIn(delay: 60.ms, duration: 400.ms)
                .slideY(begin: 0.10, end: 0, delay: 60.ms, duration: 400.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 18),

            // ── انتخاب صنف + مضامین همان صنف ──
            Row(
              children: [
                Icon(Icons.school_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(context.tr('dashboard.myGrade'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            const GradeSelector(),
            const SizedBox(height: 16),
            const PromotionStatusCard(),
            const SizedBox(height: 18),
            Text(context.tr('dashboard.subjectsOfGrade', {'grade': '$grade'}),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            const GradeSubjectsGrid(),
            const SizedBox(height: 20),

            // ── تقسیم اوقات هوشمند امروز (ساخته‌شده توسط هوش مصنوعی) ──
            const TodayScheduleCard()
                .animate()
                .fadeIn(delay: 80.ms, duration: 400.ms)
                .slideY(
                    begin: 0.12,
                    end: 0,
                    delay: 80.ms,
                    duration: 400.ms,
                    curve: Curves.easeOutCubic),
            const SizedBox(height: 16),

            // ── ادامهٔ یادگیری: چند مضمون «در حال انجام» (نه فقط یکی) ──
            // رفع اشکال قبلی: همیشه فقط اولین مضمون برنامهٔ درسی نشان داده
            // می‌شد؛ اکنون سرور تا ۳ مضمونی که شاگرد واقعاً در آن‌ها فعالیت
            // داشته (به ترتیب آخرین بازدید) برمی‌گرداند.
            if (summary.continueLearning.isNotEmpty) ...[
              Text(context.tr('dashboard.continueLesson'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 10),
              for (var i = 0; i < summary.continueLearning.length; i++) ...[
                _ActionCard(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: scheme.primary,
                  title: summary.continueLearning[i].subjectNameFa,
                  subtitle: summary.continueLearning[i].lessonTitle,
                  trailingPercent: summary.continueLearning[i].progressPercent,
                  onTap: () => context.push(AppRoutes.curriculum),
                ).animate().fadeIn(delay: (120 + i * 40).ms, duration: 380.ms).slideY(
                    begin: 0.15, end: 0, delay: (120 + i * 40).ms, duration: 380.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 10),
              ],
            ] else ...[
              _ActionCard(
                icon: Icons.play_circle_fill_rounded,
                iconColor: scheme.primary,
                title: context.tr('dashboard.continueLesson'),
                subtitle: '${summary.currentSubjectNameFa} — ${summary.currentLessonTitle}',
                onTap: () => context.push(AppRoutes.curriculum),
              ).animate().fadeIn(delay: 120.ms, duration: 380.ms).slideY(
                  begin: 0.15, end: 0, delay: 120.ms, duration: 380.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 12),
            ],
            // ── گواهی‌نامه‌ها: زیرنویس اکنون واقعی است، نه یک متن ثابت ──
            _ActionCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFB8860B),
              title: context.tr('dashboard.myCertificates'),
              subtitle: summary.certificatesCount > 0
                  ? context.tr('dashboard.certificatesIssuedCount', {'count': '${summary.certificatesCount}'})
                  : context.tr('dashboard.noCertificatesYet'),
              onTap: () => context.push(AppRoutes.certificates),
            ).animate().fadeIn(delay: 160.ms, duration: 380.ms).slideY(
                begin: 0.15, end: 0, delay: 160.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 12),
            // ── مشق کاغذی + نمره‌دهی هوشمند — همیشه نمایش داده می‌شود (وابسته
            // به خلاصهٔ سرور نیست) تا شاگرد همیشه راه سریعی برای فرستادن عکس
            // مشق داشته باشد.
            _ActionCard(
              icon: Icons.assignment_turned_in_rounded,
              iconColor: AppColors.orange500,
              title: context.tr('dashboard.homeworkCardTitle'),
              subtitle: context.tr('dashboard.homeworkCardSubtitle'),
              onTap: () => context.push(AppRoutes.homework),
            ).animate().fadeIn(delay: 180.ms, duration: 380.ms).slideY(
                begin: 0.15, end: 0, delay: 180.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            // نکته (رفع اشکال): باید هم عنوان و هم تاریخ موجود باشد؛ سرور
            // ممکن است فقط عنوان امتحان را بفرستد و تاریخ را null بگذارد
            // (چون هنوز فیلد تاریخ در جدول امتحانات وجود ندارد) — قبلاً این‌جا
            // فقط عنوان چک می‌شد و «!» روی تاریخِ null کرش می‌کرد.
            if (summary.upcomingExamTitle != null) ...[
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.assignment_rounded,
                iconColor: scheme.tertiary,
                title: context.tr('dashboard.upcomingExam'),
                subtitle: summary.upcomingExamDate != null
                    ? '${summary.upcomingExamTitle} — ${_fmtDate(summary.upcomingExamDate!)}'
                    : summary.upcomingExamTitle!,
                onTap: () => context.push(AppRoutes.exams),
              ).animate().fadeIn(delay: 200.ms, duration: 380.ms).slideY(
                  begin: 0.15, end: 0, delay: 200.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            ],
            // رفع اشکال «فقط یک سمینار نمایش/ایجاد می‌شود»: قبلاً این‌جا فقط
            // نزدیک‌ترین سمینار (یک کارت) نشان داده می‌شد، در حالی که ممکن
            // بود چند سمینار در انتظار باشند. اکنون فهرست کامل سمینارهای در
            // انتظار (طبق `upcomingSeminars` سرور) نمایش داده می‌شود.
            if (summary.upcomingSeminars.isNotEmpty)
              for (var i = 0; i < summary.upcomingSeminars.length; i++) ...[
                const SizedBox(height: 12),
                _ActionCard(
                  icon: Icons.groups_rounded,
                  iconColor: scheme.secondary,
                  title: context.tr('dashboard.upcomingSeminar'),
                  subtitle:
                      '${summary.upcomingSeminars[i].title} — ${_fmtDate(summary.upcomingSeminars[i].scheduledStart)}',
                  onTap: () => context.push(AppRoutes.seminars),
                ).animate().fadeIn(delay: (260 + i * 60).ms, duration: 380.ms).slideY(
                    begin: 0.15,
                    end: 0,
                    delay: (260 + i * 60).ms,
                    duration: 380.ms,
                    curve: Curves.easeOutCubic),
              ],
            if (summary.recommendedTopics.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                context.tr('dashboard.weaknessAlert'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.recommendedTopics
                    .map((t) => Chip(
                          label: Text(t),
                          backgroundColor: scheme.surfaceContainerHigh,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// یک بخش اصلی برنامه در گرید خانهٔ شاگرد — آیکن، کلید ترجمه، مسیر، و رنگ.
class _SectionItem {
  final IconData icon;
  final String labelKey;
  final String route;
  final Color color;
  const _SectionItem(this.icon, this.labelKey, this.route, this.color);
}

/// گرید «بخش‌های اصلی» — دقیقاً همان بخش‌های مینوی کشویی شاگرد
/// (`_studentItems` در `app_drawer.dart`)، با همان آیکن‌ها، همان کلیدهای
/// ترجمه (`nav.*`) و همان مسیرها؛ فقط «خانه» حذف شده چون خودِ همین صفحه
/// است. اگر بخشی به مینو اضافه/کم شد، این فهرست هم باید به‌روز شود.
class _MainSectionsGrid extends StatelessWidget {
  const _MainSectionsGrid();

  static const _sections = [
    _SectionItem(Icons.map_rounded, 'nav.gradeMap', AppRoutes.gradeMap, AppColors.info),
    _SectionItem(Icons.menu_book_rounded, 'nav.curriculum', AppRoutes.curriculum, AppColors.orange600),
    _SectionItem(Icons.assignment_turned_in_rounded, 'nav.homework', AppRoutes.homework, AppColors.orange500),
    _SectionItem(Icons.volunteer_activism_rounded, 'nav.advisor', AppRoutes.advisor, AppColors.danger),
    _SectionItem(Icons.assignment_rounded, 'nav.exams', AppRoutes.exams, AppColors.green600),
    _SectionItem(Icons.event_available_rounded, 'nav.attendance', AppRoutes.attendance, AppColors.green500),
    _SectionItem(Icons.local_library_rounded, 'nav.library', AppRoutes.library, AppColors.gold600),
    _SectionItem(Icons.groups_rounded, 'nav.seminars', AppRoutes.seminars, AppColors.info),
    _SectionItem(Icons.chat_bubble_rounded, 'nav.chat', AppRoutes.chat, AppColors.orange400),
    _SectionItem(Icons.auto_stories_rounded, 'nav.collectiveMemory', AppRoutes.collectiveMemory, AppColors.ink700),
    _SectionItem(Icons.notifications_rounded, 'nav.notifications', AppRoutes.notifications, AppColors.gold500),
    _SectionItem(Icons.person_rounded, 'nav.profile', AppRoutes.profile, AppColors.green700),
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

class _ProgressRing extends StatelessWidget {
  final double percent;
  const _ProgressRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();
    return SizedBox(
      width: 64,
      height: 64,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double? trailingPercent;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingPercent,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailingPercent != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('٪${trailingPercent!.toStringAsFixed(0)}',
                      style: TextStyle(color: iconColor, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
