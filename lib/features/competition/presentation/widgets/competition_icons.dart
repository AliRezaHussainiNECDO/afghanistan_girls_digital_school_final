import 'package:flutter/material.dart';

/// نگاشت نام آیکون (رشتهٔ آمده از سرور — `rank_tiers.icon`/`missions.icon`)
/// به `IconData` واقعی متریال. مجموعه‌ای بسته و از پیش‌شناخته‌شده — اگر
/// سرور آیکون ناشناخته‌ای بفرستد (مثلاً نسخهٔ آینده)، یک ستارهٔ پیش‌فرض
/// امن نمایش داده می‌شود (هرگز کرش نمی‌کند).
IconData competitionIconFor(String name) {
  switch (name) {
    case 'eco_rounded':
      return Icons.eco_rounded;
    case 'local_fire_department_rounded':
      return Icons.local_fire_department_rounded;
    case 'star_rounded':
      return Icons.star_rounded;
    case 'military_tech_rounded':
      return Icons.military_tech_rounded;
    case 'workspace_premium_rounded':
      return Icons.workspace_premium_rounded;
    case 'auto_awesome_rounded':
      return Icons.auto_awesome_rounded;
    case 'play_circle_rounded':
      return Icons.play_circle_rounded;
    case 'menu_book_rounded':
      return Icons.menu_book_rounded;
    case 'auto_stories_rounded':
      return Icons.auto_stories_rounded;
    case 'flag_circle_rounded':
      return Icons.flag_circle_rounded;
    case 'assignment_turned_in_rounded':
      return Icons.assignment_turned_in_rounded;
    case 'edit_note_rounded':
      return Icons.edit_note_rounded;
    case 'quiz_rounded':
      return Icons.quiz_rounded;
    case 'fact_check_rounded':
      return Icons.fact_check_rounded;
    case 'emoji_events_rounded':
      return Icons.emoji_events_rounded;
    case 'groups_rounded':
      return Icons.groups_rounded;
    case 'account_circle_rounded':
      return Icons.account_circle_rounded;
    case 'chat_bubble_rounded':
      return Icons.chat_bubble_rounded;
    case 'smart_toy_rounded':
      return Icons.smart_toy_rounded;
    case 'groups_2_rounded':
      return Icons.groups_2_rounded;
    case 'card_giftcard_rounded':
      return Icons.card_giftcard_rounded;
    case 'whatshot_rounded':
      return Icons.whatshot_rounded;
    default:
      return Icons.star_rounded;
  }
}

/// نگاشت رشتهٔ رنگ Hex (مثل `#FF8A3D`) به `Color` — fail-safe (اگر پارس
/// نشد، رنگ برند پیش‌فرض اپ برگردانده می‌شود).
Color colorFromHex(String hex, {Color fallback = const Color(0xFFFF8A3D)}) {
  try {
    var value = hex.replaceAll('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  } catch (_) {
    return fallback;
  }
}
