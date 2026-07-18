import 'dart:math';
import 'package:flutter/foundation.dart';

/// یک کد دعوت والد (بخش ۲.۴ سند): ۶ رقمی، با عمر ۷۲ ساعت، به‌ازای هر
/// شاگرد فقط یک کد فعال (تولید کد جدید، کد قبلی را باطل می‌کند).
class GuardianInviteCode {
  final String code;
  final String studentId;
  final String studentName;
  final int grade;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const GuardianInviteCode({
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);

  /// ساعت‌های باقی‌مانده تا انقضا (برای نمایش به شاگرد).
  int get remainingHours {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? 0 : d.inHours;
  }
}

/// وضعیت پیوند والد-فرزند (بخش ۱۳ب.۲ سند).
enum GuardianLinkStatus { pendingStudentApproval, approved, rejected }

/// یک پیوند والد ↔ فرزند (معادل رکورد `parent_student_links` در Schema).
class ParentStudentLink {
  final String parentId;

  /// نام والد — تا شاگرد هنگام تأیید بداند چه کسی درخواست داده
  /// (اصلاح ۲.۴ سند، بخش ۱۳ب.۲).
  final String parentName;
  final String studentId;
  final String studentName;
  final int gradeAtLink; // صنف فرزند در لحظهٔ لینک‌شدن
  final DateTime linkedAt;
  final GuardianLinkStatus status;

  const ParentStudentLink({
    required this.parentId,
    this.parentName = '',
    required this.studentId,
    required this.studentName,
    required this.gradeAtLink,
    required this.linkedAt,
    required this.status,
  });

  ParentStudentLink copyWith({GuardianLinkStatus? status}) => ParentStudentLink(
        parentId: parentId,
        parentName: parentName,
        studentId: studentId,
        studentName: studentName,
        gradeAtLink: gradeAtLink,
        linkedAt: linkedAt,
        status: status ?? this.status,
      );
}

/// **منبع واحد حقیقتِ پیوند والد-فرزند** — مشترک بین پروفایل شاگرد
/// (تولید کد دعوت) و داشبورد والدین (استفاده از کد و لیست فرزندان).
///
/// همانند `AcademyStore`/`ProgressionStore` یک singleton درون‌حافظه‌ای است و
/// در فاز بعد بدون تغییر UI با Backend واقعی (Endpoint های
/// `POST /students/{id}/guardian-invite-code` و
/// `POST /parents/{id}/link-requests`، بخش ۱۹ سند) جایگزین می‌شود.
///
/// ChangeNotifier است تا با هر تغییر (تولید کد، لینک‌شدن فرزند جدید)
/// همهٔ صفحه‌های وابسته — لیست فرزندان، نمرات، خلاصهٔ فرزند — خودکار
/// بازسازی شوند.
class GuardianLinkStore extends ChangeNotifier {
  GuardianLinkStore._();
  static final GuardianLinkStore instance = GuardianLinkStore._();

  final Random _rand = Random();

  /// کدهای دعوت فعال؛ کلید = خود کد ۶ رقمی.
  final Map<String, GuardianInviteCode> _codes = {};

  /// پیوندهای والد-فرزند. حساب Demo از پیش لینک‌شده است (بخش ۳.۵ سند) تا
  /// والدِ نمایشی بدون کد هم داشبورد را ببیند.
  final List<ParentStudentLink> _links = [
    ParentStudentLink(
      parentId: 'u-parent-demo',
      parentName: 'خانم کریمی',
      studentId: 'u-student-demo',
      studentName: 'مریم احمدی',
      gradeAtLink: 9,
      linkedAt: DateTime(2026, 6, 1),
      status: GuardianLinkStatus.approved,
    ),
  ];

  // ─────────────────── سمت شاگرد: تولید کد دعوت ───────────────────

  /// تولید کد دعوت برای والدین (بخش ۲.۴): ۶ رقمی، ۷۲ ساعت اعتبار.
  /// کد قبلی همان شاگرد (در صورت وجود) باطل می‌شود؛ اما تا زمان انقضا،
  /// «هر دو والد/سرپرست» می‌توانند از همان یک کد استفاده کنند.
  GuardianInviteCode issueCode({
    required String studentId,
    required String studentName,
    required int grade,
  }) {
    _codes.removeWhere((_, c) => c.studentId == studentId || c.expired);
    String code;
    do {
      code = List.generate(6, (_) => _rand.nextInt(10)).join();
    } while (_codes.containsKey(code));
    final now = DateTime.now();
    final invite = GuardianInviteCode(
      code: code,
      studentId: studentId,
      studentName: studentName,
      grade: grade,
      issuedAt: now,
      expiresAt: now.add(const Duration(hours: 72)),
    );
    _codes[code] = invite;
    notifyListeners();
    return invite;
  }

  /// کد فعال فعلی یک شاگرد (برای نمایش دوباره در پروفایل)، یا null.
  GuardianInviteCode? activeCodeFor(String studentId) {
    for (final c in _codes.values) {
      if (c.studentId == studentId && !c.expired) return c;
    }
    return null;
  }

  // ─────────────────── سمت والد: استفاده از کد ───────────────────

  /// والد کد دعوت را وارد می‌کند. در صورت اعتبار، پیوند با وضعیت
  /// `pending_student_approval` ساخته می‌شود و باید توسط خود شاگرد تأیید
  /// شود (بخش ۱۳ب.۲ / ۳ب.۴ سند — اصلاح ۲.۴: قبلاً در این فاز نمایشی
  /// بلافاصله approved می‌شد که ناقض عاملیت شاگرد بود). برای چند فرزند،
  /// والد همین کار را با کدِ هر فرزند تکرار می‌کند (بخش ۱۳ب.۵).
  static const Map<String, Map<String, String>> _i18n = {
    'fa': {
      'codeMustBe6Digits': 'کد دعوت باید ۶ رقم باشد.',
      'invalidCode': 'کد دعوت نامعتبر است. از فرزندتان بخواهید از بخش پروفایل، کد جدید بسازد.',
      'expiredCode': 'این کد منقضی شده است (اعتبار کد ۷۲ ساعت است). لطفاً کد جدید دریافت کنید.',
      'alreadyLinked': '«{name}» قبلاً به حساب شما لینک شده است.',
      'requestPending': 'درخواست پیوند با «{name}» قبلاً ثبت شده و در انتظار تأیید اوست.',
    },
    'en': {
      'codeMustBe6Digits': 'The invite code must be 6 digits.',
      'invalidCode': 'The invite code is invalid. Ask your child to generate a new one from their profile.',
      'expiredCode': 'This code has expired (codes are valid for 72 hours). Please get a new code.',
      'alreadyLinked': '"{name}" is already linked to your account.',
      'requestPending': 'A link request with "{name}" has already been submitted and is awaiting their approval.',
    },
    'ps': {
      'codeMustBe6Digits': 'د بلنې کوډ باید ۶ عدده وي.',
      'invalidCode': 'د بلنې کوډ ناسم دی. له خپل ماشوم وغواړئ چې د پروفایل برخې څخه نوی کوډ جوړ کړي.',
      'expiredCode': 'دا کوډ ختم شوی دی (د کوډ اعتبار ۷۲ ساعته دی). مهرباني وکړئ نوی کوډ ترلاسه کړئ.',
      'alreadyLinked': '«{name}» دمخه ستاسو حساب سره تړل شوی دی.',
      'requestPending': 'د «{name}» سره د تړنې غوښتنه دمخه ثبت شوې او د هغه/هغې د تایید په تمه ده.',
    },
    'fr': {
      'codeMustBe6Digits': 'Le code d’invitation doit comporter 6 chiffres.',
      'invalidCode': 'Le code d’invitation est invalide. Demandez à votre enfant d’en générer un nouveau depuis son profil.',
      'expiredCode': 'Ce code a expiré (les codes sont valables 72 heures). Veuillez obtenir un nouveau code.',
      'alreadyLinked': '« {name} » est déjà lié à votre compte.',
      'requestPending': 'Une demande de liaison avec « {name} » a déjà été soumise et est en attente de son approbation.',
    },
  };

  String _tr(String localeCode, String key, [Map<String, String>? params]) {
    var s = _i18n[localeCode]?[key] ?? _i18n['fa']![key]!;
    params?.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  ParentStudentLink redeemCode({
    required String parentId,
    String parentName = '',
    required String rawCode,
    String localeCode = 'fa',
  }) {
    final code = _normalize(rawCode);
    if (code.length != 6) {
      throw _tr(localeCode, 'codeMustBe6Digits'); // ignore: only_throw_errors
    }
    final invite = _codes[code];
    if (invite == null) {
      throw _tr(localeCode, 'invalidCode'); // ignore: only_throw_errors
    }
    if (invite.expired) {
      _codes.remove(code);
      throw _tr(localeCode, 'expiredCode'); // ignore: only_throw_errors
    }
    final existing = linkFor(parentId, invite.studentId);
    if (existing != null) {
      throw _tr(localeCode, 'alreadyLinked', {'name': invite.studentName}); // ignore: only_throw_errors
    }
    final pending = _pendingLink(parentId, invite.studentId);
    if (pending != null) {
      throw _tr(localeCode, 'requestPending', {'name': invite.studentName}); // ignore: only_throw_errors
    }
    // درخواست ردشدهٔ قبلی مانع درخواست دوباره نیست (بخش ۱۳ب.۲: والد
    // می‌تواند کد جدید وارد کند) — رکورد ردشده حذف و درخواست تازه ثبت می‌شود.
    _links.removeWhere((l) =>
        l.parentId == parentId &&
        l.studentId == invite.studentId &&
        l.status == GuardianLinkStatus.rejected);
    final link = ParentStudentLink(
      parentId: parentId,
      parentName: parentName,
      studentId: invite.studentId,
      studentName: invite.studentName,
      gradeAtLink: invite.grade,
      linkedAt: DateTime.now(),
      status: GuardianLinkStatus.pendingStudentApproval,
    );
    _links.add(link);
    notifyListeners();
    return link;
  }

  // ─────────────── سمت شاگرد: تأیید/رد درخواست پیوند ───────────────

  /// درخواست‌های پیوندِ در انتظار تأیید این شاگرد (بخش ۱۳ب.۲ —
  /// LINK_PENDING_STUDENT_APPROVAL؛ معادل
  /// `GET /students/{id}/parent-links?status=pending` سند v2.4).
  List<ParentStudentLink> pendingRequestsFor(String studentId) => List.unmodifiable(_links
      .where((l) => l.studentId == studentId && l.status == GuardianLinkStatus.pendingStudentApproval));

  /// درخواست‌های در انتظارِ یک والد — برای نمایش وضعیت «منتظر تأیید فرزند»
  /// در داشبورد والد.
  List<ParentStudentLink> pendingChildrenOf(String parentId) => List.unmodifiable(_links
      .where((l) => l.parentId == parentId && l.status == GuardianLinkStatus.pendingStudentApproval));

  /// شاگرد درخواست پیوند را تأیید یا رد می‌کند (معادل
  /// `PATCH /students/{id}/parent-links/{linkId}` با action=approve|reject).
  void respondToRequest({
    required String parentId,
    required String studentId,
    required bool approve,
  }) {
    final i = _links.indexWhere((l) =>
        l.parentId == parentId &&
        l.studentId == studentId &&
        l.status == GuardianLinkStatus.pendingStudentApproval);
    if (i == -1) return;
    _links[i] = _links[i].copyWith(
        status: approve ? GuardianLinkStatus.approved : GuardianLinkStatus.rejected);
    notifyListeners();
  }

  ParentStudentLink? _pendingLink(String parentId, String studentId) {
    for (final l in _links) {
      if (l.parentId == parentId &&
          l.studentId == studentId &&
          l.status == GuardianLinkStatus.pendingStudentApproval) {
        return l;
      }
    }
    return null;
  }

  /// فرزندان تأییدشدهٔ یک والد — فقط پیوندهای approved (بخش ۳ب.۴:
  /// تا تأیید نشده، هیچ داده‌ای برنمی‌گردد).
  List<ParentStudentLink> childrenOf(String parentId) => List.unmodifiable(
      _links.where((l) => l.parentId == parentId && l.status == GuardianLinkStatus.approved));

  /// پیوند یک والد با یک فرزند مشخص، یا null.
  ParentStudentLink? linkFor(String parentId, String studentId) {
    for (final l in _links) {
      if (l.parentId == parentId &&
          l.studentId == studentId &&
          l.status == GuardianLinkStatus.approved) {
        return l;
      }
    }
    return null;
  }

  /// همهٔ پیوندهای یک شاگرد با هر وضعیتی — برای «مشاهدهٔ کامل سابقه» در
  /// پنل مدیر (بخش ۱۵.۲: مدیریت پیوندهای parent_student_links).
  List<ParentStudentLink> linksForStudent(String studentId) =>
      List.unmodifiable(_links.where((l) => l.studentId == studentId));

  /// پیوند یک فرزند (فارغ از والد) — برای ساخت خلاصهٔ فرزند.
  ParentStudentLink? linkForStudent(String studentId) {
    for (final l in _links) {
      if (l.studentId == studentId && l.status == GuardianLinkStatus.approved) return l;
    }
    return null;
  }

  /// تبدیل ارقام فارسی/عربی به لاتین + حذف فاصله‌ها، تا والد بتواند کد را
  /// با هر صفحه‌کلیدی وارد کند.
  String _normalize(String raw) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final b = StringBuffer();
    for (final ch in raw.trim().split('')) {
      final iFa = fa.indexOf(ch);
      final iAr = ar.indexOf(ch);
      if (iFa >= 0) {
        b.write(iFa);
      } else if (iAr >= 0) {
        b.write(iAr);
      } else if (RegExp(r'\d').hasMatch(ch)) {
        b.write(ch);
      }
    }
    return b.toString();
  }
}
