import 'package:flutter/foundation.dart';
import '../domain/advisor_entities.dart';

/// انبار گفتگوهای «مشاور هوشمند» — تاریخچهٔ هر شاگرد به‌صورت جداگانه نگه
/// داشته می‌شود تا هم شاگرد گفتگوی خود را ادامه دهد و هم مدیر بتواند در
/// جزئیات شاگرد آن را بازبینی/تعقیب کند.
///
/// یک [ChangeNotifier] singleton است؛ هر صفحه‌ای که گوش می‌دهد بلافاصله
/// به‌روزرسانی می‌شود. در فاز اتصال به Backend، همین منبع با API جایگزین
/// می‌شود بدون تغییر در UI.
class AdvisorStore extends ChangeNotifier {
  AdvisorStore._() {
    _seed();
  }
  static final AdvisorStore instance = AdvisorStore._();

  final Map<String, List<AdvisorMessage>> _byStudent = {};
  final Map<String, String> _names = {};
  int _seq = 0;

  void _seed() {
    // نمونه‌های واقع‌گرایانه برای چند شاگرد فهرست مدیر (stu-1000..).
    final now = DateTime.now();
    // نام‌ها هماهنگ با StudentDirectory (منبع واحد حقیقت حساب‌های شاگرد).
    _addSeed('stu-1000', 'فاطمه رضایی', [
      _m('stu-1000', 'فاطمه رضایی', AdvisorRole.student,
          'سلام، این روزها برای امتحان‌ها خیلی استرس دارم و نمی‌توانم درست تمرکز کنم.',
          now.subtract(const Duration(days: 2, hours: 3)), topic: 'روانی'),
      _m('stu-1000', 'فاطمه رضایی', AdvisorRole.advisor,
          'سلام فاطمه عزیز 🌸 استرس امتحان کاملاً طبیعی است و نشان می‌دهد که برایت مهم است. بیا با هم یک برنامهٔ کوچک بسازیم: هر بار ۲۵ دقیقه درس و ۵ دقیقه استراحت. نفس عمیق هم خیلی کمک می‌کند. دوست داری با هم شروع کنیم؟',
          now.subtract(const Duration(days: 2, hours: 3)), topic: 'روانی'),
    ]);
    _addSeed('stu-1004', 'سمیرا نظری', [
      _m('stu-1004', 'سمیرا نظری', AdvisorRole.student,
          'در خانه اجازه نمی‌دهند زیاد درس بخوانم و باید کارهای خانه را انجام بدهم. دلم می‌گیرد.',
          now.subtract(const Duration(days: 1, hours: 5)), topic: 'خانوادگی'),
      _m('stu-1004', 'سمیرا نظری', AdvisorRole.advisor,
          'می‌فهمم که چقدر این وضعیت سخت است، سمیرا جان. تو تنها نیستی و تلاشت ارزشمند است. شاید بتوانیم زمان‌های کوتاه اما منظم برای درس پیدا کنیم — مثلاً شب‌ها یا صبح زود. اگر بخواهی، می‌توانم راه‌های محترمانه‌ای پیشنهاد بدهم که با خانواده دربارهٔ اهمیت درس صحبت کنی.',
          now.subtract(const Duration(days: 1, hours: 5)), topic: 'خانوادگی'),
    ]);
  }

  AdvisorMessage _m(String sid, String name, AdvisorRole role, String text, DateTime at,
          {String topic = 'عمومی', bool flagged = false}) =>
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
    String topic = 'عمومی',
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
