import '../../domain/entities/homework.dart';

/// مدل داده‌ای «مشق» — تبدیل JSON خام سرور (`routes/homework.ts`) به موجودیت
/// دامنه [Homework]، با مرزهای دفاعی کامل: هیچ فیلد گم‌شده/نوع نادرست سرور
/// نباید کل صفحهٔ «مشق‌های من» را Crash کند — دقیقاً همان اصل Fail-safe که در
/// بقیهٔ لایه‌های دادهٔ اپ (مثلاً AiVoiceRemoteDataSource) رعایت شده.
class HomeworkModel extends Homework {
  const HomeworkModel({
    required super.id,
    required super.studentId,
    required super.subjectId,
    super.subjectNameFa,
    super.chapterId,
    super.lessonId,
    required super.classLevel,
    super.questionText,
    super.hintText,
    super.status,
    super.studentImageUrl,
    super.extractedText,
    super.aiScore,
    super.aiFeedback,
    required super.createdAt,
    super.submittedAt,
    super.gradedAt,
  });

  /// پارس دفاعی: هر فیلد جداگانه با fallback امن — یک مقدار غیرمنتظره
  /// (مثلاً `null` یا نوع اشتباه) کل رکورد را خراب نمی‌کند.
  factory HomeworkModel.fromJson(Map<String, dynamic> json) {
    int? scoreOrNull;
    final rawScore = json['aiScore'];
    if (rawScore is num) scoreOrNull = rawScore.round().clamp(0, 100);

    return HomeworkModel(
      id: (json['id'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? '').toString(),
      subjectNameFa: (json['subjectNameFa'] ?? '').toString(),
      chapterId: (json['chapterId'] ?? '').toString(),
      lessonId: (json['lessonId'] ?? '').toString(),
      classLevel: _asInt(json['classLevel'], fallback: 7),
      questionText: (json['questionText'] ?? '').toString(),
      hintText: (json['hintText'] ?? '').toString(),
      status: homeworkStatusFromApi(json['status']?.toString()),
      studentImageUrl: (json['studentImageUrl'] ?? '').toString(),
      extractedText: (json['extractedText'] ?? '').toString(),
      aiScore: scoreOrNull,
      aiFeedback: (json['aiFeedback'] ?? '').toString(),
      createdAt: _asDate(json['createdAt']) ?? DateTime.now(),
      submittedAt: _asDate(json['submittedAt']),
      gradedAt: _asDate(json['gradedAt']),
    );
  }

  static int _asInt(dynamic v, {required int fallback}) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

/// مدل داده‌ای یک پیام گفت‌وگوی «شاگرد ↔ معلم هوشمند» دربارهٔ نمرهٔ یک مشق.
class HomeworkReplyModel extends HomeworkReply {
  const HomeworkReplyModel({
    required super.id,
    required super.homeworkId,
    required super.sender,
    required super.text,
    required super.createdAt,
  });

  factory HomeworkReplyModel.fromJson(Map<String, dynamic> json) {
    return HomeworkReplyModel(
      id: (json['id'] ?? '').toString(),
      homeworkId: (json['homeworkId'] ?? '').toString(),
      sender: (json['sender']?.toString() == 'ai') ? HomeworkReplySender.ai : HomeworkReplySender.student,
      text: (json['text'] ?? '').toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
