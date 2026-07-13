import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/student/guardian_link_store.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'parent_providers.dart' show guardianLinkStoreProvider;

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
/// `GuardianLinkStore` خوانده می‌شود.
final pendingParentLinksProvider =
    FutureProvider.autoDispose<List<PendingParentLink>>((ref) async {
  final user = ref.watch(authSessionProvider);
  final studentId = user?.id ?? '';

  if (kUseLiveBackend) {
    final api = ref.watch(apiClientProvider);
    final data = await api.get('/students/me/parent-links',
        queryParameters: {'status': 'pending_student_approval'});
    final list = (data['links'] as List? ?? []);
    return list
        .map((l) => PendingParentLink(
              id: l['id'] as String,
              parentId: l['parentId'] as String? ?? '',
              parentName: l['parentName'] as String? ?? 'والد/سرپرست',
            ))
        .toList();
  }

  // Mock: از منبع محلی، با بازخوانی خودکار پس از تغییر.
  ref.watch(guardianLinkStoreProvider);
  return GuardianLinkStore.instance
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
    GuardianLinkStore.instance.respondToRequest(
      parentId: link.parentId,
      studentId: studentId,
      approve: approve,
    );
  }
  ref.invalidate(pendingParentLinksProvider);
  return null;
}
