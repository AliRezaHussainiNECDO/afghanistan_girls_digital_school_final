import 'package:equatable/equatable.dart';

/// نقش کاربر واردشده — طبق بخش ۲.۱ سند.
enum AppUserRole { superAdmin, student, seminarInstructor, parent }

/// نمایندهٔ کاربر واردشده به سیستم (بخش ۱۷.۱: جدول `users`).
class AppUser extends Equatable {
  final String id;
  final String email;
  final String displayName;
  final String firstName; // نام
  final String lastName; // تخلص
  final int? currentGrade; // صنف فعلی — فقط برای دانش‌آموز
  final AppUserRole role;
  final String preferredLanguage; // fa | ps | en | fr
  final bool awaitingParentLink; // فقط برای Parent — بخش ۳.۶/۱۳ب.۲
  final String? avatarUrl; // آدرس کامل عکس پروفایل روی سرور (null = بدون عکس)
  final bool emailVerified; // آیا ایمیل با لینک تأیید شده است؟

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.firstName = '',
    this.lastName = '',
    this.currentGrade,
    required this.role,
    this.preferredLanguage = 'fa',
    this.awaitingParentLink = false,
    this.avatarUrl,
    this.emailVerified = true,
  });

  /// نام کامل «نام + تخلص»؛ اگر جداگانه موجود نبود، displayName برمی‌گردد.
  String get fullName {
    final joined = [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ');
    return joined.isNotEmpty ? joined : displayName;
  }

  /// حرف اول نام برای آواتار (fallback در نبود عکس پروفایل).
  String get initial => fullName.isNotEmpty ? fullName.substring(0, 1) : '?';

  AppUser copyWith({
    String? displayName,
    String? firstName,
    String? lastName,
    int? currentGrade,
    String? preferredLanguage,
    bool? awaitingParentLink,
    String? avatarUrl,
    bool? emailVerified,
  }) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      currentGrade: currentGrade ?? this.currentGrade,
      role: role,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      awaitingParentLink: awaitingParentLink ?? this.awaitingParentLink,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  @override
  List<Object?> get props =>
      [id, email, role, displayName, firstName, lastName, currentGrade, avatarUrl, emailVerified];
}
