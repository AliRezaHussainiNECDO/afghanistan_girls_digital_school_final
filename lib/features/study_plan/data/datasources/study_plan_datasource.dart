import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ai_teacher/data/datasources/learning_progress_datasource.dart';
import '../../../ai_teacher/domain/entities/learning_progress.dart';
import '../../domain/entities/study_plan.dart';

/// سازندهٔ «تقسیم اوقات هوشمند» — قلب برنامه‌ریزی درسی:
///
/// ۱. اگر Ollama (روی کامپیوتر سرور) فعال باشد، برنامهٔ هفتگی توسط خود مدل
///    هوش مصنوعی بر اساس پیشرفت/عقب‌ماندگی هر مضمون ساخته می‌شود.
/// ۲. اگر نه، الگوریتم اولویت‌بندی محلی همان کار را انجام می‌دهد (مضامین
///    عقب‌مانده و مدت‌ها مطالعه‌نشده سهم بیشتری می‌گیرند).
///
/// برنامه هفته‌ای یک‌بار ساخته و ذخیره می‌شود؛ «تولید دوباره» دستی هم ممکن است.
class StudyPlanDataSource {
  final LearningProgressDataSource progress;
  StudyPlanDataSource(this.progress);

  static const _planKey = 'study_plan_v2';
  static const schoolDays = [
    DateTime.saturday,
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
  ];

  /// کلید هفتهٔ جاری — هفتهٔ افغانستان از شنبه شروع می‌شود.
  static String currentWeekKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    // شنبهٔ همین هفته را پیدا کن.
    final daysFromSaturday = (d.weekday - DateTime.saturday + 7) % 7;
    final saturday = DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: daysFromSaturday));
    final firstDay = DateTime(saturday.year, 1, 1);
    final week = ((saturday.difference(firstDay).inDays) / 7).floor() + 1;
    return '${saturday.year}-W$week';
  }

  /// کلید ذخیرهٔ برنامهٔ هفتگی — به‌ازای هر صنف جدا (با ارتقای صنف، برنامهٔ
  /// صنف قبلی باقی می‌ماند اما دیگر بارگذاری نمی‌شود؛ برنامهٔ صنف جدید تازه
  /// ساخته می‌شود).
  String _planKeyFor(int grade) => '${_planKey}_g$grade';

  Future<WeeklyStudyPlan> getCurrentPlan({bool regenerate = false, required int grade}) async {
    final prefs = await SharedPreferences.getInstance();
    final weekKey = currentWeekKey();
    final planKey = _planKeyFor(grade);

    if (!regenerate) {
      final raw = prefs.getString(planKey);
      if (raw != null) {
        try {
          final stored = WeeklyStudyPlan.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
          if (stored.weekKey == weekKey && stored.days.isNotEmpty) {
            return stored;
          }
        } catch (_) {}
      }
    }

    final all = await progress.getAll(grade);
    // فقط مضامینی که کتاب دارند برنامه‌ریزی می‌شوند.
    final withBooks = all.where((p) => p.hasBook).toList();

    WeeklyStudyPlan plan;
    if (withBooks.isEmpty) {
      plan = WeeklyStudyPlan(
        weekKey: weekKey,
        generatedAt: DateTime.now(),
        generatedBy: 'smart',
        days: [
          for (final wd in schoolDays) PlanDay(weekday: wd, slots: const []),
          const PlanDay(weekday: DateTime.friday, slots: []),
        ],
      );
    } else {
      plan = await _generateWithOllama(weekKey, withBooks) ??
          _generateSmart(weekKey, withBooks);
    }

    await prefs.setString(planKey, jsonEncode(plan.toJson()));
    return plan;
  }

  // ── تولید با هوش مصنوعی (Ollama روی کامپیوتر سرور) ────────────────────────
  Future<WeeklyStudyPlan?> _generateWithOllama(
      String weekKey, List<SubjectLearningProgress> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final useOllama = prefs.getBool('ai_engine_use_ollama') ?? false;
    if (!useOllama) return null;
    final baseUrl =
        prefs.getString('ai_engine_base_url') ?? 'http://localhost:11434';
    final model = prefs.getString('ai_engine_model') ?? 'llama3.1';

    final subjectLines = subjects
        .map((p) =>
            '- ${p.subjectId} (${p.subjectNameFa}): پیشرفت ${p.percent.toStringAsFixed(0)}٪، ${p.daysSinceStudy >= 999 ? 'هرگز مطالعه نشده' : '${p.daysSinceStudy} روز از آخرین مطالعه'}')
        .join('\n');

    final prompt = '''
تو برنامه‌ریز درسی یک مکتب دیجیتال هستی. برای یک دانش‌آموز با وضعیت زیر، تقسیم اوقات هفتگی بساز (شنبه تا پنجشنبه، جمعه رخصتی). هر روز دقیقاً ۳ جلسه. مضامین عقب‌مانده یا مدت‌ها مطالعه‌نشده را بیشتر بگنجان.

وضعیت مضامین:
$subjectLines

فقط JSON خالص با این ساختار بده، بدون هیچ متن اضافه:
{"days":[{"weekday":"saturday","slots":[{"subjectId":"math","focusFa":"...","minutes":45}]}]}
مقادیر weekday فقط: saturday, sunday, monday, tuesday, wednesday, thursday
مقادیر subjectId فقط از این‌ها: ${subjects.map((s) => s.subjectId).join(', ')}
focusFa یک جملهٔ کوتاه دری دربارهٔ تمرکز آن جلسه باشد.
''';

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 120),
      ));
      final res = await dio.post('$baseUrl/api/generate', data: {
        'model': model,
        'prompt': prompt,
        'stream': false,
        'format': 'json',
      });
      final text = (res.data is Map ? res.data['response'] as String? : null);
      if (text == null || text.trim().isEmpty) return null;

      final parsed = jsonDecode(text.trim()) as Map;
      const wdMap = {
        'saturday': DateTime.saturday,
        'sunday': DateTime.sunday,
        'monday': DateTime.monday,
        'tuesday': DateTime.tuesday,
        'wednesday': DateTime.wednesday,
        'thursday': DateTime.thursday,
      };
      final validIds = subjects.map((s) => s.subjectId).toSet();
      final nameOf = {for (final s in subjects) s.subjectId: s.subjectNameFa};

      final days = <PlanDay>[];
      for (final rawDay in (parsed['days'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(rawDay as Map);
        final wd = wdMap[(m['weekday'] as String?)?.toLowerCase()];
        if (wd == null) continue;
        final slots = <StudySlot>[];
        for (final rawSlot in (m['slots'] as List? ?? [])) {
          final sm = Map<String, dynamic>.from(rawSlot as Map);
          final id = sm['subjectId'] as String?;
          if (id == null || !validIds.contains(id)) continue;
          slots.add(StudySlot(
            subjectId: id,
            subjectNameFa: nameOf[id] ?? id,
            focusFa: (sm['focusFa'] as String?)?.trim().isNotEmpty == true
                ? (sm['focusFa'] as String).trim()
                : 'ادامهٔ درس با معلم هوشمند',
            minutes: ((sm['minutes'] as num?)?.toInt() ?? 45).clamp(20, 90).toInt(),
          ));
        }
        if (slots.isNotEmpty) days.add(PlanDay(weekday: wd, slots: slots));
      }

      // برنامهٔ معتبر باید حداقل ۴ روز درسی داشته باشد.
      if (days.length < 4) return null;
      // روزهای جامانده را با الگوریتم محلی پر کن + جمعه رخصتی.
      final covered = days.map((d) => d.weekday).toSet();
      final fallback = _generateSmart(weekKey, subjects);
      for (final d in fallback.days) {
        if (!covered.contains(d.weekday)) days.add(d);
      }
      days.sort((a, b) => _dayOrder(a.weekday).compareTo(_dayOrder(b.weekday)));

      return WeeklyStudyPlan(
        weekKey: weekKey,
        generatedAt: DateTime.now(),
        generatedBy: 'ai',
        days: days,
      );
    } catch (_) {
      return null; // هر خطا → الگوریتم محلی
    }
  }

  static int _dayOrder(int weekday) => (weekday - DateTime.saturday + 7) % 7;

  // ── الگوریتم اولویت‌بندی محلی (بدون نیاز به هوش مصنوعی) ───────────────────
  WeeklyStudyPlan _generateSmart(
      String weekKey, List<SubjectLearningProgress> subjects) {
    // امتیاز نیاز: پیشرفت کمتر + مطالعه‌نشدهٔ طولانی‌تر = اولویت بالاتر.
    final ranked = List<SubjectLearningProgress>.from(subjects)
      ..sort((a, b) {
        final scoreA = (100 - a.percent) + a.daysSinceStudy.clamp(0, 30) * 2;
        final scoreB = (100 - b.percent) + b.daysSinceStudy.clamp(0, 30) * 2;
        return scoreB.compareTo(scoreA);
      });

    final days = <PlanDay>[];
    var cursor = 0;
    for (final wd in schoolDays) {
      final slots = <StudySlot>[];
      for (var i = 0; i < 3 && ranked.isNotEmpty; i++) {
        final p = ranked[cursor % ranked.length];
        cursor++;
        final isReview = p.percent >= 80;
        slots.add(StudySlot(
          subjectId: p.subjectId,
          subjectNameFa: p.subjectNameFa,
          focusFa: isReview
              ? 'مرور و تمرین بخش‌های خوانده‌شده'
              : p.currentSectionIndex == 0
                  ? 'شروع درس از ابتدای کتاب'
                  : 'ادامهٔ درس از بخش ${p.currentSectionIndex + 1} کتاب',
          minutes: 45,
        ));
      }
      days.add(PlanDay(weekday: wd, slots: slots));
    }
    days.add(const PlanDay(weekday: DateTime.friday, slots: []));

    return WeeklyStudyPlan(
      weekKey: weekKey,
      generatedAt: DateTime.now(),
      generatedBy: 'smart',
      days: days,
    );
  }
}
