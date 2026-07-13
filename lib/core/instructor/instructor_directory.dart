import 'package:flutter/foundation.dart';

/// پروفایل یک استاد سمینار — از دید پنل مدیریت (بخش ۱۵.۲ سند).
class InstructorProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String specialty;
  final String bio;
  final DateTime joinedAt;
  final bool suspended;

  const InstructorProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.specialty = '',
    this.bio = '',
    required this.joinedAt,
    this.suspended = false,
  });

  InstructorProfile copyWith({bool? suspended}) => InstructorProfile(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        specialty: specialty,
        bio: bio,
        joinedAt: joinedAt,
        suspended: suspended ?? this.suspended,
      );
}

/// **منبع واحد حقیقت حساب‌های استاد** — مشترک بین راجستر استاد (افزودن
/// خودکار پس از فعال‌سازی با کد دعوت) و بخش «مدیریت استادان» پنل مدیر.
///
/// همانند `GuardianLinkStore`/`SeminarStore` یک Singleton درون‌حافظه‌ای فاز ۱
/// است و در فاز بعد با `GET /admin/users?role=seminar_instructor` (بخش ۱۹.۷
/// سند) جایگزین می‌شود؛ ChangeNotifier است تا لیست مدیر بلافاصله پس از هر
/// تغییر (راجستر استاد جدید، مسدودسازی) به‌روز شود.
class InstructorDirectory extends ChangeNotifier {
  InstructorDirectory._() {
    final now = DateTime.now();
    // استادان نمایشی — هماهنگ با حساب‌های Demo و سمینارهای SeminarStore.
    _instructors.addAll([
      InstructorProfile(
        id: 'u-instructor-demo',
        fullName: 'استاد رحیمی',
        email: 'instructor@demo.com',
        phone: '+93700000001',
        specialty: 'مهارت‌های مطالعه و آمادگی امتحان',
        bio: 'برگزارکنندهٔ سمینارهای مهارت‌های مطالعه برای شاگردان و والدین.',
        joinedAt: now.subtract(const Duration(days: 90)),
      ),
      InstructorProfile(
        id: 'u-instructor-2',
        fullName: 'استاد کریمی',
        email: 'karimi.instructor@example.com',
        phone: '+93700000002',
        specialty: 'برنامه‌نویسی و ایمنی آنلاین',
        bio: 'مدرس دوره‌های مقدماتی برنامه‌نویسی نوجوانان.',
        joinedAt: now.subtract(const Duration(days: 45)),
      ),
    ]);
  }
  static final InstructorDirectory instance = InstructorDirectory._();

  final List<InstructorProfile> _instructors = [];

  /// همهٔ استادان — جدیدترین اول (برای لیست مدیر).
  List<InstructorProfile> get all {
    final list = [..._instructors]..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    return List.unmodifiable(list);
  }

  InstructorProfile? byId(String id) {
    for (final i in _instructors) {
      if (i.id == id) return i;
    }
    return null;
  }

  /// جستجو بر اساس نام/ایمیل/تخصص (فیلتر لیست مدیر — بخش ۱۵.۲).
  List<InstructorProfile> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return all;
    return List.unmodifiable(all.where((i) =>
        i.fullName.contains(q) || i.email.contains(q) || i.specialty.contains(q)));
  }

  /// افزودن استاد پس از راجستر موفق با کد دعوت (از AuthMockDataSource).
  void register({
    required String id,
    required String fullName,
    required String email,
    String phone = '',
    String specialty = '',
    String bio = '',
  }) {
    if (_instructors.any((i) => i.id == id || i.email == email.trim())) return;
    _instructors.add(InstructorProfile(
      id: id,
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      specialty: specialty.trim(),
      bio: bio.trim(),
      joinedAt: DateTime.now(),
    ));
    notifyListeners();
  }

  /// مسدود/فعال‌سازی حساب استاد توسط مدیر (بخش ۱۵.۲ — کنترل کامل مدیر).
  void setSuspended(String id, bool suspended) {
    final idx = _instructors.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _instructors[idx] = _instructors[idx].copyWith(suspended: suspended);
    notifyListeners();
  }
}
