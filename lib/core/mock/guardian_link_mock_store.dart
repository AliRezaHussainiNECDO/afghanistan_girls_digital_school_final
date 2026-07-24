import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../features/profile/domain/repositories/profile_repository.dart' show GuardianInviteCode;

/// وضعیت پیوند والد-فرزند (بخش ۱۳ب.۲ سند).
enum GuardianLinkStatus { pendingStudentApproval, approved, rejected }

/// یک پیوند والد ↔ فرزند (معادل رکورد `parent_student_links` در Schema) —
/// فقط برای پیش‌نمایش UI در حالت Mock.
class ParentStudentLink {
  final String parentId;
  final String parentName;
  final String studentId;
  final String studentName;
  final int gradeAtLink;
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

/// **انبار Mock پیوند والد-فرزند** — رفع اشکال (۲۴ جولای): این کلاس قبلاً
/// `lib/core/student/guardian_link_store.dart` نام داشت و به‌عنوان «منبع
/// واحد حقیقت» توصیف شده بود، در حالی که منبع واحد حقیقتِ *واقعی* همیشه
/// جدول `parent_student_links` در D1 بوده (بخش ۱۳ب سند، `backend/src/routes/parents.ts`).
/// این عدم‌تطابق نام باعث شده بود دست‌کم یک صفحه (`parent_dashboard_screen.dart`)
/// این Store را بدون توجه به `kUseLiveBackend` مستقیماً بخواند — یعنی در
/// حالت Live بخش «درخواست‌های در انتظار تأیید» همیشه خالی می‌ماند، چون هرگز
/// از سرور پر نمی‌شد. آن باگ رفع شد (اکنون از `GET /parents/me/pending-links`
/// واقعی می‌خواند)؛ این فایل هم به اینجا منتقل و به‌صراحت به‌عنوان
/// **زیرساخت مخصوص حالت Mock** برچسب‌گذاری شد — فقط `*_mock_datasource.dart`
/// (در سه فیچر profile/parent_dashboard/admin.user_management) اجازهٔ
/// استفاده از آن را دارند؛ هیچ Widget یا Provider گیت‌نشده نباید مستقیم به
/// آن دسترسی داشته باشد.
class GuardianLinkMockStore extends ChangeNotifier {
  GuardianLinkMockStore._();
  static final GuardianLinkMockStore instance = GuardianLinkMockStore._();

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

  // ─────────────────── سمت والد: استفاده از کد ───────────────────

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

  List<ParentStudentLink> pendingRequestsFor(String studentId) => List.unmodifiable(_links
      .where((l) => l.studentId == studentId && l.status == GuardianLinkStatus.pendingStudentApproval));

  List<ParentStudentLink> pendingChildrenOf(String parentId) => List.unmodifiable(_links
      .where((l) => l.parentId == parentId && l.status == GuardianLinkStatus.pendingStudentApproval));

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

  List<ParentStudentLink> childrenOf(String parentId) => List.unmodifiable(
      _links.where((l) => l.parentId == parentId && l.status == GuardianLinkStatus.approved));

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
  /// پنل مدیر (بخش ۱۵.۲، فقط حالت Mock).
  List<ParentStudentLink> linksForStudent(String studentId) =>
      List.unmodifiable(_links.where((l) => l.studentId == studentId));

  ParentStudentLink? linkForStudent(String studentId) {
    for (final l in _links) {
      if (l.studentId == studentId && l.status == GuardianLinkStatus.approved) return l;
    }
    return null;
  }

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
