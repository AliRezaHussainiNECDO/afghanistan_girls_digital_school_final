/// صفحهٔ جزئیات والد — فرزندان لینک‌شده + پیشرفت زندهٔ هرکدام (منبع واحد
/// `lib/progress.ts`، دقیقاً همان عددی که خودِ شاگرد/والد در داشبورد خودشان
/// می‌بینند). هم‌الگو با `student_detail_screen.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat_monitoring/presentation/widgets/contact_thread_button.dart';
import '../../../user_management/domain/entities/student_entities.dart' show AccountStatus;
import '../../../user_management/presentation/widgets/common_widgets.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../domain/entities/parent_entities.dart';
import '../providers/parent_management_providers.dart';

class ParentDetailScreen extends ConsumerWidget {
  final String parentId;
  const ParentDetailScreen({super.key, required this.parentId});

  String _fmt(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(parentDetailProvider(parentId));

    return Directionality(
      textDirection: TextDirection.rtl,
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
                onPressed: () => ref.invalidate(parentDetailProvider(parentId)),
                icon: const Icon(Icons.refresh),
                label: Text(context.tr('common.retry')),
              ),
            ]),
          ),
          data: (d) => CustomScrollView(slivers: [
            _Header(detail: d),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.55,
                    children: [
                      StatTile(
                          icon: Icons.family_restroom,
                          value: '${d.children.where((c) => c.linkStatus == 'approved').length}',
                          label: context.tr('parentDetail.linkedChildStat')),
                      StatTile(
                          icon: Icons.hourglass_top,
                          value: '${d.children.where((c) => c.linkStatus == 'pending_student_approval').length}',
                          label: context.tr('parentDetail.pendingApprovalStat'),
                          color: AppPalette.amber),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: context.tr('parentDetail.contactInfoTitle'),
                    icon: Icons.badge_outlined,
                    child: Column(children: [
                      _InfoRow(label: context.tr('parentDetail.emailLabel'), value: d.email),
                      _InfoRow(label: context.tr('parentDetail.phoneLabel'), value: d.phone.isEmpty ? context.tr('parentDetail.notRegistered') : d.phone),
                      _InfoRow(label: context.tr('parentDetail.registrationDateLabel'), value: _fmt(d.registeredAt)),
                    ]),
                  ),
                  SectionCard(
                    title: context.tr('parentDetail.linkedChildrenTitle'),
                    icon: Icons.family_restroom,
                    child: d.children.isEmpty
                        ? Text(context.tr('parentDetail.noChildrenLinked'),
                            style: TextStyle(color: Colors.grey.shade600))
                        : Column(
                            children: d.children.map((c) => _ChildTile(child: c)).toList(),
                          ),
                  ),
                  // رفع اشکال هماهنگی: قبلاً هیچ راهی برای والد وجود نداشت
                  // که با مدیریت مکتب پیام‌رسانی کند، و مدیر هم نمی‌توانست
                  // از داخل همین پروندهٔ والد به او پیام بدهد. حالا از همان
                  // زیرساخت واقعی گفتگوی «کاربر ↔ مدیریت» استفاده می‌شود.
                  SectionCard(
                    title: context.tr('parentDetail.adminMessagesTitle'),
                    icon: Icons.support_agent_rounded,
                    child: ContactThreadButton(userId: d.id, userName: d.fullName),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final ParentDetail detail;
  const _Header({required this.detail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 190,
      pinned: true,
      backgroundColor: AppPalette.greenDark,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: context.tr('parentDetail.actionsTooltip'),
          onPressed: () => showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (ctx) => Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ListTile(
                    leading: Icon(detail.status == AccountStatus.suspended
                        ? Icons.check_circle_outline
                        : Icons.block),
                    title: Text(detail.status == AccountStatus.suspended
                        ? ctx.tr('parentDetail.activateAccount')
                        : ctx.tr('parentDetail.suspendAccount')),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final next = detail.status == AccountStatus.suspended
                          ? AccountStatus.active
                          : AccountStatus.suspended;
                      final err = await ref.read(parentActionsProvider.notifier).setStatus(detail.id, next);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err ?? context.tr('parentDetail.statusUpdated'))),
                      );
                    },
                  ),
                ]),
              ),
            ),
          ),
        ),
      ],
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
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
              child: Row(children: [
                Hero(
                  tag: 'parent-avatar-${detail.id}',
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Text(
                      detail.fullName.isNotEmpty ? detail.fullName[0] : '?',
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: AppPalette.greenDark),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(detail.fullName,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      StatusBadge(detail.status),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  final LinkedChild child;
  const _ChildTile({required this.child});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (child.linkStatus) {
      'approved' => (context.tr('parentDetail.childApproved'), AppPalette.green),
      'pending_student_approval' => (context.tr('parentDetail.childPendingApproval'), AppPalette.amber),
      _ => (context.tr('parentDetail.childRejected'), Colors.grey),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('parentDetail.childNameGrade', {'name': child.studentName, 'grade': '${child.grade}'}),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ]),
        if (child.linkStatus == 'approved') ...[
          const SizedBox(height: 10),
          ScoreBar(value: child.progressPercent, label: context.tr('parentDetail.overallProgressLabel')),
          const SizedBox(height: 6),
          Text(context.tr('parentDetail.pointsSummary', {'points': '${child.pointsTotal}', 'level': child.pointsLevelTitleFa}),
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        ],
      ]),
    );
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
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}
