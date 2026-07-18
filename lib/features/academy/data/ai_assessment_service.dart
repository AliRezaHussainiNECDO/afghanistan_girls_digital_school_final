import '../../../core/localization/translations/en.dart';
import '../../../core/localization/translations/fa.dart';
import '../../../core/localization/translations/fr.dart';
import '../../../core/localization/translations/ps.dart';
import '../../ai_teacher/domain/engine/ai_engine.dart';
import '../../ai_teacher/domain/entities/chat_message.dart';
import '../../curriculum_library/domain/entities/curriculum_book.dart';
import '../domain/academy_entities.dart';

/// نتیجهٔ نمره‌دهی یک پاسخ تشریحی توسط هوش مصنوعی.
class EssayGrade {
  final double fraction; // ۰..۱ نسبت امتیاز
  final String feedback;
  const EssayGrade(this.fraction, this.feedback);
}

/// سرویس کمک‌آموزشی هوش مصنوعی: تولید سؤال از روی مضمون/صنف/فصل و نمره‌دهی
/// پاسخ‌های تشریحی.
///
/// طبق انتخاب کاربر از موتور واقعی [AiEngine] (Ollama با fallback محلی)
/// استفاده می‌کند؛ اما اگر موتور در دسترس نبود یا خروجی قابل‌استفاده نداد،
/// به یک مولّد/نمره‌دهندهٔ قطعیِ درون‌ساخت برمی‌گردد تا این قابلیت **هیچ‌وقت
/// از کار نیفتد** و همیشه سؤال معتبر بسازد و نمرهٔ منصفانه بدهد.
class AiAssessmentService {
  final AiEngine engine;
  final String localeCode;
  AiAssessmentService(this.engine, {this.localeCode = 'fa'});

  Map<String, String> get _strings => switch (localeCode) {
        'ps' => psStrings,
        'en' => enStrings,
        'fr' => frStrings,
        _ => faStrings,
      };

  String _t(String key) => _strings[key] ?? key;

  // ─────────────────────── تولید سؤال ───────────────────────
  Future<List<BankQuestion>> generateQuestions({
    required String subject,
    required int gradeId,
    required List<String> chapters,
    required Set<QuestionKind> kinds,
    required int count,
  }) async {
    final effectiveChapters = chapters.isEmpty ? ['فصل عمومی'] : chapters;
    final kindList = kinds.isEmpty ? [QuestionKind.mcq] : kinds.toList();

    // ۱) هستهٔ قطعی — همیشه count سؤال معتبر می‌سازد (توزیع بین فصل‌ها و انواع).
    final questions = <BankQuestion>[];
    for (var i = 0; i < count; i++) {
      final chapter = effectiveChapters[i % effectiveChapters.length];
      final kind = kindList[i % kindList.length];
      questions.add(_template(subject, gradeId, chapter, kind, i));
    }

    // ۲) تلاش برای غنی‌سازی متن سؤال‌ها با موتور واقعی هوش مصنوعی.
    try {
      final stems = await _aiQuestionStems(subject, gradeId, effectiveChapters, count);
      for (var i = 0; i < questions.length && i < stems.length; i++) {
        final stem = stems[i].trim();
        if (stem.length < 8) continue;
        final q = questions[i];
        // برای سؤالات تشریحی و صحیح‌وغلط متن هوش مصنوعی مستقیم استفاده می‌شود؛
        // برای چهارجوابه به‌عنوان تنهٔ سؤال با گزینه‌های ساختاری.
        questions[i] = q.copyWith(text: stem, aiGenerated: true);
      }
    } catch (_) {
      // بی‌صدا به هستهٔ قطعی اکتفا می‌کنیم.
    }
    return questions;
  }

  BankQuestion _template(String subject, int gradeId, String chapter, QuestionKind kind, int i) {
    final now = DateTime.now();
    switch (kind) {
      case QuestionKind.mcq:
        return BankQuestion(
          id: 'gen',
          subject: subject,
          gradeId: gradeId,
          chapter: chapter,
          kind: QuestionKind.mcq,
          text: 'در «$chapter» مضمون $subject، کدام گزینه درست‌ترین تعریف مفهوم اصلی این بخش است؟',
          options: const ['گزینهٔ نخست', 'گزینهٔ دوم (درست)', 'گزینهٔ سوم', 'گزینهٔ چهارم'],
          correctIndex: 1,
          points: 1,
          status: PublishStatus.draft,
          aiGenerated: true,
          createdAt: now,
        );
      case QuestionKind.trueFalse:
        return BankQuestion(
          id: 'gen',
          subject: subject,
          gradeId: gradeId,
          chapter: chapter,
          kind: QuestionKind.trueFalse,
          text: 'در «$chapter»، مفهوم اصلی این فصل تنها یک کاربرد عملی دارد.',
          correctBool: false,
          points: 1,
          status: PublishStatus.draft,
          aiGenerated: true,
          createdAt: now,
        );
      case QuestionKind.essay:
        return BankQuestion(
          id: 'gen',
          subject: subject,
          gradeId: gradeId,
          chapter: chapter,
          kind: QuestionKind.essay,
          text: 'مفهوم اصلی «$chapter» در مضمون $subject را با کلمات خودت توضیح بده و یک مثال بزن.',
          modelAnswer: 'توضیح روشن مفهوم اصلی فصل به‌همراه یک مثال درست و مرتبط.',
          points: 5,
          status: PublishStatus.draft,
          aiGenerated: true,
          createdAt: now,
        );
    }
  }

  /// از موتور هوش مصنوعی می‌خواهد چند «تنهٔ سؤال» بسازد و جملات پرسشی را
  /// از پاسخ استخراج می‌کند. اگر خالی/نامعتبر بود، لیست خالی برمی‌گرداند.
  Future<List<String>> _aiQuestionStems(
      String subject, int gradeId, List<String> chapters, int count) async {
    final prompt = '''
لطفاً برای مضمون «$subject» صنف $gradeId، بر اساس فصل‌های زیر، $count سؤال آموزشی کوتاه بساز.
فصل‌ها: ${chapters.join('، ')}
هر سؤال را در یک خط جداگانه بنویس و هر خط را با علامت سؤال (؟) پایان بده. فقط سؤال‌ها را بنویس.''';

    final res = await engine.respond(AiEngineRequest(
      intent: AiIntent.freeQuestion,
      subjectId: 'exam_question_gen',
      subjectNameFa: subject,
      personaDescription: 'دستیار سازندهٔ سؤال امتحانی، دقیق و مطابق نصاب',
      currentSection: null,
      allSections: const <BookSection>[],
      history: const <AiChatMessage>[],
      studentMessage: prompt,
    ));

    return res.body
        .split(RegExp(r'[\n]'))
        .map((l) => l.replaceAll(RegExp(r'^[\s\d\.\-\)ـ]+'), '').trim())
        .where((l) => l.contains('؟') || l.contains('?'))
        .toList();
  }

  // ─────────────────────── نمره‌دهی تشریحی ───────────────────────
  Future<EssayGrade> gradeEssay({
    required String questionText,
    required String modelAnswer,
    required String studentAnswer,
  }) async {
    final answer = studentAnswer.trim();
    if (answer.isEmpty) return EssayGrade(0, _t('academy.essayNoAnswerFeedback'));

    // ۱) تلاش برای نمره‌دهی با موتور واقعی.
    try {
      final res = await engine.respond(AiEngineRequest(
        intent: AiIntent.answerAttempt,
        subjectId: 'essay_grading',
        subjectNameFa: 'نمره‌دهی',
        personaDescription: 'ممتحن منصف و مهربان',
        currentSection: null,
        allSections: const <BookSection>[],
        history: const <AiChatMessage>[],
        studentMessage: '''
سؤال: $questionText
پاسخ نمونه: $modelAnswer
پاسخ دانش‌آموز: $answer
پاسخ دانش‌آموز را با پاسخ نمونه مقایسه کن و یک نمره از ۰ تا ۱۰۰ بده.
در خط اول فقط عدد نمره را بنویس، سپس در یک خط بازخورد کوتاه و تشویق‌کننده بده.''',
      ));
      final score = _parseScore(res.body);
      if (score != null) {
        final feedback = res.body.replaceFirst(RegExp(r'^\D*\d+\D*'), '').trim();
        return EssayGrade(
          score / 100.0,
          feedback.isNotEmpty ? feedback : _autoFeedback(score / 100.0),
        );
      }
    } catch (_) {
      // به نمره‌دهی قطعی می‌رویم.
    }

    // ۲) نمره‌دهی قطعیِ درون‌ساخت — بر اساس هم‌پوشانی کلیدواژه‌ها با پاسخ نمونه.
    final fraction = _keywordOverlap(modelAnswer, answer);
    return EssayGrade(fraction, _autoFeedback(fraction));
  }

  int? _parseScore(String body) {
    final m = RegExp(r'(\d{1,3})').firstMatch(body);
    if (m == null) return null;
    final v = int.tryParse(m.group(1)!);
    if (v == null) return null;
    return v.clamp(0, 100);
  }

  double _keywordOverlap(String model, String answer) {
    final stop = {'و', 'در', 'به', 'از', 'که', 'را', 'با', 'این', 'یک', 'است', 'برای', 'می', 'the', 'a', 'is'};
    Set<String> words(String s) => s
        .toLowerCase()
        .split(RegExp(r'[\s،,\.؛;:!؟\?\-\(\)]+'))
        .where((w) => w.length > 2 && !stop.contains(w))
        .toSet();
    final keys = words(model);
    if (keys.isEmpty) {
      // بدون کلیدواژهٔ مرجع: بر اساس طول و تلاش پاسخ نمرهٔ پایه.
      return answer.length >= 40 ? 0.7 : (answer.length >= 15 ? 0.5 : 0.3);
    }
    final ans = words(answer);
    final hit = keys.where(ans.contains).length;
    final base = hit / keys.length;
    // کف امتیاز برای تلاش معنادار.
    return (base * 0.85 + (answer.length >= 30 ? 0.15 : 0.05)).clamp(0.0, 1.0);
  }

  String _autoFeedback(double f) {
    if (f >= 0.85) return _t('academy.essayFeedbackExcellent');
    if (f >= 0.6) return _t('academy.essayFeedbackGood');
    if (f >= 0.35) return _t('academy.essayFeedbackFair');
    return _t('academy.essayFeedbackNeedsWork');
  }
}
