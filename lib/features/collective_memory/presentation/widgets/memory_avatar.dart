import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';

/// آواتار مشترک «حافظهٔ جمعی» — اگر عکس پروفایل (Base64) موجود باشد همان را
/// نشان می‌دهد، وگرنه حرف اول نام با گرادیان نقش (مدیریت/کاربر عادی).
class MemoryAvatar extends StatelessWidget {
  final String? avatarBase64;
  final String name;
  final bool isAdmin;
  final double size;

  const MemoryAvatar({
    super.key,
    required this.avatarBase64,
    required this.name,
    required this.isAdmin,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(avatarBase64!),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        // اگر Base64 خراب بود، به حالت حرف اول برمی‌گردیم.
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isAdmin ? AppColors.heroGradient : AppColors.successGradient,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1) : '؟',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
  }
}
