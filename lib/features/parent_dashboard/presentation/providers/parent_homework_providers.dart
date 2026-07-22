import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../academy/homework/domain/entities/homework.dart';
import '../../../academy/homework/domain/usecases/homework_usecases.dart';
import '../../../academy/homework/presentation/providers/homework_providers.dart';

/// ─────────────── نمای والد: کنترول کارخانگی فرزندان ───────────────
///
/// طبق درخواست صاحب پروژه: والد باید بتواند کارخانگی‌هایی که به فرزندانش
/// داده شده را ببیند و کنترول کند که «ارسال کرده‌اند یا خیر». این نما
/// **فقط‌خواندنی** است (اصل بخش ۱۳ب.۳ سند — والد هرگز به‌جای فرزند مشق
/// ارسال یا گفتگو نمی‌کند)؛ از همان منبع واحد حقیقت بخش «کار خانگی» شاگرد
/// (`GET /homework?studentId=` — همان الگوی نمای مدیر) می‌خواند تا هر چه
/// شاگرد می‌بیند، والد هم دقیقاً همان را ببیند.
///
/// Provider ها عمداً از `homeworkStatusFilterProvider`/`homeworksProvider`
/// خودِ شاگرد و از نمای مدیر (`adminHomeworkStatusFilterProvider`) جدا
/// هستند تا فیلترِ والد هرگز با فیلتر شاگرد/مدیر تداخل نکند.

/// فیلتر فعال تب‌های کارخانگی در نمای والد — کلید = studentId، تا هر فرزند
/// فیلتر جدای خودش را داشته باشد. `null` یعنی «همه».
final parentHomeworkStatusFilterProvider =
    StateProvider.family<HomeworkStatus?, String>((ref, studentId) => null);

/// فهرست کارخانگی‌های یک فرزند مشخص برای والد — با تغییر فیلتر یا ارسال
/// مشق جدید توسط فرزند (invalidate از بیرون) بازسازی می‌شود.
final parentChildHomeworksProvider =
    FutureProvider.autoDispose.family<HomeworkListResult, String>((ref, studentId) async {
  final status = ref.watch(parentHomeworkStatusFilterProvider(studentId));
  final result = await ref
      .read(getHomeworksUseCaseProvider)
      .call(GetHomeworksParams(status: status, studentId: studentId));
  return result.fold((f) => throw f, (v) => v);
});

/// آمار تجمیعی کارخانگی یک فرزند (بدون فیلتر) — برای کارت خلاصهٔ داشبورد
/// والد: چند مشق داده شده، چند ارسال/نمره‌گرفته، چند هنوز ارسال‌نشده.
final parentChildHomeworkStatsProvider =
    FutureProvider.autoDispose.family<ParentHomeworkStats, String>((ref, studentId) async {
  final result =
      await ref.read(getHomeworksUseCaseProvider).call(GetHomeworksParams(studentId: studentId));
  return result.fold((f) => throw f, (v) {
    final total = v.homeworks.length;
    final pending = v.homeworks.where((h) => h.status == HomeworkStatus.pending).length;
    final graded = v.homeworks.where((h) => h.status == HomeworkStatus.graded).length;
    return ParentHomeworkStats(
      total: total,
      notSubmitted: pending,
      submitted: total - pending,
      graded: graded,
      averageScore: v.averageScore,
    );
  });
});

/// آمار سادهٔ کارخانگی یک فرزند برای نمایش سریع.
class ParentHomeworkStats {
  final int total;
  final int notSubmitted; // هنوز ارسال نکرده
  final int submitted; // ارسال‌شده (شامل نمره‌گرفته)
  final int graded;
  final double? averageScore;
  const ParentHomeworkStats({
    required this.total,
    required this.notSubmitted,
    required this.submitted,
    required this.graded,
    this.averageScore,
  });
}
