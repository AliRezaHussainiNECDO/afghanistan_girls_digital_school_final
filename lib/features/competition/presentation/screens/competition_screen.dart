import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/competition_entities.dart';
import '../providers/competition_providers.dart';
import '../../../live_arena/presentation/providers/live_arena_providers.dart';
import '../widgets/competition_hero_card.dart';
import '../widgets/competition_stats_card.dart';
import '../widgets/daily_quest_card.dart';
import '../widgets/leaderboard_podium.dart';
import '../widgets/leaderboard_tile.dart';
import '../widgets/learning_roadmap.dart';
import '../widgets/mission_card.dart';

/// «رقابت مکتب» — صفحهٔ اصلی نسخهٔ ۲ اپ: شاگردان برای مقام اول (از ۵۰ مقام)
/// در یک جدول رتبه‌بندی سراسری با هم مبارزه می‌کنند، و با تکمیل میشن‌های
/// روزانه/دائمی که از تمام بخش‌های برنامه (درس، کارخانگی، امتحان، حافظهٔ
/// جمعی، چت، پروفایل، معلم هوشمند، سمینار، کد دعوت، گواهی‌نامه، کتابخانه)
/// می‌آیند، امتیاز و پاداش می‌گیرند.
class CompetitionScreen extends ConsumerStatefulWidget {
  const CompetitionScreen({super.key});

  @override
  ConsumerState<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends ConsumerState<CompetitionScreen> {
  int _tab = 0; // 0=leaderboard, 1=missions, 2=roadmap
  bool _byGrade = false;
  String? _claimingId;
  int? _lastKnownRankNo;

  Future<void> _claim(CompetitionMission mission) async {
    setState(() => _claimingId = mission.id);
    try {
      final points = await ref.read(competitionActionsProvider).claimMission(mission.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      CelebrationOverlay.of(context)?.burst();
      _showClaimedToast(points);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  Future<void> _claimDaily(DailyQuest quest) async {
    setState(() => _claimingId = quest.id);
    try {
      final points = await ref.read(competitionActionsProvider).claimDailyQuest(quest.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      CelebrationOverlay.of(context)?.burst();
      _showClaimedToast(points);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _claimingId = null);
    }
  }

  void _showClaimedToast(int points) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('competition.missionClaimedToast', {'points': '$points'})),
        backgroundColor: AppColors.green600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      ),
    );
  }

  /// وقتی مقام واقعاً بالا می‌رود (نه بار اول بارگیری صفحه)، یک لرزش قوی‌تر +
  /// جشن کانفتی + پیام تبریک نشان می‌دهد — طبق درخواست «بازخورد لمسی/بصری».
  void _maybeAnnounceRankUp(int newRankNo, String newTitleFa) {
    final previous = _lastKnownRankNo;
    _lastKnownRankNo = newRankNo;
    if (previous == null || newRankNo <= previous) return;
    HapticFeedback.heavyImpact();
    CelebrationOverlay.of(context)?.burst();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('competition.rankUpToast', {'title': newTitleFa})),
          backgroundColor: AppColors.gold600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(myCompetitionStatusProvider);
    final myId = ref.watch(authSessionProvider)?.id;

    return AppScaffold(
      title: context.tr('competition.title'),
      role: AppUserRole.student,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(competitionRefreshProvider.notifier).state++;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            statusAsync.when(
              loading: () => const _HeroSkeleton(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(myCompetitionStatusProvider),
              ),
              data: (status) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _maybeAnnounceRankUp(status.tier.rankNo, status.tier.titleFa);
                });
                return CompetitionHeroCard(status: status);
              },
            ),
            const SizedBox(height: 14),
            const _LiveArenaBanner(),
            const SizedBox(height: 14),
            ref.watch(competitionStatsProvider).maybeWhen(
                  data: (stats) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: CompetitionStatsCard(stats: stats),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
            const SizedBox(height: 18),
            _SegmentedToggle(
              index: _tab,
              labels: [
                context.tr('competition.tabLeaderboard'),
                context.tr('competition.tabMissions'),
                context.tr('competition.tabRoadmap'),
              ],
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (_tab == 0)
              _buildLeaderboard(myId)
            else if (_tab == 1)
              _buildMissions()
            else
              _buildRoadmap(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(String? myId) {
    final entriesAsync = ref.watch(leaderboardProvider(_byGrade));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _ScopeToggle(
            byGrade: _byGrade,
            onChanged: (v) => setState(() => _byGrade = v),
          ),
        ),
        const SizedBox(height: 12),
        entriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(leaderboardProvider(_byGrade)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(context.tr('competition.leaderboardEmpty'),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              );
            }
            final top3 = entries.take(3).toList();
            final rest = entries.length > 3 ? entries.sublist(3) : <LeaderboardEntry>[];
            return Column(
              children: [
                LeaderboardPodium(top3: top3, myStudentId: myId),
                const SizedBox(height: 8),
                _DeltaTrackedLeaderboardRest(rest: rest, myId: myId),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoadmap() {
    final tiersAsync = ref.watch(rankTiersProvider);
    final statusAsync = ref.watch(myCompetitionStatusProvider);
    return tiersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(rankTiersProvider)),
      data: (tiers) => statusAsync.maybeWhen(
        data: (status) => LearningRoadmap(tiers: tiers, currentRankNo: status.tier.rankNo),
        orElse: () => LearningRoadmap(tiers: tiers, currentRankNo: 1),
      ),
    );
  }

  Widget _buildMissions() {
    final dailyAsync = ref.watch(dailyQuestsProvider);
    final missionsAsync = ref.watch(competitionMissionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── میشن‌های روزانه — هر روز صفر می‌شود، طبق سند طراحی رقابت ──
        Text(context.tr('competition.dailyQuestsTitle'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        dailyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(dailyQuestsProvider)),
          data: (quests) => Column(
            children: quests
                .map((q) => DailyQuestCard(quest: q, claiming: _claimingId == q.id, onClaim: () => _claimDaily(q)))
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        // ── دستاوردهای دائمی ──
        Text(context.tr('competition.achievementsTitle'),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        missionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(competitionMissionsProvider)),
          data: (missions) {
            final completed = missions.where((m) => m.claimed).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    context.tr('competition.missionsCompleted', {'completed': '$completed', 'total': '${missions.length}'}),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                ...missions.map(
                  (m) => MissionCard(mission: m, claiming: _claimingId == m.id, onClaim: () => _claim(m)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _SegmentedToggle({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.heroGradient : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: selected ? AppShadows.warm : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: selected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final bool byGrade;
  final ValueChanged<bool> onChanged;
  const _ScopeToggle({required this.byGrade, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? scheme.tertiaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? scheme.onTertiaryContainer : scheme.onSurfaceVariant)),
          ),
        );
    return Wrap(
      spacing: 8,
      children: [
        chip(context.tr('competition.scopeGlobal'), !byGrade, () => onChanged(false)),
        chip(context.tr('competition.scopeGrade'), byGrade, () => onChanged(true)),
      ],
    );
  }
}

/// بنرِ ورودیِ «آرنای زنده» بالای صفحهٔ رقابت — فقط وقتی رویدادی
/// برنامه‌ریزی‌شده/در حال برگزاری وجود دارد نشان داده می‌شود؛ اگر رویدادی
/// نبود یا شاگرد واجد‌شرایط نبود، کاملاً خودش را پنهان می‌کند تا فضای بی‌مورد
/// اشغال نکند (طبق سند طراحی رقابت: آرنا یک قابلیت «پیشرفته» است، نه بخش
/// همیشگی صفحه).
class _LiveArenaBanner extends ConsumerWidget {
  const _LiveArenaBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(liveArenaCurrentProvider);
    return infoAsync.maybeWhen(
      data: (info) {
        final event = info.event;
        if (event == null || !info.eligible || event.isEnded) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.go(AppRoutes.liveArena),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B1033), Color(0xFF3D1E6D)]),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.gold300, size: 26)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(end: 1.2, duration: 800.ms, curve: Curves.easeInOut),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(event.isLive ? 'liveArena.bannerLiveNow' : 'liveArena.bannerScheduled'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.titleFa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// فهرست ردیف‌های جدول (بعد از سکو) — موقعیتِ *قبلیِ* هر شاگرد را بین
/// تازه‌سازی‌ها به‌خاطر می‌سپارد (`didUpdateWidget`) تا [LeaderboardTile]
/// بتواند نشانگر ▲/▼ تغییرِ رتبه را نشان دهد. در اولین بارگذاری چیزی
/// نمی‌سازد (چون «قبلی» معنا ندارد).
class _DeltaTrackedLeaderboardRest extends StatefulWidget {
  final List<LeaderboardEntry> rest;
  final String? myId;
  const _DeltaTrackedLeaderboardRest({required this.rest, required this.myId});

  @override
  State<_DeltaTrackedLeaderboardRest> createState() => _DeltaTrackedLeaderboardRestState();
}

class _DeltaTrackedLeaderboardRestState extends State<_DeltaTrackedLeaderboardRest> {
  Map<String, int> _previousPositions = {};

  @override
  void didUpdateWidget(covariant _DeltaTrackedLeaderboardRest oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.rest.length != widget.rest.length ||
        Iterable.generate(oldWidget.rest.length).any((i) => oldWidget.rest[i].position != widget.rest[i].position);
    if (changed) {
      _previousPositions = {for (final e in oldWidget.rest) e.studentId: e.position};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.rest.asMap().entries.map((e) {
        return LeaderboardTile(
          entry: e.value,
          isMe: e.value.studentId == widget.myId,
          index: e.key,
          previousPosition: _previousPositions[e.value.studentId],
        );
      }).toList(),
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 700.ms).then().fadeOut(duration: 700.ms);
  }
}
