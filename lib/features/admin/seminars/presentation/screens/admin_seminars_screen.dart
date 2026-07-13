import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/empty_view.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../../shared_models/seminar.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../seminars/presentation/providers/seminars_providers.dart';
import '../../../../seminars/presentation/widgets/go_live_flow.dart';
import '../../../../seminars/presentation/widgets/seminar_editor_dialog.dart';
import '../../domain/usecases/admin_seminars_usecases.dart';
import '../providers/admin_seminars_providers.dart';

/// مدیریت کامل سمینارها برای مدیر ارشد — تمام امکانات: ساخت، ویرایش، حذف،
/// تغییر وضعیت، فیلتر مخاطب (همه/شاگردان/والدین)، پخش زندهٔ واقعی (Cloudflare
/// Stream) و مشاهدهٔ فهرست ثبت‌نامی‌ها (طبق اصلاح ۲.۲ سند: مشارکت مستقیم مدیر).
class AdminSeminarsScreen extends ConsumerStatefulWidget {
  const AdminSeminarsScreen({super.key});

  @override
  ConsumerState<AdminSeminarsScreen> createState() => _AdminSeminarsScreenState();
}

class _AdminSeminarsScreenState extends ConsumerState<AdminSeminarsScreen> {
  /// null = همه؛ در غیر این صورت فقط مخاطب انتخاب‌شده.
  SeminarAudience? _filter;

  @override
  Widget build(BuildContext context) {
    final seminarsAsync = ref.watch(adminSeminarsProvider);

    return AppScaffold(
      title: context.tr('admin.seminars'),
      role: AppUserRole.superAdmin,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr('instructor.createSeminar')),
      ),
      body: seminarsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (all) {
          final studentCount = all.where((s) => s.audience == SeminarAudience.students).length;
          final parentCount = all.where((s) => s.audience == SeminarAudience.parents).length;
          final liveCount = all.where((s) => s.isLiveNow).length;
          final seminars =
              _filter == null ? all : all.where((s) => s.audience == _filter).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminSeminarsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _SummaryHeader(
                  total: all.length,
                  live: liveCount,
                  students: studentCount,
                  parents: parentCount,
                ),
                const SizedBox(height: 14),
                _AudienceFilterBar(
                  current: _filter,
                  all: all.length,
                  students: studentCount,
                  parents: parentCount,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 12),
                if (seminars.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: EmptyView(
                        message: context.tr('instructor.noSeminars'),
                        icon: Icons.groups_outlined),
                  )
                else
                  for (var i = 0; i < seminars.length; i++) ...[
                    _AdminSeminarCard(seminar: seminars[i], index: i),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showSeminarEditorDialog(context, showInstructorField: true);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final created = await ref.read(createAdminSeminarUseCaseProvider).call(
          CreateAdminSeminarParams(
            title: result.title,
            description: result.description,
            instructorName: result.instructorName ?? '',
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
        ref.invalidate(adminSeminarsProvider);
        messenger.showSnackBar(
            SnackBar(content: Text(context.mounted ? context.tr('instructor.created') : '')));
      },
    );
  }
}

/// نوار فیلتر مخاطب — همه / شاگردان / والدین (پویا).
class _AudienceFilterBar extends StatelessWidget {
  final SeminarAudience? current;
  final int all;
  final int students;
  final int parents;
  final ValueChanged<SeminarAudience?> onChanged;

  const _AudienceFilterBar({
    required this.current,
    required this.all,
    required this.students,
    required this.parents,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(context, label: '${context.tr('common.all')} ($all)', value: null),
          const SizedBox(width: 8),
          _chip(context,
              label: '${context.tr('seminars.forStudents')} ($students)',
              value: SeminarAudience.students),
          const SizedBox(width: 8),
          _chip(context,
              label: '${context.tr('seminars.forParents')} ($parents)',
              value: SeminarAudience.parents),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, {required String label, required SeminarAudience? value}) {
    final selected = current == value;
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : scheme.onSurfaceVariant,
      ),
      selectedColor: value == SeminarAudience.parents ? AppColors.green500 : AppColors.orange500,
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide(color: selected ? Colors.transparent : scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
    );
  }
}

/// هدر خلاصهٔ آماری — با تفکیک مخاطب.
class _SummaryHeader extends StatelessWidget {
  final int total;
  final int live;
  final int students;
  final int parents;
  const _SummaryHeader({
    required this.total,
    required this.live,
    required this.students,
    required this.parents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('admin.seminars'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              if (live > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: AppColors.danger, shape: BoxShape.circle),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 500.ms)
                          .then()
                          .fadeOut(duration: 500.ms),
                      const SizedBox(width: 6),
                      Text(
                        '$live ${context.tr('seminars.live')}',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat(context, icon: Icons.groups_rounded, label: context.tr('admin.seminars'), value: total),
              _divider(),
              _stat(context,
                  icon: Icons.school_rounded,
                  label: context.tr('seminars.forStudents'),
                  value: students),
              _divider(),
              _stat(context,
                  icon: Icons.family_restroom_rounded,
                  label: context.tr('seminars.forParents'),
                  value: parents),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0, duration: 350.ms);
  }

  Widget _stat(BuildContext context,
      {required IconData icon, required String label, required int value}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 5),
              Text('$value',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _AdminSeminarCard extends ConsumerWidget {
  final Seminar seminar;
  final int index;
  const _AdminSeminarCard({required this.seminar, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = seminar;
    final live = s.isLiveNow;
    final isParents = s.audience == SeminarAudience.parents;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: live
                      ? const LinearGradient(colors: [Color(0xFFE5484D), Color(0xFFB03038)])
                      : (isParents ? AppColors.successGradient : AppColors.heroGradient),
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
                    Text(s.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(s.instructorName,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: live ? AppColors.danger : scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            context.tr('seminars.status.${s.effectiveStatus.name}'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: live ? Colors.white : scheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isParents ? AppColors.green100 : scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            isParents
                                ? context.tr('seminars.forParents')
                                : context.tr('seminars.forStudents'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isParents ? AppColors.green700 : scheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                        Text(
                          '${s.scheduledStart.year}-${s.scheduledStart.month.toString().padLeft(2, '0')}-${s.scheduledStart.day.toString().padLeft(2, '0')} · ${s.durationMinutes}m',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                        // شمار ثبت‌نامی‌ها — با کلیک، فهرست باز می‌شود.
                        InkWell(
                          onTap: () => _showRegistrants(context, ref),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.how_to_reg_rounded, size: 13, color: scheme.primary),
                              const SizedBox(width: 3),
                              Text(
                                s.capacity != null
                                    ? '${s.registeredCount}/${s.capacity}'
                                    : '${s.registeredCount}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('common.edit'),
                icon: Icon(Icons.edit_rounded, color: scheme.primary, size: 20),
                onPressed: () => _edit(context, ref),
              ),
              IconButton(
                tooltip: context.tr('common.delete'),
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error, size: 20),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          if (!s.hasEnded && s.status != SeminarStatus.draft) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: live ? AppColors.danger : AppColors.green500,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                    onPressed: () => startSeminarLive(context, ref, s,
                        onWentLive: () => ref.invalidate(adminSeminarsProvider)),
                    icon: Icon(live ? Icons.videocam_rounded : Icons.play_circle_rounded, size: 18),
                    label: Text(
                      live
                          ? context.tr('instructor.hostLive')
                          : context.tr('instructor.startSeminar'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () => _showRegistrants(context, ref),
                  icon: const Icon(Icons.people_alt_rounded, size: 18),
                  label: Text('${seminar.registeredCount}'),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 60).ms, duration: 320.ms)
        .slideY(begin: 0.1, end: 0, delay: (index * 60).ms, duration: 320.ms);
  }

  /// نمایش فهرست ثبت‌نامی‌های سمینار در یک شیت پایینی.
  void _showRegistrants(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RegistrantsSheet(seminar: seminar),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showSeminarEditorDialog(
      context,
      existing: seminar,
      showInstructorField: true,
      showStatusField: true,
    );
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(updateAdminSeminarUseCaseProvider).call(
          UpdateAdminSeminarParams(
            id: seminar.id,
            title: result.title,
            description: result.description,
            instructorName: result.instructorName ?? seminar.instructorName,
            scheduledStart: result.scheduledStart,
            durationMinutes: result.durationMinutes,
            status: result.status ?? seminar.status,
            capacity: result.capacity,
            audience: result.audience,
            meetingLink: result.meetingLink,
          ),
        );
    updated.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(adminSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('admin.seminarUpdated') : '')));
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('admin.deleteSeminar')),
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
    final result = await ref.read(deleteAdminSeminarUseCaseProvider).call(seminar.id);
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(adminSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('admin.seminarDeleted') : '')));
      },
    );
  }
}

/// شیت فهرست ثبت‌نامی‌ها — نام کاربران ثبت‌نام‌کرده در سمینار.
class _RegistrantsSheet extends ConsumerWidget {
  final Seminar seminar;
  const _RegistrantsSheet({required this.seminar});

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
            decoration: BoxDecoration(
                color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Icon(Icons.how_to_reg_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('ثبت‌نامی‌های «${seminar.title}»',
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
                  child: Text('خطا در دریافت فهرست: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('هنوز کسی ثبت‌نام نکرده است.'),
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
                      subtitle: Text(_roleLabel(context, r.role)),
                      trailing: _statusBadge(context, r.status),
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

  String _roleLabel(BuildContext context, String role) {
    switch (role) {
      case 'parent':
        return context.tr('seminars.forParents');
      case 'student':
        return context.tr('seminars.forStudents');
      default:
        return role.isEmpty ? '—' : role;
    }
  }

  Widget _statusBadge(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final attended = status == 'attended';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: attended ? AppColors.green100 : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 10.5,
            color: attended ? AppColors.green700 : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}
