import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/mock/guardian_link_mock_store.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

const Map<String, String> _unknownParentLabels = {
  'fa': 'والد/سرپرست',
  'en': 'Parent/guardian',
  'ps': 'مور/پلار یا کفیل',
  'fr': 'Parent/tuteur',
};

/// یک درخواست پیوند والد در انتظار تأیید دانش‌آموز — مدل مشترک UI برای هر
/// دو حالت Mock و Live.
class PendingParentLink {
  /// شناسهٔ پیوند در سرور (Live) یا کلید ترکیبی محلی (Mock).
  final String id;
  final String parentId;
  final String parentName;
  const PendingParentLink({
    required this.id,
    required this.parentId,
    required this.parentName,
  });
}

/// درخواست‌های پیوندِ در انتظار تأیید دانش‌آموز فعلی (بخش ۱۳ب.۲).
/// در حالت Live از `GET /students/me/parent-links?status=...` و در Mock از
/// `GuardianLinkMockStore` خوانده می‌شود.
final pendingParentLinksProvider =
    FutureProvider.autoDispose<List<PendingParentLink>>((ref) async {
  final user = ref.watch(authSessionProvider);
  final studentId = user?.id ?? '';

  if (kUseLiveBackend) {
    final api = ref.watch(apiClientProvider);
    final localeCode = ref.watch(localeProvider).languageCode;
    final data = await api.get('/students/me/parent-links',
        queryParameters: {'status': 'pending_student_approval'});
    final list = (data['links'] as List? ?? []);
    return list
        .map((l) => PendingParentLink(
              id: l['id'] as String,
              parentId: l['parentId'] as String? ?? '',
              parentName: l['parentName'] as String? ??
                  (_unknownParentLabels[localeCode] ?? _unknownParentLabels['fa']!),
            ))
        .toList();
  }

  // Mock: از منبع محلی. بازخوانی با ref.invalidate صریح در respondToParentLink
  // انجام می‌شود؛ نیازی به watch روی ChangeNotifier نیست.
  return GuardianLinkMockStore.instance
      .pendingRequestsFor(studentId)
      .map((r) => PendingParentLink(
            id: '${r.parentId}:${r.studentId}',
            parentId: r.parentId,
            parentName: r.parentName,
          ))
      .toList();
});

/// تأیید/رد یک درخواست پیوند توسط دانش‌آموز. خروجی: پیام خطا یا null (موفق).
Future<String?> respondToParentLink(
  WidgetRef ref, {
  required PendingParentLink link,
  required bool approve,
}) async {
  final user = ref.read(authSessionProvider);
  final studentId = user?.id ?? '';

  if (kUseLiveBackend) {
    final api = ref.read(apiClientProvider);
    try {
      await api.patch('/students/me/parent-links/${link.id}',
          data: {'action': approve ? 'approve' : 'reject'});
    } on ApiException catch (e) {
      return e.message;
    }
  } else {
    GuardianLinkMockStore.instance.respondToRequest(
      parentId: link.parentId,
      studentId: studentId,
      approve: approve,
    );
  }
  ref.invalidate(pendingParentLinksProvider);
  return null;
}

/// یک درخواست پیوندِ ارسالی توسط والدِ فعلی که هنوز فرزند تأیید نکرده —
/// برای نمایش بنر «در انتظار تأیید» در داشبورد والد.
class PendingChildLink {
  final String id;
  final String studentId;
  final String studentName;
  const PendingChildLink({
    required this.id,
    required this.studentId,
    required this.studentName,
  });
}

/// رفع اشکال (۲۴ جولای): این Provider جایگزین خواندنِ مستقیمِ
/// `GuardianLinkStore` در `parent_dashboard_screen.dart` شد — آن صفحه قبلاً
/// بدون توجه به `kUseLiveBackend` مستقیماً یک Store محلیِ فقط-Mock را
/// می‌خواند، پس در حالت Live (پیش‌فرض تولید) بنرِ «در انتظار تأیید» هرگز
/// نمایش داده نمی‌شد، حتی وقتی واقعاً درخواست معلق روی سرور وجود داشت. حالا
/// در حالت Live از `GET /parents/me/pending-links` واقعی می‌خواند.
final pendingChildLinksProvider =
    FutureProvider.autoDispose<List<PendingChildLink>>((ref) async {
  final parent = ref.watch(authSessionProvider);
  final parentId = parent?.id ?? '';

  if (kUseLiveBackend) {
    final api = ref.watch(apiClientProvider);
    final data = await api.get('/parents/me/pending-links');
    final list = (data['links'] as List? ?? []);
    return list
        .map((l) => PendingChildLink(
              id: l['id'] as String,
              studentId: l['studentId'] as String? ?? '',
              studentName: l['studentName'] as String? ?? '',
            ))
        .toList();
  }

  // Mock: از منبع محلی.
  return GuardianLinkMockStore.instance
      .pendingChildrenOf(parentId.isEmpty ? 'u-parent-demo' : parentId)
      .map((l) => PendingChildLink(
            id: '${l.parentId}:${l.studentId}',
            studentId: l.studentId,
            studentName: l.studentName,
          ))
      .toList();
});
