import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';

/// آواتار سراسری کاربر — یک ویجت مشترک تا عکس پروفایل در «همهٔ» بخش‌هایی که
/// معلومات کاربر نمایش داده می‌شود دیده شود (نه فقط صفحهٔ پروفایل).
///
/// اولویت نمایش:
///   ۱) بایت‌های محلی که همین حالا از گالری انتخاب شده (پیش‌نمایش فوری)،
///   ۲) عکس آپلودشده روی سرور (`user.avatarUrl` — R2)،
///   ۳) حرف اول نام (مثل قبل).
///
/// اگر [name]/[avatarUrl] داده شود، آواتار همان شخص (مثلاً یک هم‌صنفی یا یک
/// کاربر در لیست مدیر) نمایش داده می‌شود؛ در غیر این صورت کاربر واردشدهٔ فعلی.
class UserAvatar extends ConsumerWidget {
  /// نام شخص (برای حرف اول). اگر null باشد، از کاربر فعلی گرفته می‌شود.
  final String? name;

  /// آدرس عکس شخص. اگر null باشد و [name] هم null باشد، از کاربر فعلی.
  final String? avatarUrl;

  /// شعاع دایرهٔ آواتار.
  final double radius;

  /// رنگ زمینه در حالت بدون عکس.
  final Color? backgroundColor;

  /// رنگ متن حرف اول.
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    this.name,
    this.avatarUrl,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isCurrentUser = name == null && avatarUrl == null;

    String displayName = name ?? '';
    String? url = avatarUrl;
    Uint8List? localBytes;

    if (isCurrentUser) {
      final user = ref.watch(authSessionProvider);
      displayName = user?.displayName ?? '';
      url = user?.avatarUrl;
      localBytes = ref.watch(profilePhotoProvider);
    }

    final ImageProvider? image = localBytes != null
        ? MemoryImage(localBytes)
        : (url != null && url.isNotEmpty ? NetworkImage(url) : null);

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? scheme.primaryContainer,
      foregroundImage: image,
      // اگر بارگیری عکس شبکه ناکام شد، حرف اول نمایش داده می‌شود.
      onForegroundImageError: image is NetworkImage ? (_, __) {} : null,
      child: Text(
        displayName.trim().isNotEmpty ? displayName.trim().substring(0, 1) : '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w800,
          color: foregroundColor ?? scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
