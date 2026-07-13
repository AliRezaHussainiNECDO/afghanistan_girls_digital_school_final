import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared_models/seminar.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../seminars/presentation/widgets/go_live_flow.dart';
import '../../../seminars/presentation/widgets/seminar_editor_dialog.dart';
import '../../domain/usecases/instructor_usecases.dart';
import '../providers/instructor_providers.dart';

/// پنل استاد سمینار: ساخت/ویرایش/حذف سمینار + شروع و برگزاری ویدیو کنفرانس.
/// طبق بخش ۱۲ و ۱۹.۸ سند.
class InstructorHomeScreen extends ConsumerWidget {
  const InstructorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seminarsAsync = ref.watch(myInstructorSeminarsProvider);

    return AppScaffold(
      title: context.tr('instructor.mySeminars'),
      role: AppUserRole.seminarInstructor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createSeminar(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.tr('instructor.createSeminar')),
      ),
      body: Column(
        children: [
          // بنر تأیید ایمیل — تا زمانی که استاد ایمیلش را تأیید نکرده.
          const EmailVerificationBanner(),
          Expanded(
            child: seminarsAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(message: e.toString()),
              data: (seminars) {
                if (seminars.isEmpty) {
                  return EmptyView(
                    message: context.tr('instructor.noSeminars'),
                    icon: Icons.groups_outlined,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(myInstructorSeminarsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: seminars.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) =>
                        _InstructorSeminarCard(seminar: seminars[i], index: i),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSeminar(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authSessionProvider);
    if (user == null) return;
    final result = await showSeminarEditorDialog(context);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final created = await ref.read(createSeminarUseCaseProvider).call(
          CreateSeminarParams(
            instructorId: user.id,
            instructorName: user.displayName,
            title: result.title,
            description: result.description,
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
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(
          SnackBar(content: Text(context.mounted ? context.tr('instructor.created') : '')),
        );
      },
    );
  }
}

class _InstructorSeminarCard extends ConsumerWidget {
  final Seminar seminar;
  final int index;
  const _InstructorSeminarCard({required this.seminar, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = seminar;
    final live = s.isLiveNow;
    final canHost = !s.hasEnded && s.status != SeminarStatus.draft;

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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: live
                      ? const LinearGradient(
                          colors: [Color(0xFFE5484D), Color(0xFFB03038)])
                      : (s.audience == SeminarAudience.parents
                          ? AppColors.successGradient
                          : AppColors.heroGradient),
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
                    Text(s.title,
                        style:
                            const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _StatusChip(status: s.effectiveStatus),
                        _MiniChip(
                          icon: Icons.calendar_month_rounded,
                          label:
                              '${s.scheduledStart.year}-${_two(s.scheduledStart.month)}-${_two(s.scheduledStart.day)} ${_two(s.scheduledStart.hour)}:${_two(s.scheduledStart.minute)}',
                        ),
                        _MiniChip(
                          icon: Icons.schedule_rounded,
                          label: '${s.durationMinutes}m',
                        ),
                        _MiniChip(
                          icon: Icons.how_to_reg_rounded,
                          label: s.capacity != null
                              ? '${s.registeredCount}/${s.capacity}'
                              : '${s.registeredCount}',
                        ),
                        _MiniChip(
                          icon: s.audience == SeminarAudience.parents
                              ? Icons.family_restroom_rounded
                              : Icons.school_rounded,
                          label: s.audience == SeminarAudience.parents
                              ? context.tr('seminars.forParents')
                              : context.tr('seminars.forStudents'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _edit(context, ref);
                    case 'delete':
                      _confirmDelete(context, ref);
                    case 'end':
                      _setStatus(context, ref, SeminarStatus.ended);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Text(context.tr('common.edit')),
                    ]),
                  ),
                  if (live)
                    PopupMenuItem(
                      value: 'end',
                      child: Row(children: [
                        const Icon(Icons.stop_circle_rounded,
                            size: 18, color: AppColors.danger),
                        const SizedBox(width: 10),
                        Text(context.tr('room.endSeminar')),
                      ]),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
                      const SizedBox(width: 10),
                      Text(context.tr('common.delete')),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          if (canHost) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: live ? AppColors.danger : AppColors.green500,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                onPressed: () => _startLive(context, ref),
                icon: Icon(
                  live ? Icons.videocam_rounded : Icons.play_circle_rounded,
                  size: 18,
                ),
                label: Text(
                  live
                      ? context.tr('instructor.hostLive')
                      : context.tr('instructor.startSeminar'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(delay: (index * 70).ms, duration: 350.ms)
        .slideY(begin: 0.1, end: 0, delay: (index * 70).ms, duration: 350.ms);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// شروع/میزبانی پخش زنده — از جریان مشترک `startSeminarLive` استفاده می‌کند
  /// (go-live روی Cloudflare Stream، انتخاب پخش درون‌اپ/OBS، و برگشت امن).
  Future<void> _startLive(BuildContext context, WidgetRef ref) {
    return startSeminarLive(context, ref, seminar,
        onWentLive: () => ref.invalidate(myInstructorSeminarsProvider));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showSeminarEditorDialog(context, existing: seminar);
    if (result == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final updated = await ref.read(updateSeminarUseCaseProvider).call(
          UpdateSeminarParams(
            id: seminar.id,
            title: result.title,
            description: result.description,
            scheduledStart: result.scheduledStart,
            durationMinutes: result.durationMinutes,
            capacity: result.capacity,
            audience: result.audience,
            meetingLink: result.meetingLink,
          ),
        );
    updated.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('instructor.updated') : '')));
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('instructor.deleteSeminar')),
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
    final result = await ref.read(deleteSeminarUseCaseProvider).call(seminar.id);
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(myInstructorSeminarsProvider);
        messenger.showSnackBar(SnackBar(
            content: Text(context.mounted ? context.tr('instructor.deleted') : '')));
      },
    );
  }

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, SeminarStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(setSeminarStatusUseCaseProvider)
        .call(SetSeminarStatusParams(id: seminar.id, status: status));
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) => ref.invalidate(myInstructorSeminarsProvider),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SeminarStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = status == SeminarStatus.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? AppColors.danger : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        context.tr('seminars.status.${status.name}'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isLive ? Colors.white : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

