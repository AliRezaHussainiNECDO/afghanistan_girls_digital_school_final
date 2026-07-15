/// صفحهٔ جزئیات شاگرد — تب‌ها: نمای کلی / پیشرفت / حاضری / گزارش استاد AI.
/// اکشن‌های مدیر (مسدودسازی، حذف، ریست رمز، …) از Registry توسعه‌پذیر.

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../advisor/data/advisor_store.dart';
import '../../../../advisor/domain/advisor_entities.dart';
import '../../../../progression/data/progression_store.dart';
import '../../../../certificates/presentation/widgets/admin_certificates_section.dart';
import '../../domain/entities/student_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/admin_actions_sheet.dart';
import '../widgets/common_widgets.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;
  const StudentDetailScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(studentDetailProvider(studentId));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 5,
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
                  label: const Text('تلاش دوباره'),
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
          tooltip: 'اکشن‌های مدیریتی',
          onPressed: () => showAdminActionsSheet(context, ref, detail),
        ),
      ],
      bottom: const TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(text: 'نمای کلی'),
          Tab(text: 'پیشرفت درسی'),
          Tab(text: 'حاضری'),
          Tab(text: 'گزارش استاد AI'),
          Tab(text: 'مشاور هوشمند'),
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
                            'صنف ${s.grade} • ${s.province} • رتبه ${detail.classRank} از ${detail.classSize}',
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
              label: 'میانگین نمرات'),
          StatTile(
              icon: Icons.event_available,
              value: '٪${s.attendanceRate.toStringAsFixed(0)}',
              label: 'نرخ حاضری',
              color: s.attendanceRate >= 75 ? AppPalette.green : AppPalette.red),
          StatTile(
              icon: Icons.quiz,
              value: '${detail.examsTaken}',
              label: 'امتحانات سپری‌شده',
              color: Colors.indigo),
          StatTile(
              icon: Icons.workspace_premium,
              value: '${detail.certificatesCount}',
              label: 'گواهی‌نامه‌ها',
              color: AppPalette.amber),
        ],
      ),
      const SizedBox(height: 14),
      _PromotionSection(studentId: s.id, grade: s.grade),
      const SizedBox(height: 14),
      SectionCard(
        title: 'معلومات شخصی',
        icon: Icons.badge_outlined,
        child: Column(children: [
          _InfoRow(label: 'ایمیل', value: detail.email),
          _InfoRow(label: 'شماره تلفن', value: detail.phone),
          _InfoRow(label: 'تاریخ تولد', value: _fmt(detail.birthDate)),
          _InfoRow(label: 'تاریخ ثبت‌نام', value: _fmt(detail.registeredAt)),
          _InfoRow(
              label: 'آخرین فعالیت',
              value: s.lastActiveAt != null
                  ? _fmt(s.lastActiveAt!)
                  : 'نامشخص'),
          _InfoRow(
              label: 'گفتگو با استاد AI',
              value: '${detail.aiConversationsCount} پیام'),
          _InfoRow(
              label: 'گفتگو با مشاور هوشمند',
              value: '${AdvisorStore.instance.messagesFor(s.id).length} پیام'),
        ]),
      ),
      // ── گواهی‌نامه‌ها: ارسال پس از ختم هر صنف + لیست ارسال‌شده‌ها ──
      AdminCertificatesSection(detail: detail),
      SectionCard(
        title: 'والدین / سرپرست',
        icon: Icons.family_restroom,
        child: detail.parentLinks.isEmpty
            ? Text('هیچ والدی لینک نشده است',
                style: TextStyle(color: Colors.grey.shade600))
            : Column(
                children: detail.parentLinks
                    .map((p) => _InfoRow(
                        label: p.parentName,
                        value: switch (p.linkStatus) {
                          'approved' => 'تأییدشده',
                          'pending_student_approval' => 'در انتظار تأیید شاگرد',
                          _ => 'ردشده',
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
              SubjectStatus.completed => 'تکمیل‌شده',
              SubjectStatus.inProgress => 'در جریان',
              SubjectStatus.failed => 'ناکام',
              SubjectStatus.locked => 'قفل',
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
            ScoreBar(value: sub.progressPercent, label: 'پیشرفت دروس'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _MiniStat(
                    label: 'دروس',
                    value: '${sub.completedLessons}/${sub.totalLessons}'),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'میانگین کوییز',
                    value: sub.quizAverage != null
                        ? '٪${sub.quizAverage!.toStringAsFixed(0)}'
                        : '—'),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'میانگین امتحان',
                    value: sub.examAverage != null
                        ? '٪${sub.examAverage!.toStringAsFixed(0)}'
                        : '—'),
              ),
              Expanded(
                child: _MiniStat(
                    label: 'نمره نهایی',
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
                icon: Icons.check, value: '${a.presentDays}', label: 'روز حاضر')),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.close,
                value: '${a.absentDays}',
                label: 'روز غایب',
                color: AppPalette.red)),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                icon: Icons.percent,
                value: '٪${a.rate.toStringAsFixed(0)}',
                label: 'نرخ حاضری',
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
          child: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: AppPalette.red),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'نرخ حاضری زیر آستانهٔ ۷۵٪ است — طبق تشخیص سیستم، در معرض محرومیت از امتحان نهایی قرار دارد.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ),
      SectionCard(
        title: 'حاضری ۳۰ روز اخیر',
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
      loading: () => const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('در حال دریافت گزارش استاد هوش مصنوعی…'),
        ]),
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (r) => ListView(padding: const EdgeInsets.all(16), children: [
        SectionCard(
          title: 'خلاصهٔ وضعیت',
          icon: Icons.psychology,
          trailing: Text(
            'به‌روزرسانی: ${r.generatedAt.year}/${r.generatedAt.month}/${r.generatedAt.day}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          child: Column(children: [
            ScoreBar(value: r.overallProgress, label: 'سطح پیشرفت کلی'),
            const SizedBox(height: 12),
            ScoreBar(value: r.engagementScore, label: 'میزان تعامل با استاد AI'),
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
                  Trend.improving => 'روند کلی: در حال بهبود',
                  Trend.stable => 'روند کلی: ثابت',
                  Trend.declining => 'روند کلی: در حال افت',
                },
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ]),
          ]),
        ),
        if (r.strengths.isNotEmpty)
          SectionCard(
            title: 'نقاط قوت',
            icon: Icons.star,
            child: _BulletList(items: r.strengths, color: AppPalette.green),
          ),
        if (r.concerns.isNotEmpty)
          SectionCard(
            title: 'مشکلات و نگرانی‌ها',
            icon: Icons.report_problem_outlined,
            child: _BulletList(items: r.concerns, color: AppPalette.red),
          ),
        if (r.recommendations.isNotEmpty)
          SectionCard(
            title: 'پیشنهادهای استاد AI به مدیر',
            icon: Icons.lightbulb_outline,
            child:
                _BulletList(items: r.recommendations, color: AppPalette.amber),
          ),
        if (r.subjectNotes.isNotEmpty)
          SectionCard(
            title: 'یادداشت به تفکیک مضمون',
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
class _AdvisorTab extends StatelessWidget {
  final String studentId;
  const _AdvisorTab({required this.studentId});

  String _time(DateTime d) =>
      '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final store = AdvisorStore.instance;
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
              Text('این شاگرد هنوز با مشاور هوشمند گفتگو نکرده است',
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
                        ? 'در این گفتگو نشانهٔ نگرانی وجود دارد — لطفاً با دقت و حمایت بازبینی شود.'
                        : 'تاریخچهٔ گفتگوی شاگرد با مشاور هوشمند (${msgs.length} پیام).',
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
            Text(isStudent ? 'شاگرد' : 'مشاور',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const Spacer(),
            if (msg.topic.isNotEmpty && msg.topic != 'عمومی')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(msg.topic, style: const TextStyle(fontSize: 10)),
              ),
            if (msg.flagged) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppPalette.red, borderRadius: BorderRadius.circular(8)),
                child: const Text('نیازمند توجه', style: TextStyle(fontSize: 10, color: Colors.white)),
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

// ── بخش ارتقا/کاهش صنف (نمای مدیر) ────────────────────────────────────────
class _PromotionSection extends StatelessWidget {
  final String studentId;
  final int grade;
  const _PromotionSection({required this.studentId, required this.grade});

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final store = ProgressionStore.instance;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final p = store.progressFor(studentId, fallbackGrade: grade);
        final canPromote = p.currentGrade < 12;
        final canDemote = p.currentGrade > p.enrolledGrade && p.currentGrade > 7;
        return SectionCard(
          title: 'ارتقا / کاهش صنف',
          icon: Icons.trending_up,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppPalette.green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('صنف فعلی: ${p.currentGrade}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppPalette.greenDark)),
          ),
          child: Column(children: [
            ScoreBar(value: p.overallCompletion, label: 'تکمیل مضامین صنف ${p.currentGrade}'),
            const SizedBox(height: 12),
            Row(children: [
              Icon(p.examPassed ? Icons.check_circle : Icons.pending_rounded,
                  size: 18, color: p.examPassed ? AppPalette.green : AppPalette.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.examTaken
                      ? 'امتحان: ٪${p.examScore.toStringAsFixed(0)} ${p.examPassed ? '(کامیاب)' : '(ناکام)'}'
                      : 'امتحان: هنوز داده نشده',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppPalette.green),
                  onPressed: canPromote
                      ? () {
                          final target = p.currentGrade + 1;
                          store.promote(studentId);
                          _snack(context, 'به صنف $target ارتقا یافت');
                        }
                      : null,
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  label: Text(canPromote ? 'ارتقا به صنف ${p.currentGrade + 1}' : 'بالاترین صنف'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.red,
                    side: BorderSide(color: AppPalette.red.withValues(alpha: .5)),
                  ),
                  onPressed: canDemote
                      ? () {
                          final target = p.currentGrade - 1;
        