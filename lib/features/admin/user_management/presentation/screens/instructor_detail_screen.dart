/// صفحهٔ جزئیات/فعالیت‌های یک استاد — از دید مدیر (بخش ۱۵.۲ سند).
///
/// «هر چه داشبورد استاد می‌بیند، مدیر همان را می‌بیند + کنترل کامل»:
/// فعالیت‌ها از همان منبع واحد حقیقت داشبورد استاد (بک‌اند واقعی —
/// `GET /seminars?instructor=`) خوانده می‌شوند و مدیر روی همهٔ داده‌ها کنترل
/// کامل دارد — مسدود/فعال‌سازی حساب (`PATCH /admin/users/:id/toggle-suspend`)،
/// تغییر وضعیت هر سمینار (State Machine بخش ۱۲.۲، `PATCH /seminars/:id/status`)
/// و حذف سمینار — همه از طریق بک‌اند واقعی وقتی `kUseLiveBackend` فعال است.

library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/instructor/instructor_directory.dart';
import '../../../../../core/instructor/instructor_invite_store.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../shared_models/seminar.dart';
import '../../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../../../instructor/presentation/providers/instructor_providers.dart';
import '../../../seminars/domain/usecases/admin_seminars_usecases.dart';
import '../../../seminars/presentation/providers/admin_seminars_providers.dart';
import '../widgets/common_widgets.dart';

class InstructorDetailScreen extends ConsumerStatefulWidget {
  final String instructorId;
  const InstructorDetailScreen({super.key, required this.instructorId});

  @override
  ConsumerState<InstructorDetailScreen> createState() => _InstructorDetailScreenState();
}

class _InstructorDetailScreenState extends ConsumerState<InstructorDetailScreen> {
  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _fmt(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';

  static (String, Color) _statusView(Seminar s) => switch (s.effectiveStatus) {
        SeminarStatus.draft => ('پیش‌نویس', Colors.blueGrey),
        SeminarStatus.published => ('منتشرشده', AppPalette.green),
        SeminarStatus.registrationClosed => ('ثبت‌نام بسته', AppPalette.amber),
        SeminarStatus.live => ('زنده', AppPalette.red),
        SeminarStatus.ended => ('پایان‌یافته', Colors.grey),
        SeminarStatus.archived => ('آرشیو', Colors.grey),
      };

  @override
  void initState() {
    super.initState();
    // در حالت Backend واقعی، فهرست واقعی استادان را از سرور می‌گیریم —
    // به‌جای دادهٔ نمایشی محلی (بخش ۱۵.۲ سند)، همان الگوی صفحهٔ لیست استادان.
    if (kUseLiveBackend && !InstructorDirectory.instance.loadedFromBackend) {
      Future.microtask(
          () => InstructorDirectory.instance.loadFromBackend(ref.read(apiClientProvider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: InstructorDirectory.instance,
        builder: (context, _) {
          if (kUseLiveBackend && !InstructorDirectory.instance.loadedFromBackend) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final instructor =
              InstructorDirectory.instance.byId(widget.instructorId);
          if (instructor == null) {
            return const Scaffold(
                body: Center(child: Text('استاد یافت نشد')));
          }
          // آمار فعالیت از همان منبع واحد حقیقت سمینارها — در حالت Backend
          // واقعی مستقیماً از سرور، تا «هر چه داشبورد استاد می‌بیند، مدیر
          // همان را ببیند» واقعاً درست باشد.
          final seminarsAsync = ref.watch(seminarsByInstructorProvider(instructor.id));
          final seminars = seminarsAsync.valueOrNull ?? const <Seminar>[];
          final liveCount = seminars.where((s) => s.isLiveNow).length;
          final endedCount = seminars.where((s) => s.hasEnded).length;
          final upcoming = seminars.length - liveCount - endedCount;
          final totalRegistrations =
              seminars.fold<int>(0, (sum, s) => sum + s.registeredCount);

          // کد دعوتی که این استاد با آن راجستر شده (قابلیت بازبینی —
          // بخش ۱.۲ سند)؛ برای استادان Seed نمایشی ممکن است وجود نداشته باشد.
          InstructorInviteCode? usedCode;
          for (final c in InstructorInviteStore.instance.codes) {
            if (c.usedByEmail == instructor.email) {
              usedCode = c;
              break;
            }
          }

          return Scaffold(
            backgroundColor: AppPalette.surface,
            body: CustomScrollView(slivers: [
              SliverAppBar(
                expandedHeight: 170,
                pinned: true,
                backgroundColor: AppPalette.greenDark,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsetsDirectional.only(start: 52, bottom: 14),
                  title: Text(instructor.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [AppPalette.greenDark, AppPalette.green],
                      ),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                        child: Row(children: [
                          Hero(
                            tag: 'instructor-avatar-${instructor.id}',
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withValues(alpha: .2),
                              child: Text(
                                instructor.fullName.characters.first,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              instructor.specialty,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .9),
                                  fontSize: 12.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── معلومات حساب + کنترل مسدودسازی (کنترل کامل مدیر) ──
                    _Card(children: [
                      _InfoRow(icon: Icons.mail_rounded, label: 'ایمیل', value: instructor.email),
                      if (instructor.phone.isNotEmpty)
                        _InfoRow(icon: Icons.phone_rounded, label: 'تلفن', value: instructor.phone),
                      _InfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'تاریخ عضویت',
                          value: _fmt(instructor.joinedAt)),
                      if (instructor.bio.isNotEmpty)
                        _InfoRow(icon: Icons.info_rounded, label: 'معرفی', value: instructor.bio),
                      if (usedCode != null)
                        _InfoRow(
                            icon: Icons.qr_code_rounded,
                            label: 'کد دعوت مصرف‌شده',
                            value:
                                '${usedCode.code} (${usedCode.label})'),
                      const Divider(height: 20),
                      Row(children: [
                        Icon(
                            instructor.suspended
                                ? Icons.block_rounded
                                : Icons.verified_user_rounded,
                            size: 20,
                            color: instructor.suspended
                                ? AppPalette.red
                                : AppPalette.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            instructor.suspended
                                ? 'حساب مسدود است — استاد نمی‌تواند وارد شود یا سمینار بسازد'
                                : 'حساب فعال است',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Switch(
                          value: !instructor.suspended,
                          activeThumbColor: AppPalette.green,
                          onChanged: (active) async {
                            if (kUseLiveBackend) {
                              final ok = await InstructorDirectory.instance
                                  .toggleSuspendRemote(ref.read(apiClientProvider), instructor.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(ok
                                      ? (active ? 'حساب استاد فعال شد' : 'حساب استاد مسدود شد')
                                      : 'خطا در ارتباط با سرور')));
                            } else {
                              InstructorDirectory.instance
                                  .setSuspended(instructor.id, !active);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(active
                                      ? 'حساب استاد فعال شد'
                                      : 'حساب استاد مسدود شد')));
                            }
                          },
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 12),

                    // ── آمار فعالیت (مطابق منطق داشبورد استاد) ──
                    Row(children: [
                      _StatBox(value: '${seminars.length}', label: 'سمینار'),
                      const SizedBox(width: 8),
                      _StatBox(
                          value: '$liveCount',
                          label: 'زنده',
                          color: AppPalette.red),
                      const SizedBox(width: 8),
                      _StatBox(
                          value: '$upcoming',
                          label: 'پیش رو',
                          color: AppPalette.amber),
                      const SizedBox(width: 8),
                      _StatBox(
                          value: '$totalRegistrations',
                          label: 'ثبت‌نام',
                          color: AppPalette.greenDark),
                    ]),
                    const SizedBox(height: 16),

                    const Text('فعالیت‌ها (سمینارهای این استاد)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    if (seminarsAsync.isLoading && seminars.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (seminars.isEmpty)
                      const _Card(children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('این استاد هنوز سمیناری نساخته است',
                              textAlign: TextAlign.center),
                        ),
                      ])
                    else
                      for (final s in seminars) ...[
                        _SeminarAdminCard(
                          seminar: s,
                          statusView: _statusView(s),
                          formattedDate: _fmt(s.scheduledStart),
                          instructorId: instructor.id,
                        ),
                        const SizedBox(height: 10),
                      ],
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// کارت یک سمینار در نمای مدیر — با کنترل کامل: تغییر وضعیت (State Machine
/// بخش ۱۲.۲) و حذف — هر دو از طریق بک‌اند واقعی (همان Use Case های بخش
/// «مدیریت سمینارها» پنل مدیر) وقتی `kUseLiveBackend` فعال است.
class _SeminarAdminCard extends ConsumerWidget {
  final Seminar seminar;
  final (String, Color) statusView;
  final String formattedDate;
  final String instructorId;

  const _SeminarAdminCard({
    required this.seminar,
    required this.statusView,
    required this.formattedDate,
    required this.instructorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusLabel, statusColor) = statusView;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(seminar.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            PopupMenuButton<String>(
              tooltip: 'کنترل مدیر',
              onSelected: (action) async {
                switch (action) {
                  case 'status':
                    await _changeStatus(context, ref);
                  case 'delete':
                    await _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'status',
                    child: Text('تغییر وضعیت سمینار')),
                PopupMenuItem(
                    value: 'delete',
                    child: Text('حذف سمینار',
                        style: TextStyle(color: AppPalette.red))),
              ],
            ),
          ]),
          if (seminar.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(seminar.description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            _Meta(icon: Icons.schedule_rounded, text: formattedDate),
            _Meta(
                icon: Icons.timer_rounded,
                text: '${seminar.durationMinutes} دقیقه'),
            _Meta(
              icon: Icons.group_rounded,
              text: seminar.capacity == null
                  ? '${seminar.registeredCount} ثبت‌نام'
                  : '${seminar.registeredCount}/${seminar.capacity} ثبت‌نام',
            ),
            _Meta(
              icon: seminar.audience == SeminarAudience.parents
                  ? Icons.family_restroom_rounded
                  : Icons.school_rounded,
              text: seminar.audience == SeminarAudience.parents
                  ? 'ویژهٔ والدین'
                  : 'ویژهٔ شاگردان',
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _changeStatus(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<SeminarStatus>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('تغییر وضعیت سمینار (State Machine بخش ۱۲.۲)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final (st, label) in const [
              (SeminarStatus.draft, 'پیش‌نویس'),
              (SeminarStatus.published, 'منتشرشده (ثبت‌نام باز)'),
              (SeminarStatus.registrationClosed, 'بستن ثبت‌نام'),
              (SeminarStatus.live, 'شروع زنده'),
              (SeminarStatus.ended, 'پایان جلسه'),
              (SeminarStatus.archived, 'آرشیو'),
            ])
              ListTile(
                title: Text(label),
                trailing: seminar.status == st
                    ? const Icon(Icons.check_rounded,
                        color: AppPalette.green)
                    : null,
                onTap: () => Navigator.pop(ctx, st),
              ),
          ]),
        ),
      ),
    );
    if (selected == null || selected == seminar.status) return;
    final result = await ref
        .read(setAdminSeminarStatusUseCaseProvider)
        .call(SetAdminSeminarStatusParams(id: seminar.id, status: selected));
    if (!context.mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(seminarsByInstructorProvider(instructorId));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('وضعیت سمینار به‌روز شد')));
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حذف سمینار'),
          content: Text(
              'سمینار «${seminar.title}» با ${seminar.registeredCount} ثبت‌نام حذف شود؟ این عمل قابل بازگشت نیست.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('انصراف')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppPalette.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final result = await ref.read(deleteAdminSeminarUseCaseProvider).call(seminar.id);
    if (!context.mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(seminarsByInstructorProvider(instructorId));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('سمینار حذف شد')));
      },
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 17, color: AppPalette.greenDark),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox(
      {required this.value, required this.label, this.color = AppPalette.green});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ]),
        ),
      );
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      ]);
}
