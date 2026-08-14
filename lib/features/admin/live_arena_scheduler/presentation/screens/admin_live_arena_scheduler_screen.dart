import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../competition/domain/entities/competition_entities.dart';
import '../../../../competition/presentation/providers/competition_providers.dart';
import '../../domain/entities/arena_event_list_item.dart';
import '../providers/admin_live_arena_providers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// «زمان‌بندی میدان ستارگان» — صفحهٔ مدیر برای زمان‌بندی/لغو نبردهای هفتگی
/// زندهٔ رتبه‌بندی، به‌جای نیاز به فراخوانی دستی `POST /admin/live-arena/schedule`.
///
/// طبق درخواست صریح کاربر («خیلی مدرن و گویا و آینده‌نگرانه»)، این صفحه
/// پالت «فضای تیرهٔ پرستاره» مخصوص خودش را دارد (نه توکن‌های گرم/نارنجی
/// معمول اپ) — دقیقاً همان الگویی که already برای «مراکز عملیات» مدیر
/// (لاگ خطا/لاگ بازبینی) با پالت «سینمای تیره» جا افتاده، اینجا با یک
/// زمینهٔ پرستارهٔ متحرک به‌جای «میدان ستارگان» گسترش داده شده.
/// ═══════════════════════════════════════════════════════════════════════════

class _Nova {
  static const bg = Color(0xFF05061A);
  static const bgMid = Color(0xFF0B0F33);
  static const surface = Color(0xFF141A44);
  static const surfaceHi = Color(0xFF1E2657);
  static const border = Color(0x26FFFFFF);
  static const text = Color(0xFFEDEFFF);
  static const textDim = Color(0xFFA0A7DA);
  static const gold = Color(0xFFFFC93C);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF9B8CFB);
  static const green = Color(0xFF34D399);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);
}

String _statusLabel(BuildContext context, String status) => switch (status) {
      'live' => context.tr('liveArenaAdmin.statusLive'),
      'ended' => context.tr('liveArenaAdmin.statusEnded'),
      _ => context.tr('liveArenaAdmin.statusScheduled'),
    };

Color _statusColor(String status) => switch (status) {
      'live' => _Nova.green,
      'ended' => _Nova.textDim,
      _ => _Nova.amber,
    };

String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDateTime(DateTime d) => '${d.year}/${_two(d.month)}/${_two(d.day)}  ${_two(d.hour)}:${_two(d.minute)}';

/// نام لیگِ نزدیک‌ترین مقام به `minRankNo` (اگر فهرست ۵۰ مقام هنوز از سرور
/// نرسیده، به نمایش خام «مقام N به بالا» برمی‌گردد).
String _leagueLabelFor(List<RankTier> tiers, int minRankNo, BuildContext context) {
  for (final t in tiers) {
    if (t.rankNo == minRankNo) return t.leagueTitleFa;
  }
  return context.tr('liveArenaAdmin.rankFallback', {'rank': '$minRankNo'});
}

/// آغاز هر لیگ (کمترین `rankNo` در هر `leagueKey`) — برای تبدیل ۵۰ مقام به
/// حداکثر ۵ گزینهٔ قابل‌فهم در فرم زمان‌بندی («این رویداد برای کدام لیگ به
/// بالا باز باشد؟») به‌جای یک عدد خام ۱ تا ۵۰.
List<({String leagueKey, String leagueTitleFa, int startRankNo})> _leagueStarts(List<RankTier> tiers) {
  final map = <String, ({String leagueTitleFa, int startRankNo})>{};
  for (final t in tiers) {
    final existing = map[t.leagueKey];
    if (existing == null || t.rankNo < existing.startRankNo) {
      map[t.leagueKey] = (leagueTitleFa: t.leagueTitleFa, startRankNo: t.rankNo);
    }
  }
  final list = map.entries
      .map((e) => (leagueKey: e.key, leagueTitleFa: e.value.leagueTitleFa, startRankNo: e.value.startRankNo))
      .toList();
  list.sort((a, b) => a.startRankNo.compareTo(b.startRankNo));
  return list;
}

// ═════════════════════════════════ صفحه ═════════════════════════════════════
class AdminLiveArenaSchedulerScreen extends ConsumerStatefulWidget {
  const AdminLiveArenaSchedulerScreen({super.key});

  @override
  ConsumerState<AdminLiveArenaSchedulerScreen> createState() => _AdminLiveArenaSchedulerScreenState();
}

class _AdminLiveArenaSchedulerScreenState extends ConsumerState<AdminLiveArenaSchedulerScreen> {
  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(adminLiveArenaEventsProvider);

    return AppScaffold(
      title: context.tr('admin.liveArenaScheduler'),
      role: ref.watch(authSessionProvider)?.role ?? AppUserRole.superAdmin,
      actions: [
        IconButton(
          tooltip: context.tr('liveArenaAdmin.refreshTooltip'),
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(adminLiveArenaEventsProvider),
        ),
      ],
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_Nova.bg, _Nova.bgMid, _Nova.bg],
              ),
            ),
          ),
          const Positioned.fill(child: _Starfield()),
          pageAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _Nova.cyan)),
            error: (e, st) => _ErrorPanel(
              message: context.tr('liveArenaAdmin.loadError'),
              onRetry: () => ref.invalidate(adminLiveArenaEventsProvider),
            ),
            data: (page) => _SchedulerContent(page: page),
          ),
        ],
      ),
    );
  }
}

/// زمینهٔ پرستارهٔ ثابت (تولیدشده یک‌بار با seed مشخص — نه `Random()` جدید
/// هر فریم) پشتِ کل صفحه، تا حس «میدان ستارگان» واقعاً از همان لحظهٔ ورود
/// دیده شود، نه فقط در متن.
class _Starfield extends StatelessWidget {
  const _Starfield();

  static final List<Offset> _positions = List.generate(70, (i) {
    final rnd = Random(i * 7919 + 13);
    return Offset(rnd.nextDouble(), rnd.nextDouble());
  });
  static final List<double> _radii = List.generate(70, (i) => Random(i * 104729 + 5).nextDouble() * 1.4 + 0.4);
  static final List<double> _opacities = List.generate(70, (i) => Random(i * 65537 + 3).nextDouble() * 0.55 + 0.15);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarfieldPainter(_positions, _radii, _opacities));
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<Offset> positions;
  final List<double> radii;
  final List<double> opacities;
  const _StarfieldPainter(this.positions, this.radii, this.opacities);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++) {
      final paint = Paint()..color = Colors.white.withValues(alpha: opacities[i]);
      canvas.drawCircle(Offset(positions[i].dx * size.width, positions[i].dy * size.height), radii[i] * 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt_rounded, size: 52, color: _Nova.textDim),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _Nova.surfaceHi, foregroundColor: _Nova.cyan),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulerContent extends ConsumerWidget {
  final AdminArenaEventsPage page;
  const _SchedulerContent({required this.page});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = page.events.where((e) => e.isScheduled || e.isLive).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final primary = upcoming.isNotEmpty ? upcoming.first : null;
    final otherUpcoming = upcoming.length > 1 ? upcoming.sublist(1) : const <ArenaEventListItem>[];
    final ended = page.events.where((e) => e.isEnded).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        if (primary != null)
          _HeroStatusCard(event: primary).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06, end: 0, duration: 400.ms)
        else
          const _EmptyHero().animate().fadeIn(duration: 400.ms),
        if (otherUpcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          _OtherUpcomingSection(events: otherUpcoming),
        ],
        const SizedBox(height: 22),
        _ScheduleFormCard(questionBankCount: page.questionBankCount)
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.06, end: 0, delay: 100.ms, duration: 400.ms),
        const SizedBox(height: 22),
        _HistorySection(events: ended),
      ],
    );
  }
}

// ────────────────────────── کارت وضعیت اصلی (Hero) ──────────────────────────
class _HeroStatusCard extends ConsumerWidget {
  final ArenaEventListItem event;
  const _HeroStatusCard({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiersAsync = ref.watch(rankTiersProvider);
    final tiers = tiersAsync.asData?.value ?? const <RankTier>[];
    final statusColor = _statusColor(event.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Nova.border),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Nova.surfaceHi, _Nova.surface],
        ),
        boxShadow: [
          BoxShadow(color: statusColor.withValues(alpha: 0.18), blurRadius: 32, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(status: event.status),
              const Spacer(),
              if (event.isScheduled)
                IconButton(
                  tooltip: context.tr('liveArenaAdmin.cancelEvent'),
                  icon: const Icon(Icons.close_rounded, color: _Nova.red),
                  onPressed: () => _confirmCancel(context, ref, event.id),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: _Nova.gold, size: 22)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(end: 1.18, duration: 1200.ms, curve: Curves.easeInOut),
              const SizedBox(width: 10),
              Expanded(
                child: Text(event.titleFa,
                    style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w900, fontSize: 19)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (event.isScheduled) _CountdownRow(target: event.startsAt) else if (event.isLive) _LiveNowRow(endsAt: event.endsAt),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(icon: Icons.event_rounded, label: _fmtDateTime(event.startsAt)),
              _StatChip(
                  icon: Icons.timer_outlined,
                  label: '${event.endsAt.difference(event.startsAt).inMinutes} ${context.tr('liveArenaAdmin.minutesShort')}'),
              _StatChip(icon: Icons.shield_moon_rounded, label: _leagueLabelFor(tiers, event.minRankNo, context)),
              _StatChip(icon: Icons.quiz_rounded, label: '${event.questionCount} ${context.tr('liveArenaAdmin.questionsShort')}'),
              _StatChip(
                  icon: Icons.hourglass_bottom_rounded,
                  label: '${event.timeLimitSeconds} ${context.tr('liveArenaAdmin.secondsShort')}'),
              if (event.isLive || event.participantCount > 0)
                _StatChip(icon: Icons.groups_rounded, label: '${event.participantCount} ${context.tr('liveArenaAdmin.participantsLabel')}'),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmCancel(BuildContext context, WidgetRef ref, String eventId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: _Nova.surfaceHi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(dialogContext.tr('liveArenaAdmin.cancelConfirmTitle'), style: const TextStyle(color: _Nova.text)),
      content: Text(dialogContext.tr('liveArenaAdmin.cancelConfirmBody'), style: const TextStyle(color: _Nova.textDim)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(dialogContext.tr('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _Nova.red),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(dialogContext.tr('liveArenaAdmin.cancelEvent')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(adminLiveArenaActionsProvider).cancel(eventId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('liveArenaAdmin.cancelSuccess'))));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final isLive = status == 'live';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle))
              .animate(onPlay: (c) => isLive ? c.repeat(reverse: true) : null)
              .fadeIn(duration: 500.ms)
              .then()
              .fadeOut(duration: 500.ms),
          const SizedBox(width: 8),
          Text(_statusLabel(context, status), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Nova.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _Nova.cyan),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _Nova.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CountdownRow extends StatefulWidget {
  final DateTime target;
  const _CountdownRow({required this.target});
  @override
  State<_CountdownRow> createState() => _CountdownRowState();
}

class _CountdownRowState extends State<_CountdownRow> {
  late final Stream<Duration> _ticker =
      Stream.periodic(const Duration(seconds: 1), (_) => widget.target.difference(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _ticker,
      initialData: widget.target.difference(DateTime.now()),
      builder: (context, snap) {
        final d = snap.data ?? Duration.zero;
        final text = d.isNegative
            ? context.tr('liveArenaAdmin.startingSoon')
            : d.inHours > 0
                ? '${d.inHours}س ${d.inMinutes % 60}د ${d.inSeconds % 60}ث'
                : '${d.inMinutes % 60}د ${d.inSeconds % 60}ث';
        return Row(
          children: [
            Text(context.tr('liveArenaAdmin.startsIn'), style: const TextStyle(color: _Nova.textDim, fontSize: 12.5)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: _Nova.gold, fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        );
      },
    );
  }
}

class _LiveNowRow extends StatelessWidget {
  final DateTime endsAt;
  const _LiveNowRow({required this.endsAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bolt_rounded, color: _Nova.green, size: 18),
        const SizedBox(width: 6),
        Text(context.tr('liveArenaAdmin.statusLive'), style: const TextStyle(color: _Nova.green, fontWeight: FontWeight.w800, fontSize: 14)),
      ],
    );
  }
}

// ─────────────────── سایر رویدادهای برنامه‌ریزی‌شده (اگر بیش از یکی) ─────────
class _OtherUpcomingSection extends ConsumerWidget {
  final List<ArenaEventListItem> events;
  const _OtherUpcomingSection({required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Nova.border),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('liveArenaAdmin.otherScheduledTitle'),
              style: const TextStyle(color: _Nova.textDim, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 10),
          ...events.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    _StatusPill(status: e.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${e.titleFa} — ${_fmtDateTime(e.startsAt)}',
                        style: const TextStyle(color: _Nova.text, fontSize: 12.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (e.isScheduled)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _Nova.red, size: 18),
                        onPressed: () => _confirmCancel(context, ref, e.id),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Nova.border, style: BorderStyle.solid),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Column(
        children: [
          const Icon(Icons.nights_stay_rounded, size: 46, color: _Nova.textDim),
          const SizedBox(height: 14),
          Text(context.tr('liveArenaAdmin.heroEmptyTitle'),
              textAlign: TextAlign.center, style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(context.tr('liveArenaAdmin.heroEmptyBody'),
              textAlign: TextAlign.center, style: const TextStyle(color: _Nova.textDim, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}

// ────────────────────────── فرم زمان‌بندی رویداد جدید ────────────────────────
const List<int> _kQuestionCountOptions = [5, 10, 15, 20];
const List<int> _kTimeLimitOptions = [10, 15, 20, 30];

class _ScheduleFormCard extends ConsumerStatefulWidget {
  final int questionBankCount;
  const _ScheduleFormCard({required this.questionBankCount});

  @override
  ConsumerState<_ScheduleFormCard> createState() => _ScheduleFormCardState();
}

class _ScheduleFormCardState extends ConsumerState<_ScheduleFormCard> {
  final _titleController = TextEditingController();
  DateTime? _pickedDate;
  TimeOfDay? _pickedTime;
  int _questionCount = 10;
  int _timeLimitSeconds = 15;
  int? _selectedMinRank;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime? get _combinedStart {
    if (_pickedDate == null || _pickedTime == null) return null;
    return DateTime(_pickedDate!.year, _pickedDate!.month, _pickedDate!.day, _pickedTime!.hour, _pickedTime!.minute);
  }

  int get _estimatedMinutes => ((_questionCount * (_timeLimitSeconds + 4)) / 60).ceil() + 5;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: _darkPickerTheme(context), child: child!),
    );
    if (picked != null) setState(() => _pickedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? const TimeOfDay(hour: 18, minute: 0),
      builder: (context, child) => Theme(data: _darkPickerTheme(context), child: child!),
    );
    if (picked != null) setState(() => _pickedTime = picked);
  }

  ThemeData _darkPickerTheme(BuildContext context) => ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: _Nova.gold, onPrimary: Colors.black, surface: _Nova.surfaceHi),
      );

  Future<void> _submit(List<({String leagueKey, String leagueTitleFa, int startRankNo})> leagues) async {
    final start = _combinedStart;
    setState(() => _errorText = null);
    if (start == null) {
      setState(() => _errorText = context.tr('liveArenaAdmin.pickDateTimeFirst'));
      return;
    }
    if (!start.isAfter(DateTime.now())) {
      setState(() => _errorText = context.tr('liveArenaAdmin.pastRequiredStartError'));
      return;
    }
    final minRank = _selectedMinRank ?? (leagues.isNotEmpty ? leagues.first.startRankNo : 21);
    setState(() => _submitting = true);
    try {
      await ref.read(adminLiveArenaActionsProvider).schedule(
            startsAt: start,
            titleFa: _titleController.text,
            minRankNo: minRank,
            questionCount: _questionCount,
            timeLimitSeconds: _timeLimitSeconds,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('liveArenaAdmin.scheduleSuccess'))));
      setState(() {
        _titleController.clear();
        _pickedDate = null;
        _pickedTime = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(rankTiersProvider);
    final tiers = tiersAsync.asData?.value ?? const <RankTier>[];
    final leagues = _leagueStarts(tiers);
    final bankShortage = _questionCount > widget.questionBankCount && widget.questionBankCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Nova.border),
        color: _Nova.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: _Nova.violet, size: 20),
              const SizedBox(width: 8),
              Text(context.tr('liveArenaAdmin.formTitle'), style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              _StatChip(icon: Icons.quiz_outlined, label: context.tr('liveArenaAdmin.questionBankInfo', {'count': '${widget.questionBankCount}'})),
            ],
          ),
          const SizedBox(height: 18),
          _DarkTextField(controller: _titleController, label: context.tr('liveArenaAdmin.titleFieldLabel'), hint: context.tr('liveArenaAdmin.titleFieldHint')),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PickerButton(
                  icon: Icons.calendar_month_rounded,
                  label: _pickedDate == null
                      ? context.tr('liveArenaAdmin.pickDate')
                      : '${_pickedDate!.year}/${_two(_pickedDate!.month)}/${_two(_pickedDate!.day)}',
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PickerButton(
                  icon: Icons.schedule_rounded,
                  label: _pickedTime == null ? context.tr('liveArenaAdmin.pickTime') : _pickedTime!.format(context),
                  onTap: _pickTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(context.tr('liveArenaAdmin.leagueLabel'), style: const TextStyle(color: _Nova.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (leagues.isEmpty)
            const SizedBox(height: 24, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _Nova.cyan)))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: leagues.map((l) {
                final selected = (_selectedMinRank ?? leagues.first.startRankNo) == l.startRankNo;
                return _SelectableChip(label: l.leagueTitleFa, selected: selected, onTap: () => setState(() => _selectedMinRank = l.startRankNo));
              }).toList(),
            ),
          const SizedBox(height: 18),
          Text(context.tr('liveArenaAdmin.questionCountLabel'), style: const TextStyle(color: _Nova.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _kQuestionCountOptions
                .map((n) => _SelectableChip(label: '$n', selected: _questionCount == n, onTap: () => setState(() => _questionCount = n)))
                .toList(),
          ),
          if (bankShortage) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('liveArenaAdmin.questionBankWarning', {'requested': '$_questionCount'}),
              style: const TextStyle(color: _Nova.amber, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 18),
          Text(context.tr('liveArenaAdmin.timePerQuestionLabel'), style: const TextStyle(color: _Nova.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _kTimeLimitOptions
                .map((s) => _SelectableChip(
                    label: '$s ${context.tr('liveArenaAdmin.secondsShort')}',
                    selected: _timeLimitSeconds == s,
                    onTap: () => setState(() => _timeLimitSeconds = s)))
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(context.tr('liveArenaAdmin.estimatedDuration', {'minutes': '$_estimatedMinutes'}),
              style: const TextStyle(color: _Nova.textDim, fontSize: 12)),
          if (_errorText != null) ...[
            const SizedBox(height: 10),
            Text(_errorText!, style: const TextStyle(color: _Nova.red, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [_Nova.violet, _Nova.cyan]),
                boxShadow: [BoxShadow(color: _Nova.violet.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _submitting ? null : () => _submit(leagues),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(context.tr('liveArenaAdmin.scheduleButton'),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  const _DarkTextField({required this.controller, required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _Nova.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: _Nova.textDim),
        hintStyle: TextStyle(color: _Nova.textDim.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _Nova.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _Nova.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _Nova.violet)),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: _Nova.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: _Nova.cyan),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w700, fontSize: 12.5))),
          ],
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? const LinearGradient(colors: [_Nova.violet, _Nova.cyan]) : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: selected ? Colors.transparent : _Nova.border),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? Colors.white : _Nova.textDim, fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      ),
    );
  }
}

// ────────────────────────────── تاریخچهٔ رویدادها ────────────────────────────
class _HistorySection extends StatelessWidget {
  final List<ArenaEventListItem> events;
  const _HistorySection({required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded, color: _Nova.textDim, size: 18),
            const SizedBox(width: 8),
            Text(context.tr('liveArenaAdmin.historyTitle'), style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          Text(context.tr('liveArenaAdmin.historyEmpty'), style: const TextStyle(color: _Nova.textDim, fontSize: 12.5))
        else
          ...events.map((e) => _HistoryRow(event: e)),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ArenaEventListItem event;
  const _HistoryRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final hasChampion = event.championName != null && event.championName!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: _Nova.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (hasChampion ? _Nova.gold : _Nova.textDim).withValues(alpha: 0.16),
            ),
            child: Icon(hasChampion ? Icons.emoji_events_rounded : Icons.people_outline_rounded,
                color: hasChampion ? _Nova.gold : _Nova.textDim, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.titleFa, style: const TextStyle(color: _Nova.text, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  hasChampion
                      ? '${context.tr('liveArenaAdmin.championLabel')}: ${event.championName} (+${event.championPoints ?? 0})'
                      : context.tr('liveArenaAdmin.noChampion'),
                  style: TextStyle(color: hasChampion ? _Nova.gold : _Nova.textDim, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtDateTime(event.startsAt), style: const TextStyle(color: _Nova.textDim, fontSize: 10.5)),
              const SizedBox(height: 3),
              Text('${event.participantCount} ${context.tr('liveArenaAdmin.participantsLabel')}',
                  style: const TextStyle(color: _Nova.textDim, fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}
