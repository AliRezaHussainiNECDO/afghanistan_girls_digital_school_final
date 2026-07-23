import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../../../student_dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/homework.dart';
import '../../domain/usecases/homework_usecases.dart';
import '../providers/homework_providers.dart';
import '../widgets/homework_card.dart';
import '../widgets/homework_chat_thread_view.dart';

/// داشبورد «مشق کاغذی + نمره‌دهی هوشمند» — شاگرد روی کاغذ حل می‌کند، عکس
/// می‌فرستد و بلافاصله نمره/بازخورد هوش مصنوعی می‌بیند. فهرست همیشه با صنف
/// *فعلی* شاگرد هماهنگ است (سرور خودکار فیلتر می‌کند — `GET /homework`)، پس
/// با هر ارتقای صنف، بدون هیچ تغییری در این صفحه، مشق‌های صنف تازه نشان
/// داده می‌شود.
///
/// طراحی عمداً «سینمایی و تیره» است (پس‌زمینهٔ ثابت تیره صرف‌نظر از تم روشن/
/// تاریک کلی اپ) — دقیقاً همان الگویی که پنل پخش زندهٔ سمینار
/// (`SeminarBroadcastScreen`) برای تجربه‌ای غوطه‌ورتر استفاده می‌کند.
class HomeworkDashboardScreen extends ConsumerStatefulWidget {
  const HomeworkDashboardScreen({super.key});

  @override
  ConsumerState<HomeworkDashboardScreen> createState() => _HomeworkDashboardScreenState();
}

class _HomeworkDashboardScreenState extends ConsumerState<HomeworkDashboardScreen> {
  final Set<String> _uploadingIds = {};

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF201A14),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                title: Text(context.tr('homework.sourceCameraLabel'), style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
                title: Text(context.tr('homework.sourceGalleryLabel'), style: const TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _captureAndSubmit(Homework hw) async {
    final source = await _chooseSource();
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
    } catch (_) {
      if (!mounted) return;
      _snack(context.tr('homework.pickImageError'));
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _uploadingIds.add(hw.id));
    try {
      final bytes = await file.readAsBytes();
      final result = await ref.read(submitHomeworkPhotoUseCaseProvider).call(
            SubmitHomeworkPhotoParams(
              homeworkId: hw.id,
              bytes: bytes,
              fileName: file.name,
              contentType: _mimeFromName(file.name),
            ),
          );
      if (!mounted) return;
      result.fold(
        (f) => _snack(f.message),
        (updated) {
          ref.invalidate(homeworksProvider);
          // رفع اشکال «مشق را فرستادم ولی درس بعدی هنوز قفل نشان داده می‌شود»:
          // این وضعیت واقعاً به نمرهٔ AI ربطی ندارد (سرور با هر وضعیت
          // submitted/graded درس را باز می‌کند — backend/src/lib/progress.ts)،
          // مشکل واقعی این بود که فقط `homeworksProvider` باطل می‌شد؛ صفحهٔ
          // «فهرست درس‌ها»/«فصل‌ها»/«خانه»/«نقشهٔ صنوف» که ممکن است هنوز در
          // پشتهٔ ناوبری زنده باشند، هرگز خبردار نمی‌شدند و قفل/تکمیل‌شدهٔ
          // کهنه نشان می‌دادند. حالا همهٔ این Providerها هم باطل می‌شوند تا
          // بازگشت به آن صفحات فوراً وضعیت تازه را نشان دهد.
          if (updated.chapterId.isNotEmpty) ref.invalidate(lessonsProvider(updated.chapterId));
          if (updated.subjectId.isNotEmpty) ref.invalidate(chaptersProvider(updated.subjectId));
          if (updated.lessonId.isNotEmpty) ref.invalidate(lessonProvider(updated.lessonId));
          final studentId = ref.read(authSessionProvider)?.id;
          if (studentId != null) ref.invalidate(dashboardSummaryProvider(studentId));
          ref.invalidate(gradeMapProvider);
          _snack(
            updated.isGraded
                ? context.tr('homework.gradedSnack', {'score': '${updated.aiScore}'})
                : context.tr('homework.submittedSnack'),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _uploadingIds.remove(hw.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeworksAsync = ref.watch(homeworksProvider);
    final activeFilter = ref.watch(homeworkStatusFilterProvider);

    return AppScaffold(
      title: context.tr('homework.title'),
      role: AppUserRole.student,
      body: Container(
        color: AppColors.darkSurface,
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.gold500,
            backgroundColor: AppColors.darkSurfaceHigh,
            onRefresh: () async => ref.invalidate(homeworksProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _SunriseHeader(
                    classLevel: homeworksAsync.valueOrNull?.classLevel,
                    averageScore: homeworksAsync.valueOrNull?.averageScore,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                    child: _FilterChipsRow(activeFilter: activeFilter),
                  ),
                ),
                homeworksAsync.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(color: AppColors.gold500)),
                  ),
                  error: (e, st) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(error: e, onRetry: () => ref.invalidate(homeworksProvider)),
                  ),
                  data: (result) {
                    if (result.homeworks.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.assignment_turned_in_rounded, size: 56, color: Colors.white24),
                                const SizedBox(height: 14),
                                Text(
                                  context.tr('homework.emptyState'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white60, fontSize: 13.5, height: 1.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final hw = result.homeworks[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: HomeworkCard(
                                homework: hw,
                                uploading: _uploadingIds.contains(hw.id),
                                onCapture: () => _captureAndSubmit(hw),
                                onOpenChat: () => showHomeworkChatThreadView(context, hw),
                              )
                                  .animate()
                                  .fadeIn(delay: (i * 50).ms, duration: 320.ms)
                                  .slideY(begin: 0.08, end: 0, delay: (i * 50).ms, duration: 320.ms, curve: Curves.easeOutCubic),
                            );
                          },
                          childCount: result.homeworks.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// هدر گرادیان طلوع (Sunrise) — صنف فعلی + میانگین نمرهٔ شاگرد.
class _SunriseHeader extends StatelessWidget {
  final int? classLevel;
  final double? averageScore;
  const _SunriseHeader({required this.classLevel, required this.averageScore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.sunriseGradient,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          boxShadow: AppShadows.warm,
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('homework.headerTitle'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    classLevel != null
                        ? context.tr('homework.classLabel', {'grade': '$classLevel'})
                        : '',
                    style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                children: [
                  Text(
                    averageScore != null ? averageScore!.toStringAsFixed(0) : '—',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(context.tr('homework.averageScoreShort'),
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: -0.06, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// نوار فیلتر — نسخهٔ سفارشی (نه `ChoiceChip` پیش‌فرض متریال) تا رنگ واقعاً
/// همان چیزی باشد که طراحی می‌کنیم؛ `Chip` در متریال ۳ یک لایهٔ
/// `surfaceTintColor` روی پس‌زمینه می‌گذارد که با آن ترکیب می‌شود و باعث
/// می‌شد حالت غیرفعال به‌جای شیشه‌ای/تیره، کدر و سفیدرنگ به نظر برسد — رفع
/// اشکال دقیقاً همین («جذاب نیست، پس‌زمینهٔ سفید»). حالا هر دکمه با
/// `AnimatedContainer` + `AnimatedScale` خودش رنگ/اندازه را نرم عوض می‌کند و
/// حالت فعال با همان گرادیان طلوع (Sunrise) سربرگ هماهنگ است.
class _FilterChipsRow extends ConsumerWidget {
  final HomeworkStatus? activeFilter;
  const _FilterChipsRow({required this.activeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = <(String, HomeworkStatus?, IconData)>[
      (context.tr('homework.filterAll'), null, Icons.apps_rounded),
      (context.tr('homework.filterPending'), HomeworkStatus.pending, Icons.edit_note_rounded),
      (context.tr('homework.filterSubmitted'), HomeworkStatus.submitted, Icons.hourglass_top_rounded),
      (context.tr('homework.filterGraded'), HomeworkStatus.graded, Icons.workspace_premium_rounded),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status, icon) = options[i];
          return _FilterPill(
            label: label,
            icon: icon,
            selected: activeFilter == status,
            onTap: () => ref.read(homeworkStatusFilterProvider.notifier).state = status,
          )
              .animate()
              .fadeIn(delay: (i * 60).ms, duration: 300.ms)
              .slideX(begin: 0.15, end: 0, delay: (i * 60).ms, duration: 300.ms, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

/// یک دکمهٔ فیلتر «کپسولی» با انیمیشن فشردن (Scale) + گذار نرم رنگ هنگام
/// انتخاب/عدم‌انتخاب — حس لمسی پویا و مدرن، بدون وابستگی به تم پیش‌فرض Chip.
class _FilterPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  double _scale = 1.0;

  void _setScale(double v) {
    if (mounted) setState(() => _scale = v);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => _setScale(0.93),
      onTapCancel: () => _setScale(1.0),
      onTapUp: (_) => _setScale(1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.sunriseGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? Colors.transparent : Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: selected ? AppShadows.warm : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: selected ? Colors.white : Colors.white60),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
