/// صفحهٔ لیست شاگردان — مسیر /admin/users (بخش ۲۴.۴).

library;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/student_entities.dart';
import '../providers/student_management_providers.dart';
import '../widgets/common_widgets.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  static const provinces = [
    'کابل', 'هرات', 'بلخ', 'بامیان', 'دایکندی', 'غزنی', 'ننگرهار', 'بدخشان'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(studentListFilterProvider);
    final students = ref.watch(studentsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: AppPalette.greenDark,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsetsDirectional.only(start: 16, bottom: 14),
              title: const Text('مدیریت شاگردان',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [AppPalette.greenDark, AppPalette.green],
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 52, 16, 0),
                    child: students.maybeWhen(
                      data: (p) => Text(
                        '${p.total} شاگرد ثبت‌شده',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .85), fontSize: 13),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _FilterBar(filter: filter)),
          students.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(studentsProvider)),
            ),
            data: (page) => page.items.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text('شاگردی با این فیلتر یافت نشد')))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _StudentCard(student: page.items[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final StudentListFilter filter;
  const _FilterBar({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(studentListFilterProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(children: [
        TextField(
          onChanged: (v) => notifier.state = filter.copyWith(query: v, page: 1),
          decoration: InputDecoration(
            hintText: 'جستجوی نام شاگرد…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _chip(
              context,
              label: filter.grade == null ? 'صنف' : 'صنف ${filter.grade}',
              selected: filter.grade != null,
              onTap: () async {
                final g = await _pick<int>(context, 'انتخاب صنف',
                    [for (var g = 7; g <= 12; g++) (g, 'صنف $g')]);
                notifier.state = g == null
                    ? filter.copyWith(clearGrade: true, page: 1)
                    : filter.copyWith(grade: g, page: 1);
              },
            ),
            _chip(
              context,
              label: filter.province ?? 'ولایت',
              selected: filter.province != null,
              onTap: () async {
                final p = await _pick<String>(context, 'انتخاب ولایت',
                    [for (final p in StudentListScreen.provinces) (p, p)]);
                notifier.state = p == null
                    ? filter.copyWith(clearProvince: true, page: 1)
                    : filter.copyWith(province: p, page: 1);
              },
            ),
            _chip(
              context,
              label: switch (filter.status) {
                null => 'وضعیت حساب',
                AccountStatus.active => 'فعال',
                AccountStatus.suspended => 'مسدود',
                AccountStatus.pendingVerification => 'در انتظار',
                AccountStatus.deleted => 'حذف‌شده',
              },
              selected: filter.status != null,
              onTap: () async {
                final s = await _pick<AccountStatus>(context, 'وضعیت حساب', [
                  (AccountStatus.active, 'فعال'),
                  (AccountStatus.suspended, 'مسدود'),
                  (AccountStatus.deleted, 'حذف‌شده'),
                ]);
                notifier.state = s == null
                    ? filter.copyWith(clearStatus: true, page: 1)
                    : filter.copyWith(status: s, page: 1);
              },
            ),
            _chip(
              context,
              label: 'در معرض خطر',
              selected: filter.atRiskOnly,
              color: AppPalette.red,
              onTap: () => notifier.state =
                  filter.copyWith(atRiskOnly: !filter.atRiskOnly, page: 1),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _chip(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap,
      Color color = AppPalette.greenDark}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: color.withValues(alpha: .15),
        checkmarkColor: color,
        labelStyle: TextStyle(
            color: selected ? color : AppPalette.ink,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }

  Future<T?> _pick<T>(BuildContext context, String title,
      List<(T, String)> options) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map((o) => ListTile(
                          title: Text(o.$2),
                          onTap: () => Navigator.pop(ctx, o.$1),
                        ))
                    .toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentSummary student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/admin/students/${student.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Hero(
              tag: 'avatar-${student.id}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppPalette.green.withValues(alpha: .15),
                child: Text(
                  student.fullName.characters.first,
                  style: const TextStyle(
                      color: AppPalette.greenDark,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(student.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  StatusBadge(student.status),
                ]),
                const SizedBox(height: 4),
                Text('صنف ${student.grade} • ${student.province}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: ScoreBar(value: student.gradeAverage, label: 'میانگین نمرات')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ScoreBar(value: student.attendanceRate, label: 'حاضری')),
                ]),
                if (student.riskLevel != RiskLevel.none) ...[
                  const SizedBox(height: 8),
                  RiskBadge(student.riskLevel),
                ],
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش دوباره')),
        ]),
      );
}
