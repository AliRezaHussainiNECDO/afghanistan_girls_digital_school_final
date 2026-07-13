import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
import '../data/advisor_service.dart';
import '../data/advisor_store.dart';

/// انبار گفتگوهای مشاور (singleton مشترک بین شاگرد و مدیر).
final advisorStoreProvider = Provider<AdvisorStore>((ref) => AdvisorStore.instance);

/// سرویس مشاور — از موتور فعال هوش مصنوعی استفاده می‌کند.
final advisorServiceProvider =
    Provider<AdvisorService>((ref) => AdvisorService(ref.watch(activeAiEngineProvider)));
