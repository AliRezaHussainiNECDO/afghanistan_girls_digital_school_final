import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../domain/advisor_entities.dart';
import 'advisor_remote_datasource.dart';

/// انبار گفتگوهای «مشاور هوشمند» — تاریخچهٔ هر شاگرد به‌صورت جداگانه نگه
/// داشته می‌شود تا هم شاگرد گفتگوی خود را ادامه دهد و هم مدیر بتواند در
/// جزئیات شاگرد آن را بازبینی/تعقیب کند.
///
/// یک [ChangeNotifier] singleton است؛ هر صفحه‌ای که گوش می‌دهد بلافاصله
/// به‌روزرسانی می‌شود.
///
/// رفع اشکال حیاتی امنیتی: قبلاً این گفتگو *فقط* در همین حافظهٔ محلی می‌ماند
/// و هرگز به سرور نمی‌رسید — یعنی پیام‌های پرچم‌شده (نشانهٔ خودآزاری/آزار/
/// ازدواج اجباری) هرگز به مدیر واقعی مکتب نمی‌رسید، با اینکه به شاگرد گفته
/// می‌شد «مدیریت بازبینی می‌کند». اکنون در حالت Live، هر پیام پس از افزودن
/// محلی (برای فوریتِ UX) هم‌زمان روی سرور نیز ثبت می‌شود (Write-through)، و
/// [hydrateForStudent]/[hydrateForAdmin] تاریخچهٔ واقعی را از سرور می‌خوانند.
class AdvisorStore extends ChangeNotifier {
  AdvisorStore._() {
    // رفع اشکال امنیتی/حساسیت‌محتوایی جدی: قبلاً `_seed()` همیشه (حتی در
    // بیلد Live واقعی) دو گفتگوی جعلیِ حساس (موضوع خودآزاری/فشار خانوادگی)
    // را برای شناسه‌های ثابت `stu-1000`/`stu-1004` می‌ساخت. اگر `hydrateFor*`
    // به هر دلیل (خطای شبکه) ناکام می‌ماند، این دادهٔ ساختگی به‌جای تاریخچهٔ
    // واقعی باقی می‌ماند — هم ممکن بود به یک شاگرد واقعی با همان شناسه
    // نسبت داده شود، و هم در فهرست «گفتگوهای مشاور» مدیر (`threads()`)
    // همیشه به‌عنوان یک مورد پرچم‌دارِ واقعی ظاهر می‌شد و بازبینی امنیتی
    // واقعی مدیر را با نمونهٔ ساختگی گیج می‌کرد. اکنون این داده‌های نمونه
    // فقط در حالت Mock (فاز نمایشی/توسعه، `kUseLiveBackend == false`)
    // ساخته می‌شوند؛ در بیلد واقعی این فهرست تا رسیدن دادهٔ واقعیِ سرور
    // خالی می‌ماند.
    if (!kUseLiveBackend) _seed();
  }
  static final AdvisorStore instance = AdvisorStore._();

  final Map<String, List<AdvisorMessage>> _byStudent = {};
  final Map<String, String> _names = {};
  int _seq = 0;

  // ───────────────────── همگام‌سازی با سرور (Write-through) ─────────────────
  AdvisorRemoteDataSource? _remote;
  final Set<String> _hydratedStudents = {};

  /// اتصال به سرور (فقط در حالت Live صدا زده می‌شود).
  void configure(ApiClient api) {
    _remote ??= AdvisorRemoteDataSource(api);
  }

  bool get isLive => _remote != null;

  /// بارگذاری تاریخچهٔ واقعیِ شاگرد جاری از سرور (جایگزین دادهٔ نمونه).
  Future<void> hydrateForStudent(String studentId) async {
    final r = _remote;
    if (r == null || _hydratedStudents.contains(studentId)) return;
    try {
      final msgs = await r.fetchOwnMessages();
      _byStudent[studentId] = msgs;
      _hydratedStudents.add(studentId);
      notifyListeners();
    } catch (_) {
      // خطای شبکه: دادهٔ محلی فعلی حفظ می‌شود تا UI خالی نماند.
    }
  }

  /// بارگذاری تاریخچهٔ یک شاگرد مشخص برای نمای مدیر.
  Future<void> hydrateForAdmin(String studentId) async {
    final r = _remote;
    if (r == null) return;
    try {
      final msgs = await r.fetchStudentMessages(studentId);
      _byStudent[studentId] = msgs;
      if (msgs.isNotEmpty) _names[studentId] = msgs.first.studentName;
      _hydratedStudents.add(studentId);
      notifyListeners();
    } catch (_) {
      // خطای شبکه: فهرست فعلی (احتمالاً خالی) حفظ می‌شود.
    }
  }

  void _seed() {
    // نمونه‌های واقع‌گرایانه برای چند شاگرد فهرست مدیر (stu-1000..).
    final now = DateTime.now();
    // نام‌ها هماهنگ با StudentDirectory (منبع واحد حقیقت حساب‌های شاگرد).
    _addSeed('stu-1000', 'فاطمه رضایی', [
      _m('stu-1000', 'فاطمه رضایی', AdvisorRole.student,
          'سلام، این روزها برای امتحان‌ها خیلی استرس دارم و نمی‌توانم درست تمرکز کنم.',
          now.subtract(const Duration(days: 2, hours: 3)), topic: 'psychological'),
      _m('stu-1000', 'فاطمه رضایی', AdvisorRole.advisor,
          'سلام فاطمه عزیز 🌸 استرس امتحان کاملاً طبیعی است و نشان می‌دهد که برایت مهم است. بیا با هم یک برنامهٔ کوچک بسازیم: هر بار ۲۵ دقیقه درس و ۵ دقیقه استراحت. نفس عمیق هم خیلی کمک می‌کند. دوست داری با هم شروع کنیم؟',
          now.subtract(const Duration(days: 2, hours: 3)), topic: 'psychological'),
    ]);
    _addSeed('stu-1004', 'سمیرا نظری', [
      _m('stu-1004', 'سمیرا نظری', AdvisorRole.student,
          'در خانه اجازه نمی‌دهند زیاد درس بخوانم و باید کارهای خانه را انجام بدهم. دلم می‌گیرد.',
          now.subtract(const Duration(days: 1, hours: 5)), topic: 'family'),
      _m('stu-1004', 'سمیرا نظری', AdvisorRole.advisor,
          'می‌فهمم که چقدر این وضعیت سخت است، سمیرا جان. تو تنها نیستی و تلاشت ارزشمند است. شاید بتوانیم زمان‌های کوتاه اما منظم برای درس پیدا کنیم — مثلاً شب‌ها یا صبح زود. اگر بخواهی، می‌توانم راه‌های محترمانه‌ای پیشنهاد بدهم که با خانواده دربارهٔ اهمیت درس صحبت کنی.',
          now.subtract(const Duration(days: 1, hours: 5)), topic: 'family'),
    ]);
  }

  AdvisorMessage _m(String sid, String name, AdvisorRole role, String text, DateTime at,
          {String topic = 'general', bool flagged = false}) =>
      AdvisorMessage(
        id: 'seed_${_seq++}',
        studentId: sid,
        studentName: name,
        role: role,
        text: text,
        createdAt: at,
        topic: topic,
        flagged: flagged,
      );

  void _addSeed(String sid, String name, List<AdvisorMessage> msgs) {
    _names[sid] = name;
    _byStudent[sid] = msgs;
  }

  /// پیام‌های یک شاگرد (قدیم به جدید).
  List<AdvisorMessage> messagesFor(String studentId) =>
      List.unmodifiable(_byStudent[studentId] ?? const []);

  bool hasHistory(String studentId) => (_byStudent[studentId]?.isNotEmpty ?? false);

  bool hasFlagFor(String studentId) =>
      (_byStudent[studentId] ?? const []).any((m) => m.flagged);

  /// افزودن یک پیام و اطلاع‌رسانی.
  AdvisorMessage add({
    required String studentId,
    required String studentName,
    required AdvisorRole role,
    required String text,
    bool flagged = false,
    String topic = 'general',
  }) {
    final msg = AdvisorMessage(
      id: 'adv_${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
      studentId: studentId,
      studentName: studentName,
      role: role,
      text: text,
      createdAt: DateTime.now(),
      flagged: flagged,
      topic: topic,
    );
    _byStudent.putIfAbsent(studentId, () => []).add(msg);
    _names[studentId] = studentName;
    notifyListeners();

    final r = _remote;
    if (r != null) {
      unawaited(r
          .postMessage(role: role, text: text, topic: topic, flagged: flagged, studentName: studentName)
          .catchError((_) {}));
    }
    return msg;
  }

  /// فهرست گفتگوها برای نمای مدیر.
  List<AdvisorThreadSummary> threads() {
    final list = <AdvisorThreadSummary>[];
    _byStudent.forEach((sid, msgs) {
      if (msgs.isEmpty) return;
      list.add(AdvisorThreadSummary(
        studentId: sid,
        studentName: _names[sid] ?? sid,
        messageCount: msgs.length,
        lastAt: msgs.last.createdAt,
        hasFlag: msgs.any((m) => m.flagged),
      ));
    });
    list.sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return list;
  }
}
