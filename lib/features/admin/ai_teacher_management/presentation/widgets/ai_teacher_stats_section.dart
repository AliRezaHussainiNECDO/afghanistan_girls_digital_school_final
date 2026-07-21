import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../domain/entities/ai_teacher_stats.dart';
import '../providers/ai_teacher_management_providers.dart';

/// آمار حقیقی استفاده از معلم هوشمند — بالای پنل «مدیریت معلم هوشمند».
/// قبلاً این بخش هیچ فیلد آماری نداشت (نه واقعی، نه ساختگی)؛ این ویجت
/// مستقیماً از لاگ واقعی گفتگوهای موتور ابری می‌خواند (طبق همان اصل «آمار
/// حقیقی» که در داشبورد مدیر/شاگرد/والد رعایت شده) — اگر هنوز هیچ گفتگویی
/// رخ نداده، همه‌چیز صادقانه صفر نشان داده می‌شود.
class AiTeacherStatsSection extends ConsumerWidget {
  const AiTeacherStatsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(aiTeacherStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => ErrorView(
            error: e,
            onRetry: () => ref.invalidate(aiTeacherStatsProvider),
          ),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.query_stats_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Text(context.tr('aiTeacherStats.sectionTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              _StatCard(
                icon: Icons.forum_rounded,
                label: context.tr('aiTeacherStats.totalMessages'),
                value: '${stats.totalMessages}',
                gradient: AppColors.heroGradient,
              ),
              _StatCard(
                icon: Icons.today_rounded,
                label: context.tr('aiTeacherStats.messagesToday'),
                value: '${stats.messagesToday}',
                gradient: AppColors.successGradient,
              ),
              _StatCard(
                icon: Icons.person_rounded,
                label: context.tr('aiTeacherStats.activeStudentsToday'),
                value: '${stats.activeStudentsToday}',
                gradient: AppColors.heroGradientWarm,
              ),
              _StatCard(
                icon: Icons.groups_rounded,
                label: context.tr('aiTeacherStats.activeStudentsWeek'),
                value: '${stats.activeStudentsWeek}',
                gradient: AppColors.sunriseGradient,
              ),
              _StatCard(
                icon: Icons.track_changes_rounded,
                label: context.tr('aiTeacherStats.accuracyLabel'),
                value: stats.accuracyPercent != null
                    ? '${stats.accuracyPercent!.toStringAsFixed(0)}٪'
                    : '—',
                gradient: const LinearGradient(colors: [AppColors.green600, Color(0xFF2E7D32)]),
              ),
              _StatCard(
                icon: Icons.auto_awesome_rounded,
                label: context.tr('aiTeacherStats.embeddingCoverageLabel'),
                value: stats.embeddingCoveragePercent != null
                    ? '${stats.embeddingCoveragePercent!.toStringAsFixed(0)}٪'
                    : '—',
                gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
              ),
            ],
          ),
          if (stats.bySubject.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(context.tr('aiTeacherStats.topSubjectsLabel'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            ...[
              for (var i = 0; i < stats.bySubject.length; i++)
                _SubjectUsageRow(
                  usage: stats.bySubject[i],
                  maxCount: stats.bySubject.first.messageCount,
                ),
            ],
          ] else if (stats.totalMessages == 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('aiTeacherStats.noConversationsYet'),
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((stats.embeddingCoveragePercent ?? 100) < 99.5) ...[
            const SizedBox(height: 10),
            const _EmbeddingBackfillButton(),
          ],
        ],
      ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

/// دکمهٔ «بازسازی نمایهٔ معنایی برای همهٔ صنوف/مضامین» — برای درس‌هایی که
/// پیش از فعال‌شدن بازیابی معنایی منتشر شده‌اند (یا Embedding‌شان ناموفق
/// مانده). یک کلیک، همهٔ صنوف و مضامین را پوشش می‌دهد.
class _EmbeddingBackfillButton extends ConsumerStatefulWidget {
  const _EmbeddingBackfillButton();

  @override
  ConsumerState<_EmbeddingBackfillButton> createState() => _EmbeddingBackfillButtonState();
}

class _EmbeddingBackfillButtonState extends ConsumerState<_EmbeddingBackfillButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(apiClientProvider).post('/admin/ai-teacher/embeddings/backfill');
      final queued = (data is Map ? data['queued'] as num? : null) ?? 0;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(queued > 0
            ? context.tr('aiTeacherStats.embeddingQueuedToast', {'count': '$queued'})
            : context.tr('aiTeacherStats.embeddingAlreadyDoneToast')),
      ));
      ref.invalidate(aiTeacherStatsProvider);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(context.tr('aiTeacherStats.embeddingFailedToast'))));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: _running ? null : _run,
      icon: _running
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome_rounded, size: 16),
      label: Text(
        _running ? context.tr('aiTeacherStats.embeddingInProgress') : context.tr('aiTeacherStats.embeddingBackfillButton'),
        style: const TextStyle(fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Gradient gradient;
  const _StatCard({required this.icon, required this.label, required this.value, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const Spacer(),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SubjectUsageRow extends StatelessWidget {
  final AiTeacherSubjectUsage usage;
  final int maxCount;
  const _SubjectUsageRow({required this.usage, required this.maxCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = maxCount > 0 ? usage.messageCount / maxCount : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(usage.subjectNameFa,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.02, 1.0),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('${usage.messageCount}',
                textAlign: TextAlign.left, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
