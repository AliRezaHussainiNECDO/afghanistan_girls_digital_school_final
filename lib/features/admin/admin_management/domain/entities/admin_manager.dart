import 'package:equatable/equatable.dart';

/// یک «مدیر زیرمجموعه» (role='admin') — بخش «مدیریت مدیران»؛ فقط Super Admin
/// این حساب‌ها را می‌سازد و دسترسی‌هایشان را تعیین می‌کند (سرور: routes/admin.ts
/// `/admin/admins/*`، جدول admin_permissions — Migration 0044).
class AdminManager extends Equatable {
  final String id;
  final String name;
  final String email;
  final bool suspended;
  final String createdAt;
  final List<String> permissions;

  const AdminManager({
    required this.id,
    required this.name,
    required this.email,
    required this.suspended,
    required this.createdAt,
    required this.permissions,
  });

  AdminManager copyWith({bool? suspended, List<String>? permissions}) => AdminManager(
        id: id,
        name: name,
        email: email,
        suspended: suspended ?? this.suspended,
        createdAt: createdAt,
        permissions: permissions ?? this.permissions,
      );

  @override
  List<Object?> get props => [id, name, email, suspended, permissions];
}

/// همان دسته‌بندی ثابت سمت سرور (`backend/src/lib/permissions.ts`) — هر
/// تغییری آنجا باید اینجا هم اعمال شود (هیچ Endpointی این فهرست را برنمی‌گرداند
/// جز `GET /admin/admins` که آن را هم پاسخ می‌دهد؛ این ثابت برای زمانی است
/// که فهرست هنوز از سرور نیامده — مثلاً هنگام باز کردن اولیهٔ فرم ساخت مدیر).
const List<String> kAllAdminPermissions = [
  'manage_users',
  'manage_content',
  'manage_exams',
  'manage_seminars',
  'manage_safety_chat',
  'manage_invite_codes',
  'view_reports_audit',
  'manage_notifications',
];
