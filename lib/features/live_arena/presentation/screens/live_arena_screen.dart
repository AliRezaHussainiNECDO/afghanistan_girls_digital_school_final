import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/live_arena_entities.dart';
import '../providers/live_arena_providers.dart';
import '../widgets/arena_answer_option.dart';
import '../widgets/arena_countdown_ring.dart';
import '../widgets/arena_mini_leaderboard.dart';

/// «آرنای زنده» — صفحهٔ نبرد هفتگی زندهٔ رتبه‌بندی. طبق طراحی: اتاق انتظار
/// (قبل از شروع) → سؤال زنده (با شمارش معکوس سمت سرور) → نمایش پاسخ درست +
/// جدول لحظه‌ای → ... → پایان (قهرمان + جشن). تمام حالت‌ها یک صفحه‌اند،
/// دقیقاً هم‌الگو با `CompetitionScreen`.
class LiveArenaScreen extends ConsumerStatefulWidget {
  const LiveArenaScreen({super.key});

  @override
  ConsumerState<LiveArenaScreen> createState() => _LiveArenaScreenState();
}

class _LiveArenaScreenState extends ConsumerState<LiveArenaScreen> {
  int? _selectedChoice;

  String _promptFor(ArenaQuestionPublic q, String lang) => switch (lang) {
        'en' => q.promptEn,
        'ps' => q.promptPs,
        'fr' => q.promptFr,
        _ => q.promptFa,
      };

  List<String> _optionsFor(ArenaQuestionPublic q, String lang) => switch (lang) {
        'en' => q.optionsEn,
        'ps' => q.optionsPs,
        'fr' => q.optionsFr,
        _ => q.optionsFa,
      };

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(liveArenaCurrentProvider);

    return AppScaffold(
      title: context.tr('liveArena.title'),
      role: AppUserRole.student,
      body: infoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(liveArenaCurrentProvider)),
        data: (info) => _buildForInfo(info),
      ),
    );
  }

  Widget _buildForInfo(ArenaCurrentInfo info) {
    final event = info.event;
    if (event == null) {
      return _EmptyState(text: context.tr('liveArena.noEventScheduled'));
    }
    if (!info.eligible) {
      return _EligibilityGate(myRankNo: info.myRankNo, requiredRankNo: event.minRankNo);
    }
    if (event.isEnded) {
      return _ResultsView(eventId: event.id, event: event);
    }
    if (event.isScheduled) {
      return _WaitingForStart(event: event, onStarted: () => ref.invalidate(liveArenaCurrentProvider));
    }
    // event.isLive — اتصال زنده برقرار می‌شود
    return _LiveRoom(
      eventId: event.id,
      selectedChoice: _selectedChoice,
      onSelect: (i) => setState(() => _selectedChoice = i),
      onQuestionAdvance: () => setState(() => _selectedChoice = null),
      promptFor: _promptFor,
      optionsFor: _optionsFor,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _EligibilityGate extends StatelessWidget {
  final int myRankNo;
  final int requiredRankNo;
  const _EligibilityGate({required this.myRankNo, required this.requiredRankNo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('liveArena.notEligibleTitle'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('liveArena.notEligibleBody', {'rank': '$requiredRankNo'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingForStart extends ConsumerStatefulWidget {
  final ArenaEventSummary event;
  final VoidCallback onStarted;
  const _WaitingForStart({required this.event, required this.onStarted});

  @override
  ConsumerState<_WaitingForStart> createState() => _WaitingForStartState();
}

class _WaitingForStartState extends ConsumerState<_WaitingForStart> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // هر ۲۰ ثانیه چک می‌کند آیا رویداد به فاز «زنده» رسیده — تا بدون نیاز به
    // خروج/ورود دستی از صفحه، خودکار به اتاق زنده منتقل شود.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => ref.invalidate(liveArenaCurrentProvider));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 44, color: AppColors.orange500)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.15, duration: 900.ms),
            const SizedBox(height: 14),
            Text(widget.event.titleFa, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              context.tr('liveArena.waitingForStart'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _CountdownToText(target: widget.event.startsAt),
          ],
        ),
      ),
    );
  }
}

class _CountdownToText extends StatefulWidget {
  final DateTime target;
  const _CountdownToText({required this.target});
  @override
  State<_CountdownToText> createState() => _CountdownToTextState();
}

class _CountdownToTextState extends State<_CountdownToText> {
  late final Stream<Duration> _ticker =
      Stream.periodic(const Duration(seconds: 1), (_) => widget.target.difference(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: _ticker,
      initialData: widget.target.difference(DateTime.now()),
      builder: (context, snap) {
        final d = snap.data ?? Duration.zero;
        if (d.isNegative) return Text(context.tr('liveArena.startingSoon'), style: const TextStyle(fontWeight: FontWeight.w800));
        final h = d.inHours;
        final m = d.inMinutes % 60;
        final s = d.inSeconds % 60;
        final text = h > 0 ? '$hس $mد $sث' : '$mد $sث';
        return Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: AppColors.orange600));
      },
    );
  }
}

class _LiveRoom extends ConsumerStatefulWidget {
  final String eventId;
  final int? selectedChoice;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuestionAdvance;
  final String Function(ArenaQuestionPublic, String) promptFor;
  final List<String> Function(ArenaQuestionPublic, String) optionsFor;

  const _LiveRoom({
    required this.eventId,
    required this.selectedChoice,
    required this.onSelect,
    required this.onQuestionAdvance,
    required this.promptFor,
    required this.optionsFor,
  });

  @override
  ConsumerState<_LiveRoom> createState() => _LiveRoomState();
}

class _LiveRoomState extends ConsumerState<_LiveRoom> {
  int _lastSeenQuestionIndex = -2;
  bool _finishedAnnounced = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveArenaControllerProvider(widget.eventId));
    final myId = ref.watch(authSessionProvider)?.id;
    final lang = Localizations.localeOf(context).languageCode;
    final snapshot = state.snapshot;

    if (state.connectionStatus == ArenaConnectionStatus.connecting && snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.connectionStatus == ArenaConnectionStatus.error) {
      return _EmptyState(text: context.tr('liveArena.connectionError'));
    }
    if (snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.questionIndex != _lastSeenQuestionIndex) {
      _lastSeenQuestionIndex = snapshot.questionIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onQuestionAdvance());
    }

    if (snapshot.phase == ArenaPhase.finished && !_finishedAnnounced) {
      _finishedAnnounced = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HapticFeedback.heavyImpact();
        CelebrationOverlay.of(context)?.burst();
      });
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (state.connectionStatus == ArenaConnectionStatus.disconnected)
          _ReconnectingBanner(text: context.tr('liveArena.reconnecting')),
        if (snapshot.phase == ArenaPhase.waiting)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text(context.tr('liveArena.waitingForStart'), style: const TextStyle(fontWeight: FontWeight.w700))),
          )
        else if (snapshot.phase == ArenaPhase.finished)
          _FinishedView(standings: snapshot.standings, myId: myId)
        else
          _QuestionView(
            snapshot: snapshot,
            myId: myId,
            selectedChoice: widget.selectedChoice,
            lang: lang,
            promptFor: widget.promptFor,
            optionsFor: widget.optionsFor,
            onSelect: (i) {
              if (widget.selectedChoice != null) return;
              widget.onSelect(i);
              HapticFeedback.selectionClick();
              ref.read(liveArenaControllerProvider(widget.eventId).notifier).answer(i);
            },
          ),
      ],
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  final String text;
  const _ReconnectingBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.gold300.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
        ],
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  final ArenaRoomSnapshot snapshot;
  final String? myId;
  final int? selectedChoice;
  final String lang;
  final String Function(ArenaQuestionPublic, String) promptFor;
  final List<String> Function(ArenaQuestionPublic, String) optionsFor;
  final ValueChanged<int> onSelect;

  const _QuestionView({
    required this.snapshot,
    required this.myId,
    required this.selectedChoice,
    required this.lang,
    required this.promptFor,
    required this.optionsFor,
    required this.onSelect,
  });

  static const _labels = ['الف', 'ب', 'ج', 'د'];

  @override
  Widget build(BuildContext context) {
    final q = snapshot.question;
    final revealed = snapshot.phase == ArenaPhase.reveal;
    if (q == null) return const SizedBox.shrink();

    final options = optionsFor(q, lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('liveArena.questionOf', {'current': '${snapshot.questionIndex + 1}', 'total': '${snapshot.totalQuestions}'}),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            ),
            if (snapshot.questionEndsAt != null)
              ArenaCountdownRing(endsAt: snapshot.questionEndsAt!, totalSeconds: snapshot.timeLimitSeconds, size: 52),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.heroGradientWarm, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.warm),
          child: Text(
            promptFor(q, lang),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(options.length, (i) {
          return ArenaAnswerOption(
            label: i < _labels.length ? _labels[i] : '${i + 1}',
            text: options[i],
            selected: selectedChoice == i,
            revealed: revealed,
            isCorrectAnswer: revealed && q.correctIndex == i,
            locked: selectedChoice != null || revealed,
            onTap: () => onSelect(i),
          );
        }),
        const SizedBox(height: 20),
        Text(context.tr('liveArena.liveStandings'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        const SizedBox(height: 8),
        ArenaMiniLeaderboard(standings: snapshot.standings, myStudentId: myId),
      ],
    );
  }
}

class _FinishedView extends StatelessWidget {
  final List<ArenaStanding> standings;
  final String? myId;
  const _FinishedView({required this.standings, required this.myId});

  @override
  Widget build(BuildContext context) {
    final champion = standings.isNotEmpty ? standings.first : null;
    return Column(
      children: [
        const SizedBox(height: 12),
        const Icon(Icons.emoji_events_rounded, color: AppColors.gold500, size: 64)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .slideY(begin: 0, end: -0.1, duration: 1100.ms, curve: Curves.easeInOut),
        const SizedBox(height: 10),
        Text(context.tr('liveArena.eventFinished'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        if (champion != null) ...[
          const SizedBox(height: 6),
          Text(
            context.tr('liveArena.championIs', {'name': champion.displayName}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.gold600),
          ),
        ],
        const SizedBox(height: 22),
        ArenaMiniLeaderboard(standings: standings, myStudentId: myId, maxRows: 10),
      ],
    );
  }
}

class _ResultsView extends ConsumerWidget {
  final String eventId;
  final ArenaEventSummary event;
  const _ResultsView({required this.eventId, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(arenaResultsProvider(eventId));
    final myId = ref.watch(authSessionProvider)?.id;
    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(arenaResultsProvider(eventId))),
      data: (standings) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [_FinishedView(standings: standings, myId: myId)],
      ),
    );
  }
}
