import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/student/guardian_link_store.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/email_verification_banner.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../certificates/presentation/screens/my_certificates_screen.dart';
import '../../../curriculum/presentation/widgets/points_badge.dart';
import '../../../curriculum/presentation/widgets/subject_progress_bar.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repository.dart';
import '../providers/parent_providers.dart';

/// ارسال کد دعوت به‌نام والدِ واردشده + بازخورد واضح (بخش ۱۳ب.۲).
/// خروجی: true اگر پیوند موفق بود.
Future<bool> submitGuardianInviteCode(
    BuildContext context, WidgetRef ref, String code) async {
  final parent = ref.read(authSessionProvider);
  final result = await ref.read(submitInviteCodeUseCaseProvider).call(
        SubmitInviteParams(
          parentId: parent?.id ?? 'u-parent-demo',
          parentName: parent?.displayName ?? '',
          code: code,
        ),
      );
  if (!context.mounted) return false;
  return result.fold(
    (f) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(f.message), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return false;
    },
    (childName) {
      // اصلاح ۲.۴ (بخش ۱۳ب.۲): پیوند بلافاصله فعال نمی‌شود — ابتدا باید
      // خود شاگرد آن را در پروفایلش تأیید کند.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'درخواست پیوند با «$childName» ثبت شد؛ پس از تأیید فرزندتان در اپ خودش، به فهرست فرزندان اضافه می‌شود')),
      );
      // GuardianLinkStore خودش notifyListeners می‌کند؛ لیست فرزندان و
      // نمرات خودکار بازسازی می‌شوند.
      return true;
    },
  );
}

/// دیالوگ «افزودن فرزند دیگر» — والدِ دارای فرزند هم می‌تواند کد فرزند
/// بعدی را وارد کند (بخش ۱۳ب.۲: والد می‌تواند کد جدید/فرزند دیگر وارد کند).
Future<void> showAddChildDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.tr('parent.linkChild')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: dialogContext.tr('parent.inviteCodeHint'),
              prefixIcon: const Icon(Icons.qr_code_rounded),
              helperText: 'کد ۶ رقمی که فرزندتان از بخش پروفایل خود ساخته است',
              helperMaxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await submitGuardianInviteCode(context, ref, controller.text);
            if (ok && dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: Text(dialogContext.tr('common.submit')),
        ),
      ],
    ),
  );
}

/// طبق بخش ۱۳ب سند: فقط‌خواندنی، Aggregate-level؛ اگر هیچ فرزند لینک‌شده‌ای
/// نباشد، فرم «کد دعوت» نمایش داده می‌شود (بخش ۱۳ب.۲: AWAITING_LINK).
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(linkedChildrenProvider);

    return AppScaffold(
      title: context.tr('nav.parentDashboard'),
      role: AppUserRole.parent,
      body: Column(
        children: [
          // بنر تأیید ایمیل — تا زمانی که والد ایمیلش را تأیید نکرده.
          const EmailVerificationBanner(),
          Expanded(child: _buildBody(childrenAsync)),
        ],
      ),
    );
  }

  Widget _buildBody(AsyncValue<List<LinkedChild>> childrenAsync) {
    return childrenAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (children) {
          // درخواست‌های در انتظار تأیید فرزند (اصلاح ۲.۴ — بخش ۱۳ب.۲):
          // watch روی Store باعث بازسازی خودکار پس از تأیید/رد شاگرد می‌شود.
          final store = ref.watch(guardianLinkStoreProvider);
          final parent = ref.watch(authSessionProvider);
          final pending = store.pendingChildrenOf(parent?.id ?? 'u-parent-demo');

          if (children.isEmpty) {
            return Column(
              children: [
                if (pending.isNotEmpty) _PendingLinksBanner(pending: pending),
                Expanded(
                  child: _AwaitingLinkView(
                    onSubmitted: () => ref.invalidate(linkedChildrenProvider),
                  ),
                ),
              ],
            );
          }
          // اگر فرزند انتخاب‌شده دیگر در لیست نیست (یا اولین بار است)،
          // اولین فرزند انتخاب می‌شود.
          if (_selectedChildId == null ||
              !children.any((c) => c.studentId == _selectedChildId)) {
            _selectedChildId = children.first.studentId;
          }
          return Column(
            children: [
              if (pending.isNotEmpty) _PendingLinksBanner(pending: pending),
              // ── انتخاب فرزند + افزودن فرزند دیگر (بخش ۱۳ب.۵) ──
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final scheme = Theme.of(context).colorScheme;
                    if (i == children.length) {
                      // چیپ «افزودن فرزند»: والد کد دعوت فرزند بعدی را
                      // وارد می‌کند — هر فرزند کد جداگانهٔ خودش را دارد.
                      return ActionChip(
                        avatar: Icon(Icons.add_rounded, size: 18, color: scheme.primary),
                        label: Text(context.tr('parent.linkChild')),
                        labelStyle: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                        side: BorderSide(color: scheme.primary.withValues(alpha: 0.5)),
                        onPressed: () => showAddChildDialog(context, ref),
                      );
                    }
                    final c = children[i];
                    final selected = c.studentId == _selectedChildId;
                    return ChoiceChip(
                      label: Text(c.displayName),
                      selected: selected,
                      avatar: CircleAvatar(
                        radius: 11,
                        backgroundColor: selected ? Colors.white24 : scheme.primaryContainer,
                        child: Text(
                          c.displayName.isNotEmpty ? c.displayName.substring(0, 1) : '?',
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : scheme.onSurface),
                      onSelected: (_) => setState(() => _selectedChildId = c.studentId),
                    );
                  },
                ),
              ),
              // ── گواهی‌نامه‌های فرزند: مشاهده و دانلود توسط والدین ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    onTap: () {
                      final child = children
                          .firstWhere((c) => c.studentId == _selectedChildId);
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MyCertificatesScreen(
                          studentId: child.studentId,
                          studentName: child.displayName,
                          parentMode: true,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFB8860B),
                                Color(0xFFDDB65C)
                              ]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.workspace_premium_rounded,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('گواهی‌نامه‌های فرزندم',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5)),
                          ),
                          Icon(Icons.chevron_left_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _ChildSummaryView(studentId: _selectedChildId!)),
            ],
          );
        },
    );
  }
}

/// بنر درخواست‌های پیوندِ هنوز تأییدنشده توسط فرزند (اصلاح ۲.۴ —
/// بخش ۱۳ب.۲: LINK_PENDING_STUDENT_APPROVAL). فقط اطلاع‌رسانی است؛
/// تأیید/رد در دست خود شاگرد (پروفایل او) است.
class _PendingLinksBanner extends StatelessWidget {
  final List<ParentStudentLink> pending;
  const _PendingLinksBanner({required this.pending});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, size: 20, color: scheme.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${context.tr('parent.pendingApproval')}: '
              '${pending.map((l) => '«${l.studentName}»').join('، ')} — '
              'فرزندتان باید درخواست را از بخش پروفایل خود تأیید کند.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurface, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingLinkView extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _AwaitingLinkView({required this.onSubmitted});

  @override
  ConsumerState<_AwaitingLinkView> createState() => _AwaitingLinkViewState();
}

class _AwaitingLinkViewState extends ConsumerState<_AwaitingLinkView> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.green,
                ),
                child: const Icon(Icons.family_restroom_rounded, size: 42, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(context.tr('parent.linkChild'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: context.tr('parent.inviteCodeHint'),
                        prefixIcon: const Icon(Icons.qr_code_rounded),
                        helperText: 'فرزند شما این کد ۶ رقمی را از «پروفایل ← ساخت کد دعوت برای والدین» می‌سازد',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: context.tr('common.submit'),
                      loading: _submitting,
                      gradient: AppColors.successGradient,
                      onPressed: () async {
                        setState(() => _submitting = true);
                        final ok = await submitGuardianInviteCode(
                            context, ref, _controller.text.trim());
                        if (!mounted) return;
                        setState(() => _submitting = false);
                        if (ok) {
                          _controller.clear();
                          widget.onSubmitted();
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(context.tr('parent.pendingApproval'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildSummaryView extends ConsumerWidget {
  final String studentId;
  const _ChildSummaryView({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(childSummaryProvider(studentId));
    final scheme = Theme.of(context).colorScheme;
    return summaryAsync.when(
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(message: e.toString()),
      data: (s) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.successGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              boxShadow: AppShadows.green,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.displayName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('${context.tr('common.grade')} ${s.gradeNumber}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                      const SizedBox(height: 10),
                      Text('${context.tr('parent.attendance')}: ${s.attendanceRatePercent.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      // ── امتیاز فعالیت (Gamification) — همان منبع داشبورد شاگرد ──
                      PointsBadge(
                        pointsTotal: s.pointsTotal,
                        pointsLevel: s.pointsLevel,
                        pointsLevelTitleFa: s.pointsLevelTitleFa,
                        light: true,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 68,
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: s.gradeCompletionPercent / 100,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      Text('${s.gradeCompletionPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: context.tr('parent.grades')),
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (int i = 0; i < s.subjects.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 56, color: scheme.outlineVariant),
                  _SubjectRow(subject: s.subjects[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionLabel(text: context.tr('parent.achievements')),
          if (s.achievements.isEmpty)
            _EmptyHint(text: 'هنوز دستاوردی ثبت نشده است — با اولین امتحان، اولین نشان ظاهر می‌شود')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.achievements
                  .map((a) => Chip(
                        label: Text(a),
                        avatar: Icon(Icons.emoji_events_rounded, size: 16, color: scheme.tertiary),
                        backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.4),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          _SectionLabel(text: context.tr('parent.certificates')),
          if (s.certificates.isEmpty)
            _EmptyHint(text: 'گواهی‌نامه پس از ختم موفقانهٔ صنف توسط مدیریت صادر می‌شود')
          else
            ...s.certificates.map((c) => ListTile(
                  dense: true,
                  leading: Icon(Icons.workspace_premium_rounded, color: scheme.tertiary),
                  title: Text(c),
                )),
          const SizedBox(height: 16),
          _SectionLabel(text: context.tr('parent.upcomingSeminars')),
          ...s.upcomingSeminarTitles.map((t) => ListTile(
                dense: true,
                leading: Icon(Icons.groups_rounded, color: scheme.secondary),
                title: Text(t),
              )),
        ],
      ),
    );
  }
}

/// یک ردیف مضمون در گزارش والدین — نام مضمون + وضعیت (تکمیل/در حال
/// پیشرفت/قفل) + نمرهٔ نهایی. طبق بخش ۱۳ب.۳ سند، همهٔ مضامین فرزند
/// نمایش داده می‌شوند نه فقط چند مضمون.
class _SubjectRow extends StatelessWidget {
  final ChildSubjectSummary subject;
  const _SubjectRow({required this.subject});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusInfo(context, subject.statusLabel, scheme);
    final locked = subject.statusLabel == 'locked';
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: locked
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        child: Icon(
          locked ? Icons.lock_rounded : Icons.menu_book_rounded,
          size: 16,
          color: locked ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
        ),
      ),
      title: Text(subject.subjectNameFa,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: status.$2, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(status.$1,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
            // ── نوار پیشرفت درسی — همان منطق واحد بخش فصل‌های شاگرد ──
            if (!locked && subject.progressPercent != null) ...[
              const SizedBox(height: 6),
              SubjectProgressBar(percent: subject.progressPercent!, compact: true),
            ],
          ],
        ),
      ),
      isThreeLine: !locked && subject.progressPercent != null,
      trailing: Text(
        subject.finalScore != null
            ? '${subject.finalScore!.toStringAsFixed(0)}%'
            : '—',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: subject.finalScore == null
              ? scheme.onSurfaceVariant
              : (subject.finalScore! >= 60 ? scheme.primary : scheme.error),
        ),
      ),
    );
  }

  /// (برچسب فارسی، رنگ) برای هر وضعیت.
  (String, Color) _statusInfo(
      BuildContext context, String status, ColorScheme scheme) {
    switch (status) {
      case 'completed':
        return (context.tr('parent.statusCompleted'), scheme.primary);
      case 'locked':
        return (context.tr('parent.statusLocked'), scheme.onSurfaceVariant);
      case 'in_progress':
      default:
        return (context.tr('parent.statusInProgress'), scheme.tertiary);
    }
  }
}

/// پیام ملایم برای بخش‌های خالی (دستاورد/گواهی‌نامهٔ هنوز صادرنشده).
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.7)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
