import 'package:flutter/foundation.dart';

/// وضعیت حساب شاگرد از دید مدیریت (بخش ۱۵.۲ سند).
enum StudentAccountStatus { active, suspended, deleted }

/// پروفایل هویتی یک شاگرد — معلومات ثبت‌نامی حقیقی (نه تولیدی/تصادفی).
class StudentRecord {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String province;
  final DateTime? birthDate;
  final DateTime registeredAt;
  final StudentAccountStatus status;

  const StudentRecord({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.province = '',
    this.birthDate,
    required this.registeredAt,
    this.status = StudentAccountStatus.active,
  });

  StudentRecord copyWith({StudentAccountStatus? status}) => StudentRecord(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        province: province,
        birthDate: birthDate,
        registeredAt: registeredAt,
        status: status ?? this.status,
      );
}

/// **منبع واحد حقیقت حساب‌های شاگرد** — هم‌الگو با `InstructorDirectory`.
///
/// «مدیریت شاگردان» پنل مدیر از این دفترچه + منابع واقعی فعالیت
/// (ProgressionStore، AcademyStore، حاضری، GuardianLinkStore) تغذیه می‌شود،
/// نه از لیست تولیدی/تصادفی. هر شاگردی که با Invite Code راجستر شود،
/// بلافاصله اینجا (و در نتیجه در پنل مدیر) ظاهر می‌شود.
///
/// در فاز بعد با `GET /admin/users?role=student` (بخش ۱۹.۷ سند) جایگزین
/// می‌شود؛ Interface حفظ شود.
class StudentDirectory extends ChangeNotifier {
  StudentDirectory._() {
    // شاگردان Seed — هماهنگ با ProgressionStore (همان id ها: stu-1000/1001/1004)
    // و حساب Demo (بخش ۳.۵ سند) تا تمام داشبوردها یک روایت واحد داشته باشند.
    _students.addAll([
      StudentRecord(
        id: 'u-student-demo',
        fullName: 'مریم احمدی',
        email: 'student@demo.com',
        phone: '+93700000010',
        province: 'کابل',
        birthDate: DateTime(2011, 3, 14),
        registeredAt: DateTime(2026, 3, 1),
      ),
      StudentRecord(
        id: 'stu-1000',
        fullName: 'فاطمه رضایی',
        email: 'fatema@example.com',
        phone: '+93700000011',
        province: 'هرات',
        birthDate: DateTime(2010, 7, 2),
        registeredAt: DateTime(2025, 10, 12),
      ),
      StudentRecord(
        id: 'stu-1001',
        fullName: 'زهرا کریمی',
        email: 'zahra@example.com',
        phone: '+93700000012',
        province: 'بلخ',
        birthDate: DateTime(2009, 11, 20),
        registeredAt: DateTime(2025, 9, 5),
      ),
      StudentRecord(
        id: 'stu-1004',
        fullName: 'سمیرا نظری',
        email: 'samira@example.com',
        phone: '+93700000013',
        province: 'بامیان',
        birthDate: DateTime(2011, 1, 9),
        registeredAt: DateTime(2026, 1, 18),
      ),
    ]);
  }
  static final StudentDirectory instance = StudentDirectory._();

  final List<StudentRecord> _students = [];

  /// همهٔ شاگردان — جدیدترین ثبت‌نام اول.
  List<StudentRecord> get all {
    final list = [..._students]
      ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    return List.unmodifiable(list);
  }

  StudentRecord? byId(String id) {
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// افزودن شاگرد پس از راجستر موفق با Invite Code (از AuthMockDataSource).
  void register({
    required String id,
    required String fullName,
    required String email,
    String phone = '',
    String province = '',
    DateTime? birthDate,
  }) {
    if (_students.any((s) => s.id == id || s.email == email.trim())) return;
    _students.add(StudentRecord(
      id: id,
      fullName: fullName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      province: province.trim(),
      birthDate: birthDate,
      registeredAt: DateTime.now(),
    ));
    notifyListeners();
  }

  /// تغییر وضعیت حساب توسط مدیر (فعال/مسدود/حذف نرم — بخش ۱۵.۲).
  void setStatus(String id, StudentAccountStatus status) {
    final idx = _students.indexWhere((s) => s.id == id);
    if (idx == -1) return;
    _students[idx] = _students[idx].copyWith(status: status);
    notifyListeners();
  }
}
