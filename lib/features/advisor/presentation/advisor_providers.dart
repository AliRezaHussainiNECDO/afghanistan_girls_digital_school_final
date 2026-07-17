import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../../core/network/network_providers.dart';
import '../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
import '../data/advisor_service.dart';
import '../data/advisor_store.dart';

/// انبار گفتگوهای مشاور (singleton مشترک بین شاگرد و مدیر). در حالت Live به
/// سرور وصل می‌شود تا گفتگوها (و پرچم‌های امنیتی) واقعاً ماندگار شوند —
/// رفع اشکال: قبلاً این انبار هرگز به سرور وصل نمی‌شد.
final advisorStoreProvider = Provider<AdvisorStore>((ref) {
  final store = AdvisorStore.instance;
  if (kUseLiveBackend) {
    store.configure(ref.watch(apiClientProvider));
  }
  return store;
});

/// بارگذاری تاریخچهٔ واقعیِ شاگرد جاری از سرور — صفحهٔ مشاور پیش از نمایش
/// منتظر این می‌ماند (مثل الگوی `academyHydrationProvider`).
final advisorStudentHydrationProvider = FutureProvider<bool>((ref) async {
  final store = ref.watch(advisorStoreProvider);
  final studentId = ref.watch(authSessionProvider)?.id;
  if (store.isLive && studentId != null) {
    await store.hydrateForStudent(studentId);
  }
  return true;
});

/// سرویس مشاور — از موتور فعال هوش مصنوعی استفاده می‌کند.
final advisorServiceProvider =
    Provider<AdvisorService>((ref) => AdvisorService(ref.watch(activeAiEngineProvider)));
