import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../shared_models/subject.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../domain/entities/study_plan.dart';
import '../providers/study_plan_providers.dart';

/// کارت «برنامهٔ درسی امروز من» در صفحهٔ خانه — قلب تپندهٔ یادگیری روزانه:
/// مضامینی که برای امروز برنامه‌ریزی شده، هرکدام با پیشرفت واقعی مضمون و
/// یک دکمهٔ اقدام که **دقیقاً به همان درس/آزمون/کار-خانگیِ نصاب درسی** باز
/// می‌شود (نگاه کنید به [todaySubjectPointerProvider]) — نه یک لینک ثابت به
/// گفت‌وگوی آزاد.
///
/// رفع اشکال پایداری: قبلاً `todayPlanProvider`/`weeklyPlanProvider` فقط
/// یک‌بار محاسبه می‌شدند و اگر برنامه بدون بسته شدن باز می‌ماند (شب تا صبح،
/// یا پنجشنبه تا شنبه)، این کارت همچنان روز/هفتهٔ قبلی را نشان می‌داد؛ حالا
/// (`study_plan_providers.dart`) با گذشت روز خودکار به‌روز می‌شود.
///
/// **رفع اشکال «منطق مضامین با نصاب درسی فرق دارد»:** درصد پیشرفتِ هر
/// مضمون هم اکنون از همان [gradeMapProvider] خوانده می‌شود که «نصاب
/// درسی»/شبکهٔ مضامین صنف می‌خواند — دیگر عددی جدا از آنچه شاگرد در نصاب
/// درسی می‌بیند نشان داده نمی‌شود.
class TodayScheduleCard extends ConsumerWidget {
  const TodayScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // با watch شدن به‌جای skipLoadingOnReload، بازسازی خودکار روزانه باعث
    // چشمک‌زدن نمی‌شود چون AsyncLoading حاصل از reload مقدار قبلی را نگه
    // می‌دارد و پایین همیشه با .valueOrNull خوانده می‌شود.
    final todayAsync = ref.watch(todayPlanProvider);
    final planAsync = ref.watch(weeklyPlanProvider);

    final studentId = ref.watch(authSessionProvider)?.id ?? 'unknown';
    final grade = ref.watch(activeGradeProvider);
    final gradeMapAsync = ref.watch(gradeMapProvider((studentId: studentId, grade: grade)));
    final progressMap = gradeMapAsync.maybeWhen(
      data: (map) => {for (final s in map.subjects) s.subjectId: s.completionPercent},
      orElse: () => const <String, double>{},
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(planAsync: planAsync, todayAsync: todayAsync, progressMap: progressMap),
          const SizedBox(height: 14),
          const _WeekStrip(),
          const SizedBox(height: 14),
          Builder(builder: (context) {
            final day = todayAsync.valueOrNull;

            if (todayAsync.isLoading && day == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (todayAsync.hasError && day == null) {
              return _TodayErrorState(
                error: todayAsync.error!,
                onRetry: () {
                  ref.invalidate(weeklyPlanProvider);
                  ref.invalidate(todayPlanProvider);
                },
              );
            }

            if (day == null || day.isRestDay) {
              return _RestDayBanner(
                  isFriday: DateTime.now().weekday == DateTime.friday);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < day.slots.length; i++)
                  _TimelineSlot(
                    slot: day.slots[i],
                    order: i + 1,
                    isLast: i == day.slots.length - 1,
                    percent: progressMap[day.slots[i].subjectId] ?? 0.0,
                  )
                      .animate(delay: (70 * i).ms)
                      .fadeIn(duration: 280.ms)
                      .slideX(begin: 0.06, end: 0, duration: 280.ms, curve: Curves.easeOutCubic),
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// سربرگ کارت: آیکون گرادیانی + عنوان/روز + یک حلقهٔ کوچک «میانگین پیشرفت
/// مضامینِ امروز» تا شاگرد از همان نگاه اول حس «کاریکولم زنده» بگیرد، نه
/// یک فهرست ایستا.
class _Header extends StatelessWidget {
  final AsyncValue<WeeklyStudyPlan> planAsync;
  final AsyncValue<PlanDay?> todayAsync;
  final Map<String, double> progressMap;
  const _Header({required this.planAsync, required this.todayAsync, required this.progressMap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = todayAsync.valueOrNull;
    final generatedBy = planAsync.valueOrNull?.generatedBy;
    final totalMinutes = day?.slots.fold<int>(0, (sum, s) => sum + s.minutes) ?? 0;

    double? avgPercent;
    if (day != null && day.slots.isNotEmpty) {
      final vals = day.slots.map((s) => progressMap[s.subjectId] ?? 0.0).toList();
      // مقادیر progressMap («نصاب درسی») همیشه بین ۰ تا ۱۰۰ هستند (خودِ
      // gradeMapProvider این را تضمین می‌کند)، پس نیازی به num.clamp()
      // نیست — عمداً از آن پرهیز شده چون clamp() برخلاف عملگرهای ریاضی
      // معمولی، double برنمی‌گرداند (بلکه num)، و اینجا فقط double لازم است.
      avgPercent = vals.reduce((a, b) => a + b) / vals.length;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (avgPercent != null)
              SizedBox(
                width: 48,
                height: 48,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: avgPercent / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withValues(alpha: .35),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.soft,
              ),
              child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(context.tr('studyPlan.todayTitle'),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  if (generatedBy != null) ...[
                    const SizedBox(width: 6),
                    _MiniBadge(
                      icon: generatedBy == 'ai' ? Icons.auto_awesome_rounded : Icons.psychology_alt_rounded,
                      label: generatedBy == 'ai'
                          ? context.tr('studyPlan.generatedByAi')
                          : context.tr('studyPlan.generatedBySmart'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    PlanDay.namesFa[DateTime.now().weekday] ?? '',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                  if (day != null && !day.isRestDay) ...[
                    Text('  •  ', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    Icon(Icons.timer_outlined, size: 12, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(
                      context.tr('studyPlan.todayMinutesLabel', {'minutes': '$totalMinutes'}),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.studyPlan),
          child: Text(context.tr('studyPlan.weekPlanButton')),
        ),
      ],
    );
  }
}

/// نوار هفته: ۷ نقطهٔ کوچک شنبه تا جمعه — امروز با گرادیان و ضربان
/// (pulse) برجسته می‌شود، تا کل تقسیم اوقات مثل یک تقویم درسی واقعی حس
/// شود، نه فقط یک کارت مجزا برای امروز.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip();

  static const _order = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now().weekday;
    return Row(
      children: [
        for (final wd in _order) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: wd == today ? AppColors.heroGradient : null,
                    color: wd == today ? null : scheme.outlineVariant.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                    .animate(target: wd == today ? 1 : 0)
                    .scaleY(begin: 1, end: 1.6, duration: 500.ms, curve: Curves.easeOut)
                    .then()
                    .scaleY(begin: 1.6, end: 1, duration: 500.ms, curve: Curves.easeIn),
                const SizedBox(height: 4),
                Builder(builder: (context) {
                  final name = PlanDay.namesFa[wd] ?? '';
                  return Text(
                    name.isEmpty ? '' : name.substring(0, 1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: wd == today ? FontWeight.w800 : FontWeight.w600,
                      color: wd == today ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  );
                }),
              ],
            ),
          ),
          if (wd != _order.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _TodayErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _TodayErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 28, color: scheme.error),
          const SizedBox(height: 8),
          Text(
            context.tr('studyPlan.loadError', {'error': '$error'}),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.tr('common.retry')),
          ),
        ],
      ),
    );
  }
}

class _RestDayBanner extends StatelessWidget {
  final bool isFriday;
  const _RestDayBanner({required this.isFriday});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isFriday
            ? AppColors.sunriseGradient
            : LinearGradient(
                colors: [
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerHighest,
                ],
              ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isFriday
                  ? Colors.white.withValues(alpha: .22)
                  : scheme.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFriday ? Icons.self_improvement_rounded : Icons.menu_book_rounded,
              size: 26,
              color: isFriday ? Colors.white : scheme.primary,
            ),
          ).animate().scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 320.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 10),
          Text(
            isFriday
                ? context.tr('studyPlan.fridayRest')
                : context.tr('studyPlan.noBooksYet'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: isFriday ? Colors.white : scheme.onSurface,
            ),
          ),
          if (!isFriday) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: AppPrimaryButton(
                label: context.tr('studyPlan.browseBooksCta'),
                icon: Icons.menu_book_rounded,
                onPressed: () => context.push(AppRoutes.curriculum),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// متن وضعیتِ زندهٔ هر جلسه — همیشه از [pointer] (نصاب درسی زنده) می‌آید؛
/// فقط وقتی هنوز بارگذاری نشده یا این مضمون اصلاً نصاب ندارد، به متن
/// انگیزشیِ ذخیره‌شدهٔ [slot.focusFa] برمی‌گردد.
String _resolveFocusFa(TodaySubjectPointer? pointer, StudySlot slot, {required bool loading}) {
  if (loading || pointer == null) return slot.focusFa;
  switch (pointer.action) {
    case 'quiz':
      return 'آزمون فصل آماده است — وقتشه بدهی! 📝';
    case 'homework':
      return 'منتظر ارسال کار خانگیِ «${pointer.lessonTitleFa ?? ''}» — بعد از ارسال، درس بعدی باز می‌شود.';
    case 'lesson':
      return slot.isNew
          ? 'شروع مضمون تازه: «${pointer.lessonTitleFa ?? ''}»'
          : 'ادامه: «${pointer.lessonTitleFa ?? ''}»';
    case 'chapters':
      return 'فصل‌های این مضمون را در نصاب درسی ببین';
    default: // 'chat'
      return slot.focusFa;
  }
}

/// آیکونِ متناظر با نوع اقدام هر جلسه — بخشی از زبان بصریِ «گویا»: شاگرد با
/// یک نگاه می‌فهمد آیا باید درس تازه بخواند، آزمون بدهد، یا منتظر ارسال کار
/// خانگی است.
IconData _actionIcon(String? action) => switch (action) {
      'quiz' => Icons.quiz_rounded,
      'homework' => Icons.edit_note_rounded,
      'chapters' => Icons.menu_book_rounded,
      _ => Icons.play_arrow_rounded,
    };

/// دایرهٔ کوچک آیکون-اقدام در انتهای هر کارت جلسه؛ تا وقتی نقطهٔ زندهٔ نصاب
/// درسی هنوز نیامده یک اسپینر کوچک نشان می‌دهد (نه آیکونِ حدسی)؛ وقتی
/// [pulse] فعال است (آزمون/کار خانگیِ در انتظار) با همان الگوی پالسِ ملایمِ
/// استفاده‌شده در `chapters_screen.dart` برای quizPending می‌تپد — زبان
/// بصری یکسان برای «اینجا باید اقدام کنی» در سراسر برنامه.
Widget _actionIconAvatar({
  required Color accentColor,
  required String? action,
  required bool loading,
  required bool pulse,
}) {
  if (loading) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: accentColor.withValues(alpha: .6)),
        ),
      ),
    );
  }
  final icon = Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: accentColor.withValues(alpha: .12), shape: BoxShape.circle),
    child: Icon(_actionIcon(action), color: accentColor, size: 20),
  );
  if (!pulse) return icon;
  return icon
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .scaleXY(begin: 1.0, end: 1.12, duration: 750.ms, curve: Curves.easeInOut);
}

/// یک جلسهٔ برنامهٔ امروز، در قالب «مسیر/Timeline»: دایرهٔ شماره+پیشرفت به
/// یک خط عمودی به جلسهٔ بعدی وصل می‌شود — دقیقاً حس یک نقشهٔ کاریکولم روزانه
/// که قدم‌به‌قدم پیش می‌رود، نه یک فهرست ساده. مضامینی که تازه به شاگرد
/// معرفی می‌شوند («هنوز شروع نشده» + این هفته اولین بار) نشان «مضمون جدید»
/// می‌گیرند؛ جلساتی که منتظر آزمون یا کار خانگی‌اند («needsAction») با رنگ
/// نارنجیِ هشدار و ضربان ملایم برجسته می‌شوند تا شاگرد بداند اینجا باید
/// اقدامی انجام دهد، نه فقط «ادامه بدهد».
///
/// **هماهنگی زنده با نصاب درسی:** این ویجت [todaySubjectPointerProvider]
/// را `watch` می‌کند — یعنی هر بار که این کارت دیده می‌شود (نه فقط هفته‌ای
/// یک‌بار)، دقیقاً همان جایی از نصاب درسی که این مضمون *الان* ایستاده
/// خوانده می‌شود؛ اگر همین لحظه یک کار خانگی ارسال شده باشد، این کارت هم
/// بلافاصله همان درس/آزمون تازه‌بازشده را نشان می‌دهد.
class _TimelineSlot extends ConsumerWidget {
  final StudySlot slot;
  final int order;
  final bool isLast;
  final double percent;
  const _TimelineSlot({
    required this.slot,
    required this.order,
    required this.isLast,
    required this.percent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subject = mockSubjects.firstWhere((s) => s.id == slot.subjectId,
        orElse: () => mockSubjects.first);
    final color = Color(subject.colorValue);

    final pointerAsync = ref.watch(todaySubjectPointerProvider(slot.subjectId));
    final pointer = pointerAsync.valueOrNull;
    final loading = pointerAsync.isLoading && pointer == null;
    final action = pointer?.action;
    final focusFa = _resolveFocusFa(pointer, slot, loading: loading);
    // آزمون/کار خانگیِ در انتظار = «باید همین حالا اقدام کنی»، نه فقط
    // «ادامه بده» — با رنگ نارنجیِ هشدار (هم‌رنگ با حالت مشابه در
    // chapters_screen.dart) از رنگ خنثای مضمون جدا می‌شود.
    final needsAction = action == 'quiz' || action == 'homework';
    final accentColor = needsAction ? AppColors.orange600 : color;

    return IntrinsicHeight(
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ستون مسیر: دایرهٔ شماره/پیشرفت + خط اتصال به جلسهٔ بعد.
            Column(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percent / 100,
                        strokeWidth: 3.4,
                        backgroundColor: color.withValues(alpha: .15),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                      Text('$order',
                          style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 13)),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Center(
                        child: Container(
                          width: 2,
                          color: scheme.outlineVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: accentColor.withValues(alpha: needsAction ? .09 : .07),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  onTap: loading
                      ? null
                      : () => openTodaySubjectPointer(context, ref,
                          subjectId: slot.subjectId, pointer: pointer),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(
                        color: accentColor.withValues(alpha: needsAction ? .4 : .18),
                        width: needsAction ? 1.3 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(slot.subjectNameFa,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
                                  if (slot.isNew) ...[
                                    const SizedBox(width: 6),
                                    _NewBadge(color: color),
                                  ],
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      context.tr('curriculum.estimatedMinutes', {'minutes': '${slot.minutes}'}),
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(focusFa,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _actionIconAvatar(
                            accentColor: accentColor, action: action, loading: loading, pulse: needsAction),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// نشان «مضمون جدید» — با درخشش ملایم، برای اولین‌باری که یک مضمونِ
/// نصاب درسی امروز به شاگرد پیشنهاد می‌شود.
class _NewBadge extends StatelessWidget {
  final Color color;
  const _NewBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: .6)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 9, color: Colors.white),
          const SizedBox(width: 2),
          Text(context.tr('studyPlan.newSubjectBadge'),
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.06, duration: 700.ms, curve: Curves.easeInOut);
  }
}
