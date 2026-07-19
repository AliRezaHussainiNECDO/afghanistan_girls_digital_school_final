import '../../domain/entities/homework.dart';
import 'homework_datasource.dart';

/// دادهٔ Mock فاز ۱ — فقط برای پیش‌نمایش وقتی `kUseLiveBackend = false` (بدون
/// بک‌اند واقعی). رفتار نمره‌دهی هوشمند را با یک تأخیر کوتاه شبیه‌سازی می‌کند.
class HomeworkMockDataSource implements HomeworkDataSource {
  final List<Homework> _homeworks = [
    Homework(
      id: 'hw_mock_1',
      studentId: 'me',
      subjectId: 'math',
      subjectNameFa: 'ریاضی',
      classLevel: 7,
      questionText: 'سه کسر ۱/۲ + ۱/۳ + ۱/۶ را جمع کنید و مراحل حل را روی کاغذ بنویسید.',
      hintText: 'ابتدا مخرج مشترک هر سه کسر را پیدا کنید.',
      status: HomeworkStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Homework(
      id: 'hw_mock_2',
      studentId: 'me',
      subjectId: 'physics',
      subjectNameFa: 'فزیک',
      classLevel: 7,
      questionText: 'اگر یک موتر در ۴ ثانیه از ۰ به ۲۰ متر بر ثانیه برسد، شتاب آن را حساب کنید.',
      hintText: 'شتاب = تغییر سرعت ÷ زمان.',
      status: HomeworkStatus.graded,
      studentImageUrl: '',
      extractedText: 'شتاب = ۲۰ ÷ ۴ = ۵ متر بر ثانیه مربع',
      aiScore: 92,
      aiFeedback: 'آفرین! فرمول را درست به‌کار بردید و مراحل حل خوانا بود. فقط واحد نهایی (متر بر ثانیهٔ مربع) را در جواب پایانی هم بنویسید.',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      submittedAt: DateTime.now().subtract(const Duration(days: 2)),
      gradedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  final Map<String, List<HomeworkReply>> _replies = {};

  @override
  Future<HomeworkListResult> getHomeworks({HomeworkStatus? status, String? studentId}) async {
    // پیش‌نمایش بدون بک‌اند واقعی: صرف‌نظر از [studentId] (که فقط برای نمای
    // مدیر معنا دارد)، همان فهرست نمایشی ثابت را برمی‌گرداند تا پیش‌نمایش
    // «کار خانگی» در پروندهٔ هر شاگردی هم خالی نباشد.
    await Future.delayed(const Duration(milliseconds: 300));
    final filtered = status == null ? _homeworks : _homeworks.where((h) => h.status == status).toList();
    final graded = _homeworks.where((h) => h.aiScore != null).map((h) => h.aiScore!).toList();
    final avg = graded.isEmpty ? null : graded.reduce((a, b) => a + b) / graded.length;
    return HomeworkListResult(classLevel: 7, averageScore: avg, homeworks: List.of(filtered));
  }

  @override
  Future<Homework> getHomeworkById(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _homeworks.firstWhere((h) => h.id == id, orElse: () => _homeworks.first);
  }

  @override
  Future<List<HomeworkReply>> getReplies(String homeworkId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.of(_replies[homeworkId] ?? const []);
  }

  @override
  Future<Homework> submitPhoto({
    required String homeworkId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    await Future.delayed(const Duration(seconds: 1)); // شبیه‌سازی زمان Vision
    final idx = _homeworks.indexWhere((h) => h.id == homeworkId);
    if (idx == -1) return getHomeworkById(homeworkId);
    final graded = Homework(
      id: _homeworks[idx].id,
      studentId: _homeworks[idx].studentId,
      subjectId: _homeworks[idx].subjectId,
      subjectNameFa: _homeworks[idx].subjectNameFa,
      chapterId: _homeworks[idx].chapterId,
      lessonId: _homeworks[idx].lessonId,
      classLevel: _homeworks[idx].classLevel,
      questionText: _homeworks[idx].questionText,
      hintText: _homeworks[idx].hintText,
      status: HomeworkStatus.graded,
      studentImageUrl: 'mock://local-preview',
      extractedText: '(پیش‌نمایش محلی — بدون بک‌اند واقعی متن دست‌خط خوانده نمی‌شود)',
      aiScore: 78,
      aiFeedback: 'کار خوبی انجام دادید! این فقط یک نمرهٔ نمایشی است چون اپ در حالت پیش‌نمایش (بدون سرور واقعی) اجرا می‌شود.',
      createdAt: _homeworks[idx].createdAt,
      submittedAt: DateTime.now(),
      gradedAt: DateTime.now(),
    );
    _homeworks[idx] = graded;
    return graded;
  }

  @override
  Future<List<HomeworkReply>> sendReply({required String homeworkId, required String text}) async {
    final list = _replies.putIfAbsent(homeworkId, () => []);
    list.add(HomeworkReply(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      homeworkId: homeworkId,
      sender: HomeworkReplySender.student,
      text: text,
      createdAt: DateTime.now(),
    ));
    await Future.delayed(const Duration(milliseconds: 500));
    list.add(HomeworkReply(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}_ai',
      homeworkId: homeworkId,
      sender: HomeworkReplySender.ai,
      text: 'این یک پاسخ نمایشی است (اپ در حالت پیش‌نمایش بدون سرور واقعی اجرا می‌شود). در نسخهٔ واقعی، معلم هوشمند بر اساس نمره و بازخورد شما پاسخ می‌دهد.',
      createdAt: DateTime.now(),
    ));
    return List.of(list);
  }
}
