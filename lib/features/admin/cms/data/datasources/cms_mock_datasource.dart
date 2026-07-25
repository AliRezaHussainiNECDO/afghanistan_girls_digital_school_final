import 'dart:math';

import '../../domain/entities/cms_entities.dart';
import 'cms_remote_datasource.dart' show CmsDataSource;

/// منبع دادهٔ آزمایشی CMS (فاز ۱: پروتوتایپ با دادهٔ درون‌حافظه‌ای).
/// تمام عملیات CRUD و انتقال وضعیت اینجا شبیه‌سازی می‌شود تا رفتار UI
/// دقیقاً مانند نسخهٔ واقعی متصل به Backend باشد.
class CmsMockDataSource implements CmsDataSource {
  // یک نمونهٔ singleton تا تغییرات بین بازدیدهای مختلف صفحه حفظ شود.
  static final CmsMockDataSource _instance = CmsMockDataSource._internal();
  factory CmsMockDataSource() => _instance;
  CmsMockDataSource._internal();

  final List<CmsLessonRow> _lessons = [
    CmsLessonRow(
      id: 'l1',
      title: 'معادلات درجهٔ دوم',
      gradeNumber: 9,
      subjectId: 'math',
      chapterTitle: 'فصل ۳: معادلات',
      durationMinutes: 35,
      content: 'تعریف معادلهٔ درجهٔ دوم، روش‌های حل (فاکتورگیری، فرمول عمومی) و مثال‌های کاربردی.',
      status: ContentStatus.published,
      updatedAt: DateTime(2026, 6, 22),
    ),
    CmsLessonRow(
      id: 'l2',
      title: 'حرکت نیوتنی',
      gradeNumber: 9,
      subjectId: 'physics',
      chapterTitle: 'فصل ۲: حرکت',
      durationMinutes: 40,
      content: 'قوانین سه‌گانهٔ نیوتن و کاربرد آن‌ها در حل مسائل حرکت.',
      status: ContentStatus.draft,
      updatedAt: DateTime(2026, 7, 2),
    ),
  ];

  String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

  // ─────────────────────────── LESSONS ───────────────────────────
  @override
  Future<List<CmsLessonRow>> getLessons() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = [..._lessons]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<CmsLessonRow> saveLesson(CmsLessonRow row) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _lessons.indexWhere((l) => l.id == row.id);
    final saved = row.copyWith(updatedAt: DateTime.now());
    if (idx == -1) {
      final created = CmsLessonRow(
        id: _newId('l'),
        title: saved.title,
        gradeNumber: saved.gradeNumber,
        subjectId: saved.subjectId,
        chapterTitle: saved.chapterTitle,
        durationMinutes: saved.durationMinutes,
        content: saved.content,
        status: saved.status,
        updatedAt: saved.updatedAt,
      );
      _lessons.add(created);
      return created;
    }
    _lessons[idx] = saved;
    return saved;
  }

  @override
  Future<void> deleteLesson(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _lessons.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> setLessonStatus(String id, ContentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _lessons.indexWhere((l) => l.id == id);
    if (idx != -1) _lessons[idx] = _lessons[idx].copyWith(status: status, updatedAt: DateTime.now());
  }

  // ─────────────────────────── INVITE CODES ───────────────────────────
  // رفع اشکال (۲۴ جولای): قبلاً این بخش دو Store سراسری جدا
  // (`StudentInviteStore`/`InstructorInviteStore` در `core/`) را به‌عنوان
  // «منبع واحد حقیقت» صدا می‌زد که هم توسط این DataSource و هم توسط
  // `AuthMockDataSource` مستقیماً استفاده می‌شد — یعنی دو نسخهٔ Mock جدا
  // (CMS و ثبت‌نام) به یک Singleton سراسری خارج از مرز DataSource وابسته
  // بودند. چون منبع حقیقتِ **واقعی** کدهای دعوت همیشه جدول `invite_codes`
  // در D1 بوده (نه این Storeها)، آن دو فایل حذف شدند؛ داده‌های نمایشیِ این
  // تب اکنون کاملاً محلی و محدود به همین DataSource (Mock) هستند — دقیقاً
  // مثل `_books`/`_lessons`/`_questions` بالا. حالت Mock دیگر تلاش نمی‌کند
  // اعتبارسنجی واقعی کد دعوت را شبیه‌سازی کند (این کار را `POST
  // /api/auth/register` واقعی انجام می‌دهد)؛ اینجا فقط برای پیش‌نمایش UI
  // پنل مدیر است.
  final List<CmsInviteCodeRow> _studentCodes = [
    CmsInviteCodeRow(
      id: 'ic-demo-1',
      code: 'DEMO1234',
      batchLabel: 'دفعهٔ آزمایشی',
      status: 'unused',
      createdAt: DateTime(2026, 6, 1),
      usedByName: '',
      expiresAt: DateTime(2026, 6, 1).add(const Duration(days: 365)),
    ),
  ];
  final List<CmsInviteCodeRow> _instructorCodes = [
    CmsInviteCodeRow(
      id: 'ic-inst-demo-1',
      code: 'TCH-DEMO01',
      batchLabel: 'کد نمایشی (تست)',
      status: 'unused',
      createdAt: DateTime.now(),
      usedByName: '',
      expiresAt: DateTime.now().add(const Duration(days: 14)),
    ),
  ];

  List<CmsInviteCodeRow> _listFor(String type) => type == 'instructor' ? _instructorCodes : _studentCodes;

  @override
  Future<List<CmsInviteCodeRow>> getInviteCodes({String type = 'student'}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = [..._listFor(type)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// طبق بخش ۳ب.۳ سند: صدور دسته‌ای Invite Code با `batch_label` — نسخهٔ
  /// نمایشیِ محلی؛ کد تولیدشده اینجا هرگز به سرور نمی‌رسد (برخلاف پنل
  /// واقعی که از `POST /admin/invite-codes` می‌گذرد).
  @override
  Future<void> generateInviteCodes(int count, String batchLabel, {String type = 'student'}) async {
    await Future.delayed(const Duration(milliseconds: 350));
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final list = _listFor(type);
    final prefix = type == 'instructor' ? 'TCH-' : '';
    final validDays = type == 'instructor' ? 14 : 30;
    for (var i = 0; i < count; i++) {
      final code = '$prefix${List.generate(type == 'instructor' ? 6 : 8, (_) => chars[rand.nextInt(chars.length)]).join()}';
      final now = DateTime.now();
      list.add(CmsInviteCodeRow(
        id: _newId('ic'),
        code: code,
        batchLabel: batchLabel,
        status: 'unused',
        createdAt: now,
        usedByName: '',
        expiresAt: now.add(Duration(days: validDays)),
      ));
    }
  }

  @override
  Future<void> revokeInviteCode(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final list in [_studentCodes, _instructorCodes]) {
      final idx = list.indexWhere((c) => c.id == id);
      if (idx != -1 && list[idx].status == 'unused') {
        list[idx] = list[idx].copyWith(status: 'revoked');
        return;
      }
    }
  }
}
