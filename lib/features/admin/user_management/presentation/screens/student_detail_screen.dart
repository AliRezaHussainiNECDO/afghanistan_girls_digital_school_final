/// صفحهٔ جزئیات شاگرد — تب‌ها: نمای کلی / پیشرفت / حاضری / گزارش استاد AI.
/// اکشن‌های مدیر (مسدودسازی، حذف، ریست رمز، …) از Registry توسعه‌پذیر.

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../advisor/data/advisor_store.dart';
import '../../../../advisor/domain/advisor_entities.dart';
import '../../../../advisor/presentation/advisor_providers.dart';
import '../../../../certificates/presentation/widgets/admin_certificates_section.dart';
import '../../../../chat/domain/entities/chat_entities.dart';
import '../../../../chat/domain/usecases/chat_usecases.dart';
import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../chat_monitoring/presentation/screens/admin_chat_thread_screen.dart' show AdminMessageCard;
import '../../domain/entities/student_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/admin_actions_sheet.dart';
import '../widgets/admin_student_exams_tab.dart';
import '../widgets/common_widgets.dart';
import '../widgets/student_homework_tab.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(studentDetailProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 8,
        child: Scaffold(
          backgroundColor: AppPalette.surface,
          body: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(e.toString(), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(studentDetailProvider(studentId)),
                  icon: const Icon(Icons.refresh),
                  label: Text(context.tr('common.retry')),
                ),
              ]),
            ),
            data: (d) => NestedScrollView(
              headerSliverBuilder: (_, __) => [
                _Header(detail: d, studentId: studentId),
              ],
              body: TabBarView(children: [
                _OverviewTab(detail: d),
                _ProgressTab(detail: d),
                _AttendanceTab(detail: d),
                _AiReportTab(studentId: studentId),
                _AdvisorTab(studentId: studentId),
                _AdminChatTab(userId: studentId, userName: d.summary.fullName),
                StudentHomeworkTab(studentId: studentId),
                AdminStudentExamsTab(studentId: studentId),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────
class _Header extends ConsumerWidget {
  final StudentDetail detail;
  final String studentId;
  const _Header({required this.detail, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = detail.summary;
    return SliverAppBar(
      expandedHeight: 235,
      pinned: true,
      backgroundColor: AppPalette.greenDark,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: context.tr('studentDetail.adminActionsTooltip'),
          onPressed: () => showAdminActionsSheet(context, ref, detail),
        ),
      ],
      bottom: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: context.tr('studentDetail.tabOverview')),
          Tab(text: context.tr('studentDetail.tabProgress')),
          Tab(text: context.tr('studentDetail.tabAttendance')),
          Tab(text: context.tr('studentDetail.tabAiReport')),
          Tab(text: context.tr('studentDetail.tabAdvisor')),
          Tab(text: context.tr('studentDetail.tabAdminChat')),
          Tab(text: context.tr('studentDetail.tabHomework')),
          Tab(text: context.tr('studentDetail.tabExams')),
        ],
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppPalette.greenDark, AppPalette.green],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 60),
              child: Row(children: [
                Hero(
                  tag: 'avatar-${s.id}',
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Text(s.fullName.characters.first,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.greenDark)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(s.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            context.tr('studentDetail.headerSubtitle', {
                              'grade': '${s.grade}',
                              'province': s.province,
                              'rank': '${detail.classRank}',
                              'size': '${detail.classSize}',
                            }),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(children: [
                          StatusBadge(s.status),
                          const SizedBox(width: 6),
                          RiskBadge(s.riskLevel),
                        ]),
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab 1: نمای کلی ────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final StudentDetail detail;
  const _OverviewTab({required this.detail});

  String _fmt(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    return ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(
        crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: [
          StatTile(
              icon: Icons.school,
              value: '٪${s.gradeAverage.toStringAsFixed(0)}',
              label: context.tr('studentList.gradeAverageLabel')),
          StatTile(
              icon: Icons.event_available,
              value: '٪${s.attendanceRate.toStringAsFixed(0)}',
              label: context.tr('studentDetail.attendanceRateLabel'),
              color: s.attendanceRate >= 75 ? AppPalette.green : AppPalette.red),
          StatTile(
              icon: Icons.quiz,
              value: '${detail.examsTaken}',
              label: context.tr('studentDetail.examsTakenLabel'),
              color: Colors.indigo),
          StatTile(
              icon: Icons.workspace_premium,
              value: '${detail.certificatesCount}',
              label: context.tr('studentDetail.certificatesLabel'),
              color: AppPalette.amber),
        ],
      ),
      const SizedBox(height: 14),
      _PromotionSection(studentId: s.id, detail: detail),
      const SizedBox(height: 14),
      SectionCard(
        title: context.tr('studentDetail.personalInfoTitle'),
        icon: Icons.badge_outlined,
        child: Column(children: [
          _InfoRow(label: context.tr('instructorDetail.emailLabel'), value: detail.email),
          _InfoRow(label: context.tr('studentDetail.phoneNumberLabel'), value: detail.phone),
          _InfoRow(label: context.tr('studentDetail.birthDateLabel'), value: _fmt(detail.birthDate)),
          _InfoRow(label: context.tr('studentDetail.registeredAtLabel'), value: _fmt(detail.registeredAt)),
          _InfoRow(
              label: context.tr('studentDetail.lastActiveLabel'),
              value: s.lastActiveAt != null
                  ? _fmt(s.lastActiveAt!)
                  : context.tr('studentDetail.unknownValue')),
          _InfoRow(
              label: context.tr('studentDetail.aiTeacherChatLabel'),
              value: context.tr('studentDetail.messagesCountSuffix', {'count': '${detail.aiConversationsCount}'})),
          _InfoRow(
              label: context.tr('studentDetail.advisorChatLabel'),
              value: context.tr('studentDetail.messagesCountSuffix', {'count': '${AdvisorStore.instance.messagesFor(s.id).length}'})),
        ]),
      ),
      // ── گواهی‌نامه‌ها: ارسال پس از ختم هر صنف + لیست ارسال‌شده‌ها ──
      AdminCertificatesSection(detail: detail),
      SectionCard(
        title: context.tr('studentDetail.parentsGuardianTitle'),
        icon: Icons.family_restroom,
        child: detail.parentLinks.isEmpty
            ? Text(context.tr('studentDetail.noParentsLinked'),
                style: TextStyle(color: Colors.grey.shade600))
            : Column(
                children: detail.parentLinks
                    .map((p) => _InfoRow(
                        label: p.parentName,
                        value: switch (p.linkStatus) {
                          'approved' => context.tr('studentDetail.linkApproved'),
                          'pending_student_approval' => context.tr('studentDetail.linkPendingApproval'),
                          _ => context.tr('studentDetail.linkRejected'),
                        }))
                    .toList(),
              ),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}

// ── Tab 2: پیشرفت درسی ─────────────────────────────────────────────────────
class _ProgressTab extends StatelessWidget {
  final StudentDetail detail;
  const _ProgressTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      for (final sub in detail.subjects)
        SectionCard(
          title: sub.subjectName,
          icon: switch (sub.status) {
            SubjectStatus.completed => Icons.check_circle,
            SubjectStatus.inProgress => Icons.play_circle,
            SubjectStatus.failed => Icons.cancel,
            SubjectStatus.locked => Icons.lock,
          },
          trailing: Text(
            switch (sub.status) {
              SubjectStatus.completed => context.tr('studentDetail.subjectCompleted'),
              SubjectStatus.inProgress => context.tr('studentDetail.subjectInProgress'),
              SubjectStatus.failed => context.tr('studentDetail.subjectFailed'),
              SubjectStatus.locked => context.tr('studentDetail.subjectLocked'),
            },
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: switch (sub.status) {
                  SubjectStatus.completed => AppPalette.green,
                  SubjectStatus.inProgress => AppPalette.amber,
                  SubjectStatus.failed => AppPalette.red,
                  SubjectStatus.locked => Colors.grey,
                }),
          ),
          child: Column(children: [
            ScoreBar(value: sub.progressPercent, label: context.tr('studentDetail.lessonsProgressLabel')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _MiniStat(
                    label: context.tr('studentDetail.lessonsLabel'),
                    value: '${sub.completedLessons}/${sub.totalLessons}'),
              ),
              Expanded(
                child: _MiniStat(
                    label: context.tr('studentDetail.quizAverageLabel'),
                    value: sub.quizAverage != null
                        ? '٪${sub.quizAverage!.toStringAsFixed(0)}'
                        : '—'),
              ),
              Expanded(
                child: _MiniStat(
                    label: context.tr('studentDetail.examAverageLabel'),
                    value: sub.examAverage != null
                        ? '٪${sub.examAverage!.toStringAsFixed(0)}'
                        : '—'),
              ),
              Expanded(
                child: _MiniStat(
                    label: context.tr('studentDetail.finalScoreLabel'),
                    value: sub.finalScore != null
                        ? '٪${sub.finalScore!.toStringAsFixed(0)}'
                        : '—'),
              ),
            ]),
          ]),
        ),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ]);
}

// ── Tab 3: حاضری ───────────────────────────────────────────────────────────
class _AttendanceTab extends StatelessWidget {
  final StudentDetail detail;
  const _AttendanceTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    final a = detail.attendance;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(
            child: StatTile(
                icon: Icons.check, value: '${a.presentDays}', label: context.tr('studentDetail.presentDaysLabel'))),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.close,
                value: '${a.absentDays}',
                label: context.tr('studentDetail.absentDaysLabel'),
                color: AppPalette.red)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.percent,
                value: '٪${a.rate.toStringAsFixed(0)}',
                label: context.tr('studentDetail.attendanceRateLabel'),
                color: a.belowThreshold ? AppPalette.red : AppPalette.green)),
      ]),
      const SizedBox(height: 14),
      if (a.belowThreshold)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPalette.red.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppPalette.red.withValues(alpha: .3)),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: AppPalette.red),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('studentDetail.attendanceBelowThresholdWarning'),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
      SectionCard(
        title: context.tr('studentDetail.last30DaysAttendanceTitle'),
        icon: Icons.calendar_month,
        child: AttendanceHeatmap(days: a.last30Days),
      ),
    ]);
  }
}

// ── Tab 4: گزارش استاد هوش مصنوعی ─────────────────────────────────────────
class _AiReportTab extends ConsumerWidget {
  final String studentId;
  const _AiReportTab({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(aiReportProvider(studentId));
    return report.when(
      loading: () => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(context.tr('studentDetail.loadingAiReport')),
        ]),
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (r) => ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
          title: context.tr('studentDetail.statusSummaryTitle'),
          icon: Icons.psychology,
          trailing: Text(
            context.tr('studentDetail.updatedAtLabel', {
              'y': '${r.generatedAt.year}',
              'm': '${r.generatedAt.month}',
              'd': '${r.generatedAt.day}',
            }),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          child: Column(children: [
            ScoreBar(value: r.overallProgress, label: context.tr('studentDetail.overallProgressLabel')),
            const SizedBox(height: 12),
            ScoreBar(value: r.engagementScore, label: context.tr('studentDetail.engagementLabel')),
            const SizedBox(height: 12),
            StressGauge(level: r.stressLevel),
            const SizedBox(height: 12),
            Row(children: [
              Icon(
                switch (r.trend) {
                  Trend.improving => Icons.trending_up,
                  Trend.stable => Icons.trending_flat,
                  Trend.declining => Icons.trending_down,
                },
                color: switch (r.trend) {
                  Trend.improving => AppPalette.green,
                  Trend.stable => Colors.blueGrey,
                  Trend.declining => AppPalette.red,
                },
              ),
              const SizedBox(width: 8),
              Text(
                switch (r.trend) {
                  Trend.improving => context.tr('studentDetail.trendImproving'),
                  Trend.stable => context.tr('studentDetail.trendStable'),
                  Trend.declining => context.tr('studentDetail.trendDeclining'),
                },
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ]),
          ]),
        ),
        if (r.strengths.isNotEmpty)
          SectionCard(
            title: context.tr('studentDetail.strengthsTitle'),
            icon: Icons.star,
            child: _BulletList(items: r.strengths, color: AppPalette.green),
          ),
        if (r.concerns.isNotEmpty)
          SectionCard(
            title: context.tr('studentDetail.concernsTitle'),
            icon: Icons.report_problem_outlined,
            child: _BulletList(items: r.concerns, color: AppPalette.red),
          ),
        if (r.recommendations.isNotEmpty)
          SectionCard(
            title: context.tr('studentDetail.recommendationsTitle'),
            icon: Icons.lightbulb_outline,
            child:
                _BulletList(items: r.recommendations, color: AppPalette.amber),
          ),
        if (r.subjectNotes.isNotEmpty)
          SectionCard(
            title: context.tr('studentDetail.subjectNotesTitle'),
            icon: Icons.menu_book,
            child: Column(
              children: r.subjectNotes
                  .map((n) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppPalette.green.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(n.subjectName,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppPalette.greenDark)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(n.note,
                                      style: const TextStyle(fontSize: 13))),
                            ]),
                      ))
                  .toList(),
            ),
          ),
      ]),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final Color color;
  const _BulletList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: items
            .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 8, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
                  ]),
                ))
            .toList(),
      );
}

// ── Tab 5: گفتگوهای مشاور هوشمند ──────────────────────────────────────────
// رفع اشکال: قبلاً مستقیماً از `AdvisorStore.instance` می‌خواند بدون هیچ
// اتصالی به سرور (چون هیچ‌جا `configure()`/hydrate صدا زده نمی‌شد)؛ اکنون
// از `advisorStoreProvider` (که کلاینت API را تزریق می‌کند) و
// `hydrateForAdmin` برای دریافت تاریخچهٔ واقعی این شاگرد از سرور استفاده
// می‌شود.
class _AdvisorTab extends ConsumerStatefulWidget {
  final String studentId;
  const _AdvisorTab({required this.studentId});

  @override
  ConsumerState<_AdvisorTab> createState() => _AdvisorTabState();
}

class _AdvisorTabState extends ConsumerState<_AdvisorTab> {
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = ref.read(advisorStoreProvider);
    if (store.isLive) {
      store.hydrateForAdmin(widget.studentId).whenComplete(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _loading = false;
    }
  }

  String _time(DateTime d) =>
      '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(advisorStoreProvider);
    final studentId = widget.studentId;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final msgs = store.messagesFor(studentId);
        final hasFlag = store.hasFlagFor(studentId);
        if (msgs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.forum_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(context.tr('studentDetail.noAdvisorChatYet'),
                  style: TextStyle(color: Colors.grey.shade600)),
            ]),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: (hasFlag ? AppPalette.red : AppPalette.green).withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (hasFlag ? AppPalette.red : AppPalette.green).withValues(alpha: .3)),
              ),
              child: Row(children: [
                Icon(hasFlag ? Icons.priority_high_rounded : Icons.volunteer_activism_rounded,
                    color: hasFlag ? AppPalette.red : AppPalette.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasFlag
                        ? context.tr('studentDetail.advisorFlagWarning')
                        : context.tr('studentDetail.advisorHistorySummary', {'count': '${msgs.length}'}),
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ),
              ]),
            ),
            ...msgs.map((m) => _AdvisorBubble(msg: m, time: _time(m.createdAt))),
          ],
        );
      },
    );
  }
}

/// نگاشت کلید موضوع پایدار (`AdvisorMessage.topic`) به برچسب نمایشی — طبق
/// زبان فعال اپ ترجمه می‌شود (همان کلیدهای `advisor.topic*` که در سرویس
/// مشاور هوشمند هم استفاده می‌شوند).
String _advisorTopicLabel(BuildContext context, String topic) => switch (topic) {
      'psychological' => context.tr('advisor.topicPsychological'),
      'family' => context.tr('advisor.topicFamily'),
      'social' => context.tr('advisor.topicSocial'),
      'academic' => context.tr('advisor.topicAcademic'),
      'daily' => context.tr('advisor.topicDaily'),
      'sensitive' => context.tr('advisor.topicSensitive'),
      _ => topic,
    };

class _AdvisorBubble extends StatelessWidget {
  final AdvisorMessage msg;
  final String time;
  const _AdvisorBubble({required this.msg, required this.time});

  @override
  Widget build(BuildContext context) {
    final isStudent = msg.role == AdvisorRole.student;
    final bg = msg.flagged
        ? AppPalette.red.withValues(alpha: .08)
        : (isStudent ? AppPalette.green.withValues(alpha: .10) : Colors.white);
    final border = msg.flagged
        ? AppPalette.red.withValues(alpha: .4)
        : (isStudent ? AppPalette.green.withValues(alpha: .3) : Colors.grey.shade300);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isStudent ? Icons.person_rounded : Icons.volunteer_activism_rounded,
                size: 16, color: isStudent ? AppPalette.greenDark : AppPalette.amber),
            const SizedBox(width: 6),
            Text(isStudent ? context.tr('studentDetail.studentBadge') : context.tr('studentDetail.advisorBadge'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            if (msg.topic.isNotEmpty && msg.topic != 'general')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_advisorTopicLabel(context, msg.topic), style: const TextStyle(fontSize: 10)),
              ),
            if (msg.flagged) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppPalette.red, borderRadius: BorderRadius.circular(8)),
                child: Text(context.tr('studentDetail.needsAttentionBadge'), style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Text(msg.text, style: const TextStyle(fontSize: 13.5, height: 1.6)),
          const SizedBox(height: 6),
          Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ── Tab 6: پیام‌های مدیریت ────────────────────────────────────────────────
// گفتگوی مستقیم «شاگرد ↔ مدیریت» — دقیقاً همان زیرساخت واقعیِ بخش «چت»
// (نه یک انبار جدا)، این‌بار مستقیم داخل پروندهٔ خودِ شاگرد تا مدیر بدون
// رفتن به صندوق ورودی چت هم ببیند و هم پاسخ بدهد (رفع درخواستِ هماهنگی:
// «پیام هر کاربر در جای خودش سیستم شود»). شناسهٔ گفتگو با همان قرارداد
// یکتای سرور (`admin_<userId>`) محاسبه می‌شود.
class _AdminChatTab extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  const _AdminChatTab({required this.userId, required this.userName});

  @override
  ConsumerState<_AdminChatTab> createState() => _AdminChatTabState();
}

class _AdminChatTabState extends ConsumerState<_AdminChatTab> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String get _conversationId => 'admin_${widget.userId}';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _review(PeerMessage message, bool approve) async {
    await ref.read(reviewMessageUseCaseProvider).call(
        ReviewMessageParams(conversationId: _conversationId, messageId: message.id, approve: approve));
    if (!mounted) return;
    ref.invalidate(adminMessagesProvider(_conversationId));
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref
        .read(sendAdminReplyUseCaseProvider)
        .call(SendAdminReplyParams(conversationId: _conversationId, text: text));
    if (!mounted) return;
    ref.invalidate(adminMessagesProvider(_conversationId));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(adminMessagesProvider(_conversationId));
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppPalette.green.withValues(alpha: .08),
          child: Row(children: [
            const Icon(Icons.support_agent_rounded, size: 16, color: AppPalette.greenDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('studentDetail.adminChatHeaderWithName', {'name': widget.userName}),
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ]),
        ),
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('$e')),
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.forum_outlined, size: 54, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(context.tr('studentDetail.noAdminChatYet'),
                        style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(context.tr('studentDetail.sendFirstMessageHint'),
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ]),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) => AdminMessageCard(
                  message: messages[i],
                  onReview: messages[i].isPendingReview ? (approve) => _review(messages[i], approve) : null,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(hintText: context.tr('studentDetail.adminReplyHint')),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: const BoxDecoration(color: AppPalette.greenDark, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _sendReply,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── بخش ارتقا/کاهش صنف (نمای مدیر) ────────────────────────────────────────
// رفع اشکال هماهنگی: این بخش قبلاً فقط انبار محلیِ گوشیِ مدیر
// (ProgressionStore) را می‌خواند و تغییر می‌داد — هرگز روی دیتابیس واقعی
// اثر نمی‌گذاشت، یعنی «ارتقا»یی که مدیر اینجا می‌زد، نه شاگرد در نصاب
// درسی‌اش می‌دید و نه با نصب مجدد باقی می‌ماند. اکنون از دادهٔ واقعیِ
// `StudentDetail` (که خودِ سرور طبق lib/progress.ts::getPromotionStatus
// محاسبه کرده) می‌خواند و اقدام را روی همان سرور اعمال می‌کند.
class _PromotionSection extends ConsumerWidget {
  final String studentId;
  final StudentDetail detail;
  const _PromotionSection({required this.studentId, required this.detail});

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = detail.summary.grade;
    final canPromote = grade < 12;
    final canDemote = grade > 7;
    final busy = ref.watch(studentActionsProvider).isLoading;

    return SectionCard(
      title: context.tr('studentDetail.promotionSectionTitle'),
      icon: Icons.trending_up,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppPalette.green.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(context.tr('studentDetail.currentGradeLabel', {'grade': '$grade'}),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppPalette.greenDark)),
      ),
      child: Column(children: [
        ScoreBar(value: detail.summary.gradeAverage, label: context.tr('studentDetail.subjectsCompletionLabel', {'grade': '$grade'})),
        const SizedBox(height: 12),
        Row(children: [
          Icon(detail.examPassed ? Icons.check_circle : Icons.pending_rounded,
              size: 18, color: detail.examPassed ? AppPalette.green : AppPalette.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail.examBestScore != null
                  ? context.tr('studentDetail.examScoreWithStatus', {
                      'score': detail.examBestScore!.toStringAsFixed(0),
                      'status': detail.examPassed
                          ? context.tr('studentDetail.examPassedParen')
                          : context.tr('studentDetail.examFailedParen'),
                    })
                  : context.tr('studentDetail.examNotTakenYet'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.green),
              onPressed: canPromote && !busy
                  ? () async {
                      final newGrade = await ref.read(studentActionsProvider.notifier).promote(studentId);
                      if (context.mounted) {
                        _snack(context, newGrade != null
                            ? context.tr('studentDetail.promotedToGrade', {'grade': '$newGrade'})
                            : context.tr('studentDetail.promoteFailed'));
                      }
                    }
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text(canPromote ? context.tr('studentDetail.promoteToGrade', {'grade': '${grade + 1}'}) : context.tr('studentDetail.highestGrade')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.red,
                side: BorderSide(color: AppPalette.red.withValues(alpha: .5)),
              ),
              onPressed: canDemote && !busy
                  ? () async {
                      final newGrade = await ref.read(studentActionsProvider.notifier).demote(studentId);
                      if (context.mounted) {
                        _snack(context, newGrade != null
                            ? context.tr('studentDetail.demotedToGrade', {'grade': '$newGrade'})
                            : context.tr('studentDetail.demoteFailed'));
                      }
                    }
                  : null,
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
              label: Text(context.tr('studentDetail.demoteButton')),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(context.tr('studentDetail.manualPromotionNote'),
            style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
      ]),
    );
  }
}
