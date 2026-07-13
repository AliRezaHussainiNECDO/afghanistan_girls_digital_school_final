import '../../domain/entities/app_user.dart';

/// DTO لایهٔ داده — طبق بخش ۲۴.۱ سند (`data/models/`).
/// در فاز ۲ به بعد `fromJson` واقعی پاسخ `POST /auth/login` را پارس می‌کند؛
/// در فاز ۱ مستقیماً از دادهٔ Mock ساخته می‌شود.
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.email,
    required super.displayName,
    super.firstName,
    super.lastName,
    super.currentGrade,
    required super.role,
    super.preferredLanguage,
    super.awaitingParentLink,
    super.avatarUrl,
    super.emailVerified,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) => AppUserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        currentGrade: json['currentGrade'] as int?,
        role: AppUserRole.values.firstWhere((r) => r.name == json['role']),
        preferredLanguage: json['preferredLanguage'] as String? ?? 'fa',
        awaitingParentLink: json['awaitingParentLink'] as bool? ?? false,
        avatarUrl: json['avatarUrl'] as String?,
        emailVerified: json['emailVerified'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'currentGrade': currentGrade,
        'role': role.name,
        'preferredLanguage': preferredLanguage,
        'awaitingParentLink': awaitingParentLink,
        'avatarUrl': avatarUrl,
        'emailVerified': emailVerified,
      };
}
