import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../screens/admin_chat_thread_screen.dart';

/// کارتِ «باز کردن گفتگو با مدیریت» — برای صفحات جزئیات کاربر (والد/استاد)
/// که هنوز ساختار تب ندارند. شمار پیام و نشانِ «نیاز به بررسی» را از همان
/// شمارندهٔ صندوق ورودی مدیریت می‌خواند، و با لمس مستقیم به رشتهٔ گفتگوی
/// همان کاربر (`admin_<userId>`) می‌رود — دقیقاً همان صفحه‌ای که در «نظارت
/// چت» هم استفاده می‌شود، پس رفتار و طراحی در همه‌جا یکسان است.
class ContactThreadButton extends ConsumerWidget {
  final String userId;
  final String userName;
  const ContactThreadButton({super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationId = 'admin_$userId';
    final inboxAsync = ref.watch(adminInboxProvider);
    final summary = inboxAsync.maybeWhen(
      data: (list) {
        for (final c in list) {
          if (c.id == conversationId) return c;
        }
        return null;
      },
      orElse: () => null,
    );
    final hasFlag = (summary?.flaggedPendingCount ?? 0) > 0;
    final count = summary?.messageCount ?? 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AdminChatThreadScreen(conversationId: conversationId)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasFlag ? Colors.red.withValues(alpha: .06) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: hasFlag ? Colors.red.withValues(alpha: .35) : Colors.grey.shade200),
          ),
          child: Row(children: [
            Icon(hasFlag ? Icons.priority_high_rounded : Icons.chat_bubble_outline_rounded,
                color: hasFlag ? Colors.red : Colors.grey.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                count == 0
                    ? context.tr('contactThread.noConversationYet', {'userName': userName})
                    : context.tr('contactThread.messageCountHint', {'count': '$count'}),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}
