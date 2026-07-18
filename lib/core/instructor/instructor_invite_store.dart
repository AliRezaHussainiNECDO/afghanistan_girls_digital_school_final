import 'dart:math';
import 'package:flutter/foundation.dart';

/// وضعیت یک کد دعوت استاد.
enum InstructorCodeStatus { unused, used, revoked }

/// کد دعوت استاد سمینار — توسط Super Admin ساخته می‌شود (بخش ۲.۲ سند:
/// فقط مدیر می‌تواند استاد اضافه کند) و استاد با آن حساب خود را در صفحهٔ
/// راجستر فعال می‌کند.
class InstructorInviteCode {
  final String id;
  final String code;

  /// برچسب مدیر (مثلاً نام استاد یا تخصص موردنظر) — برای پیگیری اینکه هر
  /// کد برای چه کسی ساخته شده است.
  final String label;
  final DateTime createdAt;
  final DateTime expiresAt;
  final InstructorCodeStatus status;

  // پس از استفاده: چه کسی با این کد ثبت‌نام کرد (برای گزارش مدیر).
  final String usedByName;
  final String usedByEmail;
  final String usedSpecialty;
  final DateTime? usedAt;

  const InstructorInviteCode({
    required this.id,
    required this.code,
    required this.label,
    required this.createdAt,
    required this.expiresAt,
    this.status = InstructorCodeStatus.unused,
    this.usedByName = '',
    this.usedByEmail = '',
    this.usedSpecialty = '',
    this.usedAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);

  int get remainingDays {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? 0 : d.inDays;
  }

  InstructorInviteCode copyWith({
    InstructorCodeStatus? status,
    String? usedByName,
    String? usedByEmail,
    String? usedSpecialty,
    DateTime? usedAt,
  }) =>
      InstructorInviteCode(
        id: id,
        code: code,
        label: label,
        createdAt: createdAt,
        expiresAt: expiresAt,
        status: status ?? this.status,
        usedByName: usedByName ?? this.usedByName,
        usedByEmail: usedByEmail ?? this.usedByEmail,
        usedSpecialty: usedSpecialty ?? this.usedSpecialty,
        usedAt: usedAt ?? this.usedAt,
      );
}

/// **منبع واحد حقیقت کدهای دعوت استادان** — مشترک بین پنل مدیر (ساخت/ابطال
/// کد) و صفحهٔ راجستر استاد (فعال‌سازی حساب با کد).
///
/// منطق (الهام از پروتکل Invite Code بخش ۳ب سند):
/// * هر کد **یک‌بارمصرف** است و برای «یک استاد مشخص» ساخته می‌شود
///   (برخلاف کد والدین که ممکن است دو سرپرست استفاده کنند).
/// * اعتبار پیش‌فرض ۱۴ روز — کافی برای هماهنگی با استاد، کوتاه برای امنیت.
/// * پس از استفاده، نام/ایمیل/تخصص استاد روی همان رکورد ثبت می‌شود تا مدیر
///   دقیقاً ببیند هر کد را چه کسی مصرف کرده است (قابلیت بازبینی — بخش ۱.۲).
/// * ChangeNotifier است تا لیست مدیر بلافاصله پس از هر تغییر به‌روز شود.
///
/// در فاز بعد با جدول `invite_codes` (نوع instructor) و Endpoint های
/// `POST /admin/invite-codes` جایگزین می‌شود.
class InstructorInviteStore extends ChangeNotifier {
  InstructorInviteStore._() {
    // یک کد نمونه برای تست سریع جریان (مشابه DEMO1234 شاگردان).
    final now = DateTime.now();
    _codes.add(InstructorInviteCode(
      id: 'inst-demo-1',
      code: 'TCH-DEMO01',
      label: 'کد نمایشی (تست)',
      createdAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    ));
  }
  static final InstructorInviteStore instance = InstructorInviteStore._();

  final Random _rand = Random();
  final List<InstructorInviteCode> _codes = [];

  /// همهٔ کدها — جدیدترین اول (برای لیست مدیر).
  List<InstructorInviteCode> get codes {
    final list = [..._codes]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  // ─────────────────── سمت مدیر ───────────────────

  /// ساخت کد جدید با فرمت خوانا `TCH-XXXXXX` (حروف/ارقام بدون کاراکترهای
  /// مبهم مثل O/0 و I/1).
  InstructorInviteCode issueCode({required String label, int validDays = 14}) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = 'TCH-${List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join()}';
    } while (_codes.any((c) => c.code == code));
    final now = DateTime.now();
    final invite = InstructorInviteCode(
      id: 'inst-${now.microsecondsSinceEpoch}',
      code: code,
      label: label.trim(),
      createdAt: now,
      expiresAt: now.add(Duration(days: validDays)),
    );
    _codes.add(invite);
    notifyListeners();
    return invite;
  }

  /// ابطال کد استفاده‌نشده توسط مدیر.
  void revoke(String id) {
    final idx = _codes.indexWhere((c) => c.id == id);
    if (idx == -1 || _codes[idx].status != InstructorCodeStatus.unused) return;
    _codes[idx] = _codes[idx].copyWith(status: InstructorCodeStatus.revoked);
    notifyListeners();
  }

  // ─────────────────── سمت استاد (راجستر) ───────────────────

  static const Map<String, Map<String, String>> _i18n = {
    'fa': {
      'invalidCode': 'کد دعوت استاد نامعتبر است. این کد را باید مدیریت مکتب برای شما ساخته باشد.',
      'revokedCode': 'این کد توسط مدیریت باطل شده است. لطفاً با مدیریت تماس بگیرید.',
      'usedCode': 'این کد قبلاً استفاده شده است. هر کد فقط برای یک استاد معتبر است.',
      'expiredCode': 'این کد منقضی شده است. از مدیریت بخواهید کد جدید بسازد.',
    },
    'en': {
      'invalidCode': 'The instructor invite code is invalid. This code must have been generated for you by the school administration.',
      'revokedCode': 'This code has been revoked by the administration. Please contact the administration.',
      'usedCode': 'This code has already been used. Each code is valid for only one instructor.',
      'expiredCode': 'This code has expired. Ask the administration to generate a new one.',
    },
    'ps': {
      'invalidCode': 'د استاد بلنې کوډ ناسم دی. دا کوډ باید ستاسو لپاره د ښوونځي ادارې لخوا جوړ شوی وي.',
      'revokedCode': 'دا کوډ د ادارې لخوا لغوه شوی دی. مهرباني وکړئ له ادارې سره اړیکه ونیسئ.',
      'usedCode': 'دا کوډ دمخه کارول شوی دی. هر کوډ یوازې د یو استاد لپاره معتبر دی.',
      'expiredCode': 'دا کوډ ختم شوی دی. له ادارې وغواړئ چې نوی کوډ جوړ کړي.',
    },
    'fr': {
      'invalidCode': 'Le code d’invitation instructeur est invalide. Ce code doit avoir été créé pour vous par l’administration de l’école.',
      'revokedCode': 'Ce code a été révoqué par l’administration. Veuillez contacter l’administration.',
      'usedCode': 'Ce code a déjà été utilisé. Chaque code n’est valide que pour un seul instructeur.',
      'expiredCode': 'Ce code a expiré. Demandez à l’administration d’en générer un nouveau.',
    },
  };

  String _tr(String localeCode, String key) => _i18n[localeCode]?[key] ?? _i18n['fa']![key]!;

  /// فعال‌سازی حساب استاد با کد. یک‌بارمصرف؛ خطاهای خوانا برای هر حالت.
  InstructorInviteCode redeem({
    required String rawCode,
    required String fullName,
    required String email,
    required String specialty,
    String localeCode = 'fa',
  }) {
    final code = _normalize(rawCode);
    final idx = _codes.indexWhere((c) => _normalize(c.code) == code);
    if (code.isEmpty || idx == -1) {
      throw _tr(localeCode, 'invalidCode'); // ignore: only_throw_errors
    }
    final invite = _codes[idx];
    if (invite.status == InstructorCodeStatus.revoked) {
      throw _tr(localeCode, 'revokedCode'); // ignore: only_throw_errors
    }
    if (invite.status == InstructorCodeStatus.used) {
      throw _tr(localeCode, 'usedCode'); // ignore: only_throw_errors
    }
    if (invite.expired) {
      throw _tr(localeCode, 'expiredCode'); // ignore: only_throw_errors
    }
    final used = invite.copyWith(
      status: InstructorCodeStatus.used,
      usedByName: fullName.trim(),
      usedByEmail: email.trim(),
      usedSpecialty: specialty.trim(),
      usedAt: DateTime.now(),
    );
    _codes[idx] = used;
    notifyListeners();
    return used;
  }

  /// نرمال‌سازی: حذف فاصله‌ها، حروف بزرگ، و تبدیل ارقام فارسی/عربی.
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
      } else if (ch != ' ') {
        b.write(ch);
      }
    }
    return b.toString();
  }
}
