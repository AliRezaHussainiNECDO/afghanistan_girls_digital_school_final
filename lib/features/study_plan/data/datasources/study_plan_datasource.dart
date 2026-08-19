import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ai_teacher/data/datasources/learning_progress_datasource.dart';
import '../../../ai_teacher/domain/entities/learning_progress.dart';
import '../../../grade_map/domain/entities/grade_map.dart';
import '../../../grade_map/domain/repositories/grade_map_repository.dart';
import '../../domain/entities/study_plan.dart';

/// **معماری هماهنگی «امروز» ↔ «نصاب درسی» (نگاه کلی):**
///
/// این کلاس فقط یک تصمیم می‌گیرد: «امروز کدام مضامین، به چه ترتیبی، چقدر
/// وقت» — یعنی همان چیزی که منطقاً می‌تواند هفته‌ای یک‌بار تصمیم‌گیری و
/// Cache شود (چرخش/اولویت‌بندی مضامین). این کلاس دیگر **هیچ تصمیمی دربارهٔ
/// اینکه دقیقاً کدام درس/فصل/آزمون باز است نمی‌گیرد** و دیگر به
/// `CurriculumRepository` هم وابسته نیست.
///
/// رفع اشکال ریشه‌ای «این دو بخش یک منبع معلومات را نمی‌گیرند»: نسخهٔ قبلی
/// این تصمیم را هم اینجا می‌گرفت — یک‌بار، در لحظهٔ ساختِ برنامهٔ هفتگی — و
/// نتیجه (کدام درس/فصل دقیقاً باز است) را همراه بقیهٔ برنامه در
/// SharedPreferences ذخیره می‌کرد. مشکل: نصاب درسی خودش هرگز چنین کاری
/// نمی‌کند — `chaptersProvider`/`lessonsProvider` (نگاه کنید به
/// `curriculum_providers.dart`) هر دو `autoDispose` هستند و هر بار صفحهٔ
/// فصل‌ها/درس‌ها باز می‌شود، دوباره زنده از سرور خوانده می‌شوند. یعنی وقتی
/// شاگرد یک کار خانگی ارسال می‌کرد، نصاب درسی بلافاصله درس بعدی را باز
/// می‌دید، ولی «امروز» تا آخر همان هفته (یا تا زدن دستیِ «برنامهٔ نو بساز»)
/// همان اشارهٔ کهنه/ذخیره‌شده را نشان می‌داد — دقیقاً همان بی‌هماهنگی‌ای که
/// کاربر گزارش داد.
///
/// راه‌حل: «کدام درس/فصل/آزمون دقیقاً باز است» دیگر اینجا محاسبه و ذخیره
/// نمی‌شود؛ به‌جایش هر بار که کارت «امروز» روی صفحه می‌آید، مستقیماً از همان
/// دو Provider زندهٔ نصاب درسی خوانده می‌شود (`todaySubjectPointerProvider`
/// در `study_plan_providers.dart`) — دقیقاً همان‌طور که خودِ نصاب درسی
/// می‌خواند، بدون هیچ کش جداگانه‌ای. نتیجه: نصاب درسی تنها منبع حقیقت
/// («ریشه») برای «کدام درس» است؛ این کلاس فقط مسئول «کدام مضمون، کدام روز» است.
class _PlanSubject {
  final String subjectId;
  final String subjectNameFa;
  final double percent;
  final SubjectProgressStatus status;
  final int daysSinceStudy;
  final int currentSectionIndex;

  const _PlanSubject({
    required this.subjectId,
    required this.subjectNameFa,
    required this.percent,
    required this.status,
    required this.daysSinceStudy,
    required this.currentSectionIndex,
  });
}

/// سازندهٔ «تقسیم اوقات هوشمند» — قلب برنامه‌ریزی درسی:
///
/// ۱. اگر Ollama (روی کامپیوتر سرور) فعال باشد، برنامهٔ هفتگی توسط خود مدل
///    هوش مصنوعی بر اساس پیشرفت/عقب‌ماندگی هر مضمون ساخته می‌شود.
/// ۲. اگر نه، الگوریتم اولویت‌بندی محلی همان کار را انجام می‌دهد (مضامین
///    عقب‌مانده و مدت‌ها مطالعه‌نشده سهم بیشتری می‌گیرند).
///
/// برنامه هفته‌ای یک‌بار ساخته و ذخیره می‌شود؛ «تولید دوباره» دستی هم ممکن
/// است. این برنامه فقط دربارهٔ «کدام مضمون، کدام روز» تصمیم می‌گیرد — نگاه
/// کنید به کامنت بالای فایل برای اینکه چرا «کدام درس دقیقاً» دیگر اینجا
/// محاسبه نمی‌شود.
///
/// **رفع اشکال ریشه‌ای «منطق مضامین با نصاب درسی فرق دارد»:** قبلاً این کلاس
/// فقط `LearningProgressDataSource` را می‌خواند — یعنی «کدام مضمون امروز
/// برنامه‌ریزی شود» صرفاً بر اساس این بود که آیا کتابِ آن مضمون در کتابخانهٔ
/// محلی (`curriculum_library`) موجود است، بدون هیچ ارتباطی با آنچه صفحهٔ
/// «نصاب درسی»/شبکهٔ مضامین صنف (`GradeSubjectsGrid`) واقعاً از سرور
/// (`GET /students/{id}/grade-map`) نشان می‌دهد. نتیجه: مضامینی که در نصاب
/// درسی دیده می‌شدند ممکن بود اصلاً در «برنامهٔ امروز» نباشند یا برعکس.
/// اکنون منبع تعیین «کدام مضامین» دقیقاً همان [GradeMapRepository] است — همان
/// منبع واحد حقیقتی که نصاب درسی/نقشهٔ صنف هم می‌خوانند.
class StudyPlanDataSource {
  final GradeMapRepository gradeMapRepository;
  final LearningProgressDataSource localProgress;

  /// شناسهٔ شاگردِ واردشده — به‌صورت callback گرفته می‌شود (نه مقدار ثابت)
  /// چون این کلاس در یک Provider ساده (غیر-family) ساخته می‌شود و باید
  /// همیشه شناسهٔ *فعلیِ* نشست را بخواند، نه شناسهٔ لحظهٔ ساخته‌شدنش.
  final String Function() studentId;

  StudyPlanDataSource(this.gradeMapRepository, this.localProgress, {required this.studentId});

  // نسخهٔ کلید را عمداً یک واحد بالا بردیم (v2 → v3): برنامه‌های هفتگیِ قبلاً
  // ذخیره‌شده (نسخه‌های v2، شاملِ فیلدهای action/chapterId/lessonیِ دیگر
  // منسوخ) با این نسخهٔ جدید نادیده گرفته می‌شوند و یک برنامهٔ تازه با
  // الگوریتم درست ساخته می‌شود — به‌جای اینکه تا آخر هفتهٔ جاری هر شاگرد
  // همچنان همان دادهٔ کهنهٔ کش‌شده را ببیند.
  static const _planKey = 'study_plan_v3';
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

    // «کدام مضامین امروز باشند» — دقیقاً از همان نصاب درسی/نقشهٔ صنف
    // (Server-Authoritative). مضمونِ قفل‌شده (اگر روزی چنین وضعیتی از سرور
    // برگردد) اصلاً قابل مطالعه نیست، پس برنامه‌ریزی نمی‌شود.
    final gradeMapResult = await gradeMapRepository.getGradeMap(studentId(), grade: grade);
    final GradeMap? gradeMap = gradeMapResult.fold((_) => null, (m) => m);

    // فقط برای غنی‌سازی متنِ Fail-safe («chat») — منبع تصمیمِ «این مضمون
    // باشد یا نه» نیست (آن تصمیم فقط با gradeMap است).
    final local = await localProgress.getAll(grade);
    final localById = {for (final p in local) p.subjectId: p};

    final eligible = (gradeMap?.subjects ?? const <GradeMapSubjectEntry>[])
        .where((s) => s.status != SubjectProgressStatus.locked)
        .map((s) => _PlanSubject(
              subjectId: s.subjectId,
              subjectNameFa: s.subjectNameFa,
              percent: s.completionPercent,
              status: s.status,
              daysSinceStudy: localById[s.subjectId]?.daysSinceStudy ?? 999,
              currentSectionIndex: localById[s.subjectId]?.currentSectionIndex ?? 0,
            ))
        .toList();

    WeeklyStudyPlan plan;
    if (eligible.isEmpty) {
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
      plan = await _generateWithOllama(weekKey, eligible) ??
          _generateSmart(weekKey, eligible);
    }

    await prefs.setString(planKey, jsonEncode(plan.toJson()));
    return plan;
  }

  static String _statusFa(SubjectProgressStatus s) {
    switch (s) {
      case SubjectProgressStatus.remedialRequired:
        return 'نیاز به مرور جبرانی فوری';
      case SubjectProgressStatus.failed:
        return 'نمرهٔ ضعیف — نیاز فوری به تمرین';
      case SubjectProgressStatus.retryWindow:
        return 'در بازهٔ اعادهٔ امتحان';
      case SubjectProgressStatus.inProgress:
        return 'در حال یادگیری';
      case SubjectProgressStatus.unlocked:
        return 'هنوز شروع نشده';
      case SubjectProgressStatus.completed:
        return 'تکمیل‌شده (فقط مرور)';
      case SubjectProgressStatus.locked:
        return 'قفل';
    }
  }

  // ── تولید با هوش مصنوعی (Ollama روی کامپیوتر سرور) ────────────────────────
  Future<WeeklyStudyPlan?> _generateWithOllama(
      String weekKey, List<_PlanSubject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final useOllama = prefs.getBool('ai_engine_use_ollama') ?? false;
    if (!useOllama) return null;
    final baseUrl =
        prefs.getString('ai_engine_base_url') ?? 'http://localhost:11434';
    final model = prefs.getString('ai_engine_model') ?? 'llama3.1';

    final subjectLines = subjects
        .map((p) =>
            '- ${p.subjectId} (${p.subjectNameFa}): پیشرفت ${p.percent.toStringAsFixed(0)}٪، وضعیت نصاب: ${_statusFa(p.status)}، ${p.daysSinceStudy >= 999 ? 'هرگز مطالعه نشده' : '${p.daysSinceStudy} روز از آخرین مطالعه'}')
        .join('\n');

    final prompt = '''
تو برنامه‌ریز درسی یک مکتب دیجیتال هستی. برای یک دانش‌آموز با وضعیت زیر، تقسیم اوقات هفتگی بساز (شنبه تا پنجشنبه، جمعه رخصتی). هر روز دقیقاً ۳ جلسه. مضامینی که وضعیت نصاب‌شان «نیاز به مرور جبرانی»، «نمرهٔ ضعیف» یا «بازهٔ اعادهٔ امتحان» است باید هر هفته چند بار تکرار شوند؛ مضامین «تکمیل‌شده» فقط گاهی برای مرور بیایند؛ مضامین «هنوز شروع نشده» را هم در طول هفته حتماً معرفی کن تا هیچ مضمونی برای همیشه فراموش نشود.

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
      final byId = {for (final s in subjects) s.subjectId: s};
      final introducedIds = <String>{};

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
          final subj = byId[id]!;
          final isNew = subj.percent <= 0 &&
              subj.status == SubjectProgressStatus.unlocked &&
              introducedIds.add(id);
          final aiFocus = (sm['focusFa'] as String?)?.trim();
          slots.add(_buildSlot(
            subj,
            isNew: isNew,
            minutes: ((sm['minutes'] as num?)?.toInt() ?? 45).clamp(20, 90).toInt(),
            preferredFocusFa: (aiFocus?.isNotEmpty ?? false) ? aiFocus : null,
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

  /// یک [StudySlot] می‌سازد — فقط «کدام مضمون، چه مدت، آیا تازه است» (بخش
  /// پایدار/هفتگی). «کجا دقیقاً باز شود» (کدام درس/فصل/آزمون) دیگر اینجا
  /// تعیین نمی‌شود — آن بخش زنده، در لحظهٔ نمایش «امروز»، از
  /// `todaySubjectPointerProvider` (که مستقیماً همان Providerهای نصاب درسی
  /// را می‌خواند) محاسبه می‌شود؛ نگاه کنید به کامنت بالای فایل.
  /// [focusFa] اینجا فقط یک متن انگیزشیِ Fail-safe/پیش‌فرض است — وقتی هنوز
  /// امکان تشخیص وضعیت زندهٔ نصاب نیست (مثلاً در حال بارگذاری) نمایش داده
  /// می‌شود؛ به‌محض آماده‌شدن نقطهٔ زنده، UI همیشه آن را جایگزین می‌کند.
  StudySlot _buildSlot(_PlanSubject p, {required bool isNew, int minutes = 45, String? preferredFocusFa}) {
    final focusFa = preferredFocusFa ??
        (p.currentSectionIndex == 0
            ? 'شروع درس از ابتدای کتاب'
            : 'ادامهٔ درس از بخش ${p.currentSectionIndex + 1} کتاب');
    return StudySlot(
      subjectId: p.subjectId,
      subjectNameFa: p.subjectNameFa,
      focusFa: focusFa,
      minutes: minutes,
      isNew: isNew,
    );
  }

  /// امتیاز نیاز به مطالعه — همیشه بر اساس وضعیت واقعیِ نصاب درسی
  /// ([SubjectProgressStatus]، نه فقط یک عدد پیشرفتِ محلی): مضامینی که سرور
  /// «نیاز به مرور جبرانی»/«نمرهٔ ضعیف»/«بازهٔ اعاده» اعلام کرده همیشه
  /// بالاترین اولویت را می‌گیرند — دقیقاً همان اضطراری که در نصاب درسی/نقشهٔ
  /// صنف هم با رنگ/نشان مشخص است.
  static double _needScore(_PlanSubject s) {
    switch (s.status) {
      case SubjectProgressStatus.remedialRequired:
      case SubjectProgressStatus.failed:
      case SubjectProgressStatus.retryWindow:
        return 140;
      case SubjectProgressStatus.inProgress:
        return (100 - s.percent) + s.daysSinceStudy.clamp(0, 30) * 1.5;
      case SubjectProgressStatus.unlocked:
        // «65» عمداً double نوشته شده (65.0)، نه int: چون این عبارت جمعِ
        // مستقیمِ یک لیترالِ int با خروجیِ num.clamp() است (که برخلاف
        // عملگرهای + / - روی int/double، همیشه num برمی‌گرداند، نه double)،
        // اگر لیترال، int می‌بود کل عبارت num می‌شد و با نوع بازگشتیِ
        // double این تابع جور درنمی‌آمد.
        return 65.0 + s.daysSinceStudy.clamp(0, 30) * 0.5;
      case SubjectProgressStatus.completed:
        return 12;
      case SubjectProgressStatus.locked:
        return -1;
    }
  }

  // ── الگوریتم اولویت‌بندی محلی (بدون نیاز به هوش مصنوعی) ───────────────────
  //
  // «برنامهٔ امروز» باید مثل یک تقسیم‌اوقات واقعیِ مکتب بچرخد، نه فهرست
  // ثابتی که هفته‌به‌هفته یک‌جور تکرار می‌شود: نقطهٔ شروعِ دور توزیع با
  // شمارهٔ هفته (weekKey) عوض می‌شود — یعنی مضمونی که این هفته اول توزیع
  // می‌شود، هفتهٔ بعد جای دیگری در چرخه می‌ایستد. اولویتِ واقعی (مضامین
  // عقب‌مانده/نیازمند مرور جبرانی) همچنان بیشترین سهم را می‌گیرد، فقط
  // ترتیب روزهای هفته برای شاگرد هر هفته تازه‌تر حس می‌شود؛ و هر مضمونِ
  // «هنوز شروع‌نشده» که برای اولین‌بار در این چرخه ظاهر شود، نشان «مضمون
  // جدید» می‌گیرد — دقیقاً همان حسِ «هر روز مضمون تازه پیشنهاد می‌شود».
  WeeklyStudyPlan _generateSmart(
      String weekKey, List<_PlanSubject> subjects) {
    final ranked = List<_PlanSubject>.from(subjects)
      ..sort((a, b) => _needScore(b).compareTo(_needScore(a)));

    final weekSeed = weekKey.hashCode.abs();
    var cursor = ranked.isEmpty ? 0 : weekSeed % ranked.length;
    final introducedIds = <String>{};

    final days = <PlanDay>[];
    for (final wd in schoolDays) {
      final slots = <StudySlot>[];
      for (var i = 0; i < 3 && ranked.isNotEmpty; i++) {
        final p = ranked[cursor % ranked.length];
        cursor++;
        final isNew = p.percent <= 0 &&
            p.status == SubjectProgressStatus.unlocked &&
            introducedIds.add(p.subjectId);
        slots.add(_buildSlot(p, isNew: isNew));
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
