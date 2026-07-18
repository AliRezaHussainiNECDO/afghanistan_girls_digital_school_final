/// صفحهٔ لیست والدین — «مدیریت والدین» پنل مدیر، هم‌الگو با
/// `student_list_screen.dart`/`instructor_list_screen.dart`: لیست با جزئیات
/// هر والد؛ کلیک روی هر نام ← صفحهٔ فرزندان لینک‌شده و پیشرفت هرکدام.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../user_management/presentation/widgets/common_widgets.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../domain/entities/parent_entities.dart';
import '../providers/parent_management_providers.dart';

class ParentListScreen extends ConsumerWidget {
  const ParentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(parentListFilterProvider);
    final parents = ref.watch(parentsProvider);

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
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14),
              title: Text(context.tr('parentList.title'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    child: parents.maybeWhen(
                      data: (p) => Text(context.tr('parentList.totalRegistered', {'count': '${p.total}'}),
                          style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13)),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: TextField(
                onChanged: (v) => ref.read(parentListFilterProvider.notifier).state =
                    filter.copyWith(query: v, page: 1),
                decoration: InputDecoration(
                  hintText: context.tr('parentList.searchHint'),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          parents.when(
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(e.toString(), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(parentsProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('common.retry')),
                  ),
                ]),
              ),
            ),
            data: (page) => page.items.isEmpty
                ? SliverFillRemaining(child: Center(child: Text(context.tr('parentList.noParentsFound'))))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: page.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _ParentCard(parent: page.items[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _ParentCard extends StatelessWidget {
  final ParentSummary parent;
  const _ParentCard({required this.parent});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/admin/parents/${parent.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Hero(
              tag: 'parent-avatar-${parent.id}',
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppPalette.green.withValues(alpha: .15),
                child: Text(
                  parent.fullName.isNotEmpty ? parent.fullName[0] : '?',
                  style: const TextStyle(
                      color: AppPalette.greenDark, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(parent.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  StatusBadge(parent.status),
                ]),
                const SizedBox(height: 4),
                Text(parent.email,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _Chip(
                      icon: Icons.family_restroom_rounded,
                      label: context.tr('parentList.linkedChildrenChip', {'count': '${parent.linkedChildrenCount}'}),
                      color: AppPalette.green),
                  if (parent.pendingChildrenCount > 0)
                    _Chip(
                        icon: Icons.hourglass_top_rounded,
                        label: context.tr('parentList.pendingApprovalChip', {'count': '${parent.pendingChildrenCount}'}),
                        color: AppPalette.amber),
                ]),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ]),
      );
}
