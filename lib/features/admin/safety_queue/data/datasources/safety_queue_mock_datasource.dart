import '../../domain/entities/safety_queue_item.dart';
import 'safety_queue_remote_datasource.dart' show SafetyQueueDataSource;

class SafetyQueueMockDataSource implements SafetyQueueDataSource {
  final List<SafetyQueueItem> _items = [
    SafetyQueueItem(
      id: 'sq1',
      type: SafetyItemType.aiEscalation,
      summary: 'نشانهٔ پریشانی شخصی در گفتگوی AI Teacher — ریاضی',
      highPriority: true,
      status: SafetyItemStatus.open,
      studentName: 'زهرا احمدی',
      studentGrade: 'صنف ۹',
      source: 'AI Teacher — ریاضی',
      detectedAt: DateTime(2026, 7, 5, 14, 32),
      detail:
          'دانش‌آموز در جریان درس معادلات نوشت: «دیگه نمی‌تونم ادامه بدم، هیچ‌کس کمکم نمی‌کنه». '
          'سیستم این پیام را به‌عنوان نشانهٔ احتمالی پریشانی عاطفی علامت‌گذاری کرد و گفتگو را به صف بازبینی ارجاع داد.',
      triggerReason: 'تشخیص الگوی پریشانی عاطفی توسط فیلتر ایمنی',
    ),
    SafetyQueueItem(
      id: 'sq2',
      type: SafetyItemType.chatFlag,
      summary: 'پیام حاوی کلمهٔ فیلترشده در چت هم‌صنفی',
      highPriority: false,
      status: SafetyItemStatus.open,
      studentName: 'مریم نوری',
      studentGrade: 'صنف ۸',
      source: 'چت هم‌صنفی — صنف ۸ب',
      detectedAt: DateTime(2026, 7, 6, 9, 15),
      detail:
          'یک پیام در گروه چت صنف حاوی کلمه‌ای بود که در فهرست کلمات حساس قرار دارد. '
          'پیام پیش از نمایش برای دیگران به‌طور خودکار نگه داشته شد تا مدیر آن را بازبینی کند.',
      triggerReason: 'کلمهٔ فیلترشده در فهرست حساسیت محتوا',
    ),
    SafetyQueueItem(
      id: 'sq3',
      type: SafetyItemType.atRisk,
      summary: '۵ روز غیبت متوالی — دانش‌آموز صنف ۸',
      highPriority: true,
      status: SafetyItemStatus.open,
      studentName: 'فاطمه رضایی',
      studentGrade: 'صنف ۸',
      source: 'سیستم حاضری',
      detectedAt: DateTime(2026, 7, 6, 6, 0),
      detail:
          'این دانش‌آموز طی ۵ روز کاری گذشته هیچ فعالیتی نداشته و در هیچ درسی حاضر نشده است. '
          'طبق آستانهٔ «در معرض خطر» (بخش ۹.۳ سند) پرونده برای پیگیری مدیریت باز شده است.',
      triggerReason: 'عبور از آستانهٔ ۵ روز غیبت متوالی',
    ),
  ];

  @override
  Future<List<SafetyQueueItem>> getQueue() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_items);
  }

  @override
  Future<void> resolve(String id, SafetyItemStatus newStatus) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _items.indexWhere((i) => i.id == id);
    if (idx != -1) _items[idx] = _items[idx].copyWith(status: newStatus);
  }
}
