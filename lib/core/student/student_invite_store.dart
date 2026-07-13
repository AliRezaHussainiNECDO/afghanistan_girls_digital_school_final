import 'dart:math';
import 'package:flutter/foundation.dart';

/// وضعیت یک کد دعوت شاگرد.
enum StudentCodeStatus { unused, used, revoked }

/// کد دعوت ثبت‌نام شاگرد (بخش ۳ب سند) — توسط مدیر به‌صورت دسته‌ای صادر و
/// از طریق مکتب/سازمان همکار به دختران داده می‌شود.
class StudentInviteCode {
  final String id;
  final String code;
  final String batchLabel;
  final DateTime createdAt;
  final DateTime expiresAt;
  final StudentCodeStatus status;

  // پس از مصرف — برای قابلیت بازبینی (Auditability، بخش ۱.۲ سند).
  final String usedByName;
  final String usedByEmail;
  final DateTime? usedAt;

  const StudentInviteCode({
    required this.id,
    required this.code,
    required this.batchLabel,
    required this.createdAt,
    required this.expiresAt,
    this.status = StudentCodeStatus.unused,
    this.usedByName = '',
    this.usedByEmail = '',
    this.usedAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);

  int get remainingDays {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? 0 : d.inDays;
  }

  StudentInviteCode copyWith({
    StudentCodeStatus? status,
    String? usedByName,
    String? usedByEmail,
    DateTime? usedAt,
  }) =>
      StudentInviteCode(
        id: id,
        code: code,
        batchLabel: batchLabel,
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        usedByName: usedByName ?? this.usedByName,
        usedByEmail: usedByEmail ?? this.usedByEmail,
        usedAt: usedAt ?? this.usedAt,
      );
}

/// **منبع واحد حقیقت کدهای دعوت شاگردان** — مشترک بین CMS مدیر (صدور
/// دسته‌ای/ابطال، بخش ۳ب.۳) و صفحهٔ راجستر شاگرد (اعتبارسنجی، بخش ۳ب.۲).
///
/// نکات امنیتی این پیاده‌سازی:
/// * **`Random.secure()`** برای تولید کد (نه Random معمولی قابل پیش‌بینی).
/// * الفبای بدون کاراکترهای مبهم (بدون O/0 و I/1) — خطای تایپ کمتر.
/// * **یک‌بارمصرف + انقضا** (پیش‌فرض ۳۰ روز) + قابلیت ابطال توسط مدیر.
/// * **پیام خطای یکسان** برای نامعتبر/مصرف‌شده/باطل/منقضی (بخش ۳ب.۲.۴ —
///   تا مهاجم نتواند با آزمون‌وخطا وضعیت کدها را کشف کند).
/// * **قفل ضد حدس (Rate Limit)**: پس از ۵ تلاش ناکام، ۶۰ ثانیه قفل.
/// * **ثبت مصرف‌کننده** (نام/ایمیل/زمان) روی رکورد کد — Auditability.
///
/// در فاز بعد با جدول `invite_codes` و Endpoint های بخش ۱۹ جایگزین می‌شود.
class StudentInviteStore extends ChangeNotifier {
  StudentInviteStore._() {
    // دادهٔ اولیهٔ سازگار: همان کدهای نمایشی قبلی، این‌بار در «یک» منبع.
    final now = DateTime.now();
    _codes.addAll([
      StudentInviteCode(
        id: 'ic1',
        code: 'DEMO1234',
        batchLabel: 'دفعهٔ آزمایشی',
        createdAt: DateTime(2026, 6, 1),
        expiresAt: now.add(const Duration(days: 365)), // کد دمو — دیر منقضی شود
      ),
      StudentInviteCode(
        id: 'ic2',
        code: 'KABUL0007',
        batchLabel: 'کابل - دفعهٔ ۱',
        createdAt: DateTime(2026, 6, 10),
        expiresAt: DateTime(2026, 6, 10).add(const Duration(days: 90)),
      ),
      StudentInviteCode(
        id: 'ic3',
        code: 'HERAT0099',
        batchLabel: 'هرات - دفعهٔ ۱',
        createdAt: DateTime(2026, 6, 12),
        expiresAt: DateTime(2026, 6, 12).add(const Duration(days: 90)),
        status: StudentCodeStatus.used,
        usedByName: 'شاگرد قبلی (دادهٔ نمونه)',
        usedAt: DateTime(2026, 6, 20),
      ),
    ]);
  }
  static final StudentInviteStore instance = StudentInviteStore._();

  /// Random.secure: مولد اعداد تصادفیِ رمزنگارانه — کدها قابل حدس نیستند.
  final Random _rand = Random.secure();
  final List<StudentInviteCode> _codes = [];

  // ── قفل ضد حدس (Brute-force protection) ──
  int _failedAttempts = 0;
  DateTime? _lockedUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(seconds: 60);

  /// پیام یکسان برای همهٔ حالت‌های ناکامی — بخش ۳ب.۲.۴ سند.
  static const String _uniformError = 'کد دعوت نامعتبر است یا قبلاً استفاده شده';

  List<StudentInviteCode> get codes {
    final list = [..._codes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  // ─────────────────── سمت مدیر (CMS، بخش ۳ب.۳) ───────────────────

  /// صدور دسته‌ای کد با برچسب دفعه (مثلاً نام ولایت) و اعتبار مشخص.
  /// فرمت: ۸ کاراکتر از الفبای بدون ابهام، مثل `K7MW2PXN`.
  List<StudentInviteCode> generateBatch(int count, String batchLabel, {int validDays = 30}) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final created = <StudentInviteCode>[];
    for (var i = 0; i < count; i++) {
      String code;
      do {
        code = List.generate(8, (_) => chars[_rand.nextInt(chars.length)]).join();
      } while (_codes.any((c) => c.code == code));
      final now = DateTime.now();
      final invite = StudentInviteCode(
        id: 'ic-${now.microsecondsSinceEpoch}-$i',
        code: code,
        batchLabel: batchLabel,
        createdAt: now,
        expiresAt: now.add(Duration(days: validDays)),
      );
      _codes.add(invite);
      created.add(invite);
    }
    if (created.isNotEmpty) notifyListeners();
    return created;
  }

  /// ابطال کد استفاده‌نشده — بلافاصله در راجستر هم بی‌اعتبار می‌شود.
  void revoke(String id) {
    final idx = _codes.indexWhere((c) => c.id == id);
    if (idx == -1 || _codes[idx].status != StudentCodeStatus.unused) return;
    _codes[idx] = _codes[idx].copyWith(status: StudentCodeStatus.revoked);
    notifyListeners();
  }

  // ─────────────────── سمت راجستر شاگرد (بخش ۳ب.۲) ───────────────────

  /// اعتبارسنجی و مصرف کد هنگام ثبت‌نام شاگرد.
  StudentInviteCode redeem({
    required String rawCode,
    required String studentName,
    required String studentEmail,
  }) {
    // قفل ضد حدس: پیش از هر بررسی.
    final locked = _lockedUntil;
    if (locked != null && DateTime.now().isBefore(locked)) {
      final secs = locked.difference(DateTime.now()).inSeconds + 1;
      throw 'به دلیل تلاش‌های ناکام زیاد، $secs ثانیه صبر کنید و دوباره امتحان کنید.'; // ignore: only_throw_errors
    }

    final code = _normalize(rawCode);
    final idx = _codes.indexWhere((c) => c.code == code);
    final invite = idx == -1 ? null : _codes[idx];
    final valid = invite != null &&
        invite.status == StudentCodeStatus.unused &&
        !invite.expired;

    if (!valid) {
      _registerFailure();
      // پیام یکسان برای نامعتبر/مصرف‌شده/باطل/منقضی — بخش ۳ب.۲.۴.
      throw _uniformError; // ignore: only_throw_errors
    }

    _failedAttempts = 0;
    _lockedUntil = null;
    final used = invite.copyWith(
      status: StudentCodeStatus.used,
      usedByName: studentName.trim(),
      usedByEmail: studentEmail.trim(),
      usedAt: DateTime.now(),
    );
    _codes[idx] = used;
    notifyListeners();
    return used;
  }

  void _registerFailure() {
    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      _lockedUntil = DateTime.now().add(_lockDuration);
      _failedAttempts = 0;
    }
  }

  /// نرمال‌سازی: حروف بزرگ، حذف فاصله/خط تیره، تبدیل ارقام فارسی/عربی.
  String _normalize(String raw) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in raw.trim().toUpperCase().split('')) {
      final iFa = fa.indexOf(ch);
      final iAr = ar.indexOf(ch);
      if (iFa >= 0) {
        b.write(iFa);
      } else if (iAr >= 0) {
        b.write(iAr);
      } else if (ch != ' ' && ch != '-') {
        b.write(ch);
      }
    }
    return b.toString();
  }
}
