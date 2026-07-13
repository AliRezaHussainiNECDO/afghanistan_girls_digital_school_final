import 'package:equatable/equatable.dart';

/// طبق بخش ۱۵.۲ سند.
class AdminUserRow extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool suspended;
  final String? avatarUrl; // عکس پروفایل کاربر (سرور R2) — null = بدون عکس
  final bool emailVerified; // آیا کاربر ایمیلش را تأیید کرده؟

  const AdminUserRow({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.suspended = false,
    this.avatarUrl,
    this.emailVerified = true,
  });

  AdminUserRow copyWith({bool? suspended}) => AdminUserRow(
        id: id,
        name: name,
        email: email,
        role: role,
        suspended: suspended ?? this.suspended,
        avatarUrl: avatarUrl,
        emailVerified: emailVerified,
      );

  @override
  List<Object?> get props => [id, suspended, avatarUrl, emailVerified];
}
