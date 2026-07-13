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

            // ── انتخاب صنف + مضامین همان صنف ──
            Row(
              children: [
                Icon(Icons.school_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text('صنف من', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            const GradeSelector(),
            const SizedBox(height: 16),
            const PromotionStatusCard(),
            const SizedBox(height: 18),
            Text('مضامین صنف $grade',
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

            _ActionCard(
              icon: Icons.play_circle_fill_rounded,
              iconColor: scheme.primary,
              title: context.tr('dashboard.continueLesson'),
              subtitle: '${summary.currentSubjectNameFa} — ${summary.currentLessonTitle}',
              onTap: () => context.push(AppRoutes.curriculum),
            ).animate().fadeIn(delay: 120.ms, duration: 380.ms).slideY(
                begin: 0.15, end: 0, delay: 120.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFB8860B),
              title: 'گواهی‌نامه‌های من',
              subtitle: 'مشاهده و دانلود گواهی‌نامه‌های اتمام صنف',
              onTap: () => context.push(AppRoutes.certificates),
            ).animate().fadeIn(delay: 160.ms, duration: 380.ms).slideY(
                begin: 0.15, end: 0, delay: 160.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            if (summary.upcomingExamTitle != null) ...[
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.assignment_rounded,
                iconColor: scheme.tertiary,
                title: context.tr('dashboard.upcomingExam'),
                subtitle: '${summary.upcomingExamTitle} — ${_fmtDate(summary.upcomingExamDate!)}',
                onTap: () => context.push(AppRoutes.exams),
              ).animate().fadeIn(delay: 200.ms, duration: 380.ms).slideY(
                  begin: 0.15, end: 0, delay: 200.ms, duration: 380.ms, curve: Curves.easeOutCubic),
            ],
            if (summary.upcomingSeminarTitle != null) ...[
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.groups_rounded,
                iconColor: scheme.secondary,
                title: context.tr('dashboard.upcomingSeminar'),
                subtitle: '${summary.upcomingSeminarTitle} — ${_fmtDate(summary.upcomingSeminarDate!)}',
                onTap: () => context.push(AppRoutes.seminars),
              ).animate().fadeIn(delay: 260.ms, duration: 380.ms).slideY(
                  begin: 0.15, end: 0, delay: 260.ms, duration: 380.ms, curve: Curves.easeOutCubic),
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

class _ProgressRing extends StatelessWidget {
  final double percent;
  const _ProgressRing({required this.percent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percent / 100,
            strokeWidth: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.25),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
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

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
