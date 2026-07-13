import 'package:flutter/foundation.dart';
import '../../../shared_models/subject.dart';

/// حداقل نمرهٔ لازم برای «کامیابی» امتحان جهت ارتقا به صنف بعدی.
const double kPromoteExamMark = 80.0;

/// وضعیت ارتقای یک شاگرد.
class StudentProgress {
  final String studentId;
  final int enrolledGrade; // صنف انتخاب‌شده در راجستر (کف صنف)
  int currentGrade; // صنف فعال فعلی
  final Map<String, double> completion; // subjectId -> ۰..۱۰۰ برای صنف فعلی
  double examScore; // نمرهٔ امتحان صنف فعلی (۰..۱۰۰)
  bool examTaken;

  StudentProgress({
    required this.studentId,
    required this.enrolledGrade,
    required this.currentGrade,
    Map<String, double>? completion,
    this.examScore = 0,
    this.examTaken = false,
  }) : completion = completion ?? {};

  double get overallCompletion {
    if (mockSubjects.isEmpty) return 0;
    var sum = 0.0;
    for (final s in mockSubjects) {
      sum += (completion[s.id] ?? 0).clamp(0, 100);
    }
    return sum / mockSubjects.length;
  }

  bool get allSubjectsComplete => mockSubjects.every((s) => (completion[s.id] ?? 0) >= 100);

  bool get examPassed => examTaken && examScore >= kPromoteExamMark;

  bool get canPromote => currentGrade < 12 && allSubjectsComplete && examPassed;
}

/// انبار ارتقای صنف — منطق قفل/بازشدن صنوف و ارتقا/کاهش.
///
/// قانون (طبق درخواست کاربر): صنف انتخاب‌شده در راجستر فعال است و صنوف بالاتر
/// قفل‌اند؛ وقتی شاگرد **تمام مضامین را ۱۰۰٪** تکمیل کند و **امتحان را با نمرهٔ
/// خوب (≥۸۰) کامیاب** شود، صنف بعدی باز می‌شود.
class ProgressionStore extends ChangeNotifier {
  ProgressionStore._() {
    _seed();
  }
  static final ProgressionStore instance = ProgressionStore._();

  final Map<String, StudentProgress> _byStudent = {};

  void _seed() {
    // شاگرد نمایشی واردشده (صنف ۷): همهٔ مضامین کامل جز ریاضی — تا با کامیابی
    // در امتحان ریاضی، ارتقا به صنف ۸ به‌روشنی نمایش داده شود.
    final demo = StudentProgress(
      studentId: 'u-student-demo',
      enrolledGrade: 7,
      currentGrade: 7,
    );
    for (final s in mockSubjects) {
      demo.completion[s.id] = 100;
    }
    demo.completion['math'] = 65; // یک مضمون ناتمام
    _byStudent[demo.studentId] = demo;

    // چند شاگرد فهرست مدیر با وضعیت‌های متنوع (برای نمای مدیر/والد).
    _seedAdmin('stu-1000', enrolled: 7, current: 8, mathDone: true, exam: 88, taken: true);
    _seedAdmin('stu-1004', enrolled: 7, current: 7, mathDone: false, exam: 0, taken: false);
    _seedAdmin('stu-1001', enrolled: 8, current: 9, mathDone: true, exam: 91, taken: true);
  }

  void _seedAdmin(String id,
      {required int enrolled, required int current, required bool mathDone, required double exam, required bool taken}) {
    final p = StudentProgress(studentId: id, enrolledGrade: enrolled, currentGrade: current, examScore: exam, examTaken: taken);
    for (final s in mockSubjects) {
      p.completion[s.id] = 100;
    }
    if (!mathDone) p.completion['math'] = 55;
    _byStudent[id] = p;
  }

  /// دریافت (یا ساخت پیش‌فرض) وضعیت یک شاگرد.
  StudentProgress progressFor(String studentId, {int fallbackGrade = 7}) {
    return _byStudent.putIfAbsent(
      studentId,
      () => StudentProgress(studentId: studentId, enrolledGrade: fallbackGrade, currentGrade: fallbackGrade),
    );
  }

  bool hasProgress(String studentId) => _byStudent.containsKey(studentId);

  /// وضعیت یک صنف برای این شاگرد: completed / active / locked.
  String gradeState(String studentId, int grade) {
    final p = progressFor(studentId);
    if (grade < p.currentGrade) return 'completed';
    if (grade == p.currentGrade) return 'active';
    return 'locked';
  }

  bool isUnlocked(String studentId, int grade) => grade <= progressFor(studentId).currentGrade;

  void setCompletion(String studentId, String subjectId, double percent) {
    final p = progressFor(studentId);
    p.completion[subjectId] = percent.clamp(0, 100);
    notifyListeners();
  }

  /// ثبت نتیجهٔ امتحان یک مضمون — مضمون کامل می‌شود و نمرهٔ امتحان به‌روز
  /// می‌گردد؛ در صورت واجد شرایط بودن، ارتقای خودکار انجام می‌شود.
  /// خروجی: true اگر شاگرد ارتقا یافت.
  bool recordExam({
    required String studentId,
    required String subjectId,
    required double scorePercent,
    int fallbackGrade = 7,
  }) {
    final p = progressFor(studentId, fallbackGrade: fallbackGrade);
    if (scorePercent >= kPromoteExamMark && subjectId.isNotEmpty) {
      p.completion[subjectId] = 100; // مضمون با کامیابی در امتحان کامل می‌شود
    }
    // نمرهٔ امتحان صنف = بالاترین نمرهٔ ثبت‌شده.
    if (scorePercent > p.examScore) p.examScore = scorePercent;
    p.examTaken = true;
    final promoted = _autoPromote(p);
    notifyListeners();
    return promoted;
  }

  bool _autoPromote(StudentProgress p) {
    if (p.canPromote) {
      _advance(p);
      return true;
    }
    return false;
  }

  void _advance(StudentProgress p) {
    p.currentGrade = (p.currentGrade + 1).clamp(7, 12);
    // صنف جدید: مضامین از نو (۰٪) و امتحان بازنشانی.
    for (final s in mockSubjects) {
      p.completion[s.id] = 0;
    }
    p.examScore = 0;
    p.examTaken = false;
  }

  // ── اقدامات مدیر ──
  /// ارتقای دستی توسط مدیر (بدون شرط تکمیل — تصمیم مدیریتی).
  void promote(String studentId) {
    final p = progressFor(studentId);
    if (p.currentGrade >= 12) return;
    _advance(p);
    notifyListeners();
  }

  /// کاهش صنف توسط مدیر (تا کف صنف راجستر).
  void demote(String studentId) {
    final p = progressFor(studentId);
    if (p.currentGrade <= p.enrolledGrade || p.currentGrade <= 7) return;
    p.currentGrade -= 1;
    for (final s in mockSubjects) {
      p.completion[s.id] = 100; // صنف پایین‌تر قبلاً کامل شده بود
    }
    p.examScore = kPromoteExamMark;
    p.examTaken = true;
    notifyListeners();
  }
}
