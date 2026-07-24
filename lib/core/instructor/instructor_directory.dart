import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

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
  // کد دعوتی که این استاد با آن راجستر شده — مستقیماً از سرور (جدول واقعی
  // `invite_codes`)، نه یک Store محلیِ فقط-Mock (رفع اشکال: قبلاً در حالت
  // Backend واقعی همیشه خالی می‌ماند چون آن Store هرگز از سرور پر نمی‌شد).
  final String? inviteCode;
  final String? inviteBatchLabel;

  const InstructorProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.specialty = '',
    this.bio = '',
    required this.joinedAt,
    this.suspended = false,
    this.inviteCode,
    this.inviteBatchLabel,
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
        inviteCode: inviteCode,
        inviteBatchLabel: inviteBatchLabel,
      );
}

/// **منبع واحد حقیقت حساب‌های استاد** — مشترک بین راجستر استاد (افزودن
/// خودکار پس از فعال‌سازی با کد دعوت) و بخش «مدیریت استادان» پنل مدیر.
///
/// همانند `GuardianLinkMockStore`/`SeminarStore` یک Singleton درون‌حافظه‌ای فاز ۱
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

  /// آیا حداقل یک‌بار با موفقیت از سرور واقعی بارگذاری شده؟ در حالت
  /// Backend واقعی، صفحات مدیر تا این مقدار `true` نشود دادهٔ نمایشی
  /// (Seed) را به‌جای دادهٔ واقعی نشان نمی‌دهند.
  bool loadedFromBackend = false;
  bool loading = false;

  /// رفع اشکال: قبلاً خطای شبکه/سرور کاملاً بی‌صدا بلعیده می‌شد و اگر اولین
  /// بارگذاری شکست می‌خورد، صفحهٔ لیست/جزئیات استاد برای همیشه چرخ‌وفلک
  /// نمایش می‌داد (چون `loadedFromBackend` هرگز true نمی‌شد) — بدون هیچ پیام
  /// خطا یا دکمهٔ «تلاش دوباره» برای مدیر. اکنون آخرین خطا نگه داشته می‌شود
  /// تا UI بتواند آن را نشان دهد و امکان تلاش دوباره بدهد.
  String? lastError;

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

  /// مسدود/فعال‌سازی حساب استاد توسط مدیر (بخش ۱۵.۲ — کنترل کامل مدیر) —
  /// فقط محلی (حالت Mock/فاز ۱ بدون سرور).
  void setSuspended(String id, bool suspended) {
    final idx = _instructors.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    _instructors[idx] = _instructors[idx].copyWith(suspended: suspended);
    notifyListeners();
  }

  /// بارگذاری فهرست واقعی استادان از سرور — `GET /admin/users?role=seminar_instructor`
  /// (بخش ۱۵.۲ سند). لیست نمایشی/Seed را با دادهٔ واقعی جایگزین می‌کند.
  Future<void> loadFromBackend(ApiClient api) async {
    loading = true;
    notifyListeners();
    try {
      final data = await api.get('/admin/users', queryParameters: {'role': 'seminar_instructor'});
      final list = (data is Map ? data['users'] as List? : null) ?? const [];
      _instructors
        ..clear()
        ..addAll(list.map((e) => _fromJson(Map<String, dynamic>.from(e as Map))));
      loadedFromBackend = true;
      lastError = null;
    } catch (e) {
      // خطای شبکه/سرور — فهرست فعلی (Seed یا آخرین بارگذاری موفق) دست‌نخورده
      // می‌ماند، اما خطا را ذخیره می‌کنیم تا UI به‌جای چرخ‌وفلک بی‌پایان،
      // پیام خطا + دکمهٔ «تلاش دوباره» نشان دهد.
      lastError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// مسدود/فعال‌سازی واقعی روی سرور — `PATCH /admin/users/:id/toggle-suspend`.
  Future<bool> toggleSuspendRemote(ApiClient api, String id) async {
    try {
      final data = await api.patch('/admin/users/$id/toggle-suspend');
      final status = (data is Map ? data['status'] as String? : null) ?? 'active';
      final idx = _instructors.indexWhere((i) => i.id == id);
      if (idx != -1) {
        _instructors[idx] = _instructors[idx].copyWith(suspended: status != 'active');
        notifyListeners();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  InstructorProfile _fromJson(Map<String, dynamic> j) => InstructorProfile(
        id: j['id'] as String,
        fullName: (j['name'] as String?)?.trim().isNotEmpty == true
            ? (j['name'] as String).trim()
            : (j['email'] as String? ?? ''),
        email: j['email'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        specialty: j['specialty'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        joinedAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        suspended: j['suspended'] as bool? ?? false,
        inviteCode: j['inviteCode'] as String?,
        inviteBatchLabel: j['inviteBatchLabel'] as String?,
      );
}
