import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

/// مجموعهٔ کامل ایموجی‌ها برای واکنش — دسته‌بندی‌شده و مناسب فضای «حافظهٔ جمعی».
/// کلیدها پایدار/مستقل از زبان‌اند؛ برچسبِ نمایشی از `_categoryLabel` گرفته
/// می‌شود تا با تغییر زبان هماهنگ بماند.
const Map<String, List<String>> kEmojiCategories = {
  'heartsEmpathy': [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🤍', '🖤', '💗', '💕', '💞', '💖',
  ],
  'emotions': [
    '😢', '😭', '🥹', '😔', '😞', '😡', '😠', '🥺', '😨', '😰', '💔', '😤',
    '🙂', '😊', '🥰', '😍', '🤗', '😌', '✨', '🌟', '⭐', '🎉', '😎', '🤲',
  ],
  'solidarityStrength': [
    '💪', '✊', '🤝', '🙏', '👏', '🫶', '🤲', '☝️', '✌️', '🖐️', '👍', '🫂',
  ],
  'natureHope': [
    '🌸', '🌺', '🌹', '🌷', '🌻', '🌼', '🌱', '🌿', '🕊️', '🦋', '🌈', '☀️',
    '🌙', '💫', '🔥', '💧', '🏔️', '🌍', '📚', '✏️', '🕯️', '🎗️',
  ],
};

String _categoryLabel(BuildContext context, String key) {
  switch (key) {
    case 'heartsEmpathy':
      return context.tr('memory.categoryHeartsEmpathy');
    case 'emotions':
      return context.tr('memory.categoryEmotions');
    case 'solidarityStrength':
      return context.tr('memory.categorySolidarityStrength');
    case 'natureHope':
      return context.tr('memory.categoryNatureHope');
    default:
      return key;
  }
}

/// یک Bottom Sheet مدرن برای انتخاب ایموجی از میان ده‌ها گزینه.
/// ایموجی انتخاب‌شده را برمی‌گرداند (یا null اگر بسته شود).
Future<String?> showEmojiPickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _EmojiPickerSheet(),
  );
}

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.emoji_emotions_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(context.tr('memory.pickEmojiTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: kEmojiCategories.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(_categoryLabel(context, entry.key),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant)),
                      ),
                      Wrap(
                        children: entry.value.map((emoji) {
                          return InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            onTap: () => Navigator.of(context).pop(emoji),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: Text(emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 6),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
