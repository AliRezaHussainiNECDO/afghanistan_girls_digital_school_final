import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../data/audit_logs_remote_datasource.dart';
import '../../domain/entities/audit_log_entry.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// State Management صفحهٔ «مرکز عملیات سیستم» (Audit Logs) — Riverpod.
///
///   • [auditLogsProvider]    — بارگذاری/صفحه‌بندی از سرور (AsyncNotifier).
///   • [auditFilterProvider]  — چیپ فیلتر فعال (همه/AI/امنیتی/حساس).
///   • [auditSearchProvider]  — عبارت جستجوی زنده (بدون رفت‌وبرگشت سرور).
///   • [visibleAuditLogsProvider] — خروجی نهایی فیلتر+جستجو برای UI.
/// ═══════════════════════════════════════════════════════════════════════════

final auditLogsDataSourceProvider = Provider<AuditLogsRemoteDataSource>(
  (ref) => AuditLogsRemoteDataSource(ref.watch(apiClientProvider)),
);

/// فیلتر سریع بالای صفحه. null = همهٔ لاگ‌ها.
final auditFilterProvider = StateProvider<AuditCategory?>((ref) => null);

/// عبارت جستجوی زنده (نقش/IP/شناسه/نوع رویداد).
final auditSearchProvider = StateProvider<String>((ref) => '');

/// وضعیت لیست: رکوردهای بارگذاری‌شده + آیا صفحهٔ بعدی وجود دارد.
class AuditLogsState {
  final List<AuditLogEntry> logs;
  final bool hasMore;
  final bool loadingMore;
  const AuditLogsState({
    required this.logs,
    required this.hasMore,
    this.loadingMore = false,
  });

  AuditLogsState copyWith({List<AuditLogEntry>? logs, bool? hasMore, bool? loadingMore}) =>
      AuditLogsState(
        logs: logs ?? this.logs,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

const int _pageSize = 100;

class AuditLogsNotifier extends AsyncNotifier<AuditLogsState> {
  @override
  Future<AuditLogsState> build() async {
    final ds = ref.watch(auditLogsDataSourceProvider);
    final logs = await ds.fetch(limit: _pageSize);
    return AuditLogsState(logs: logs, hasMore: logs.length >= _pageSize);
  }

  /// بارگذاری صفحهٔ بعد (Cursor = createdAt آخرین رکورد فعلی).
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final last = current.logs.isEmpty ? null : current.logs.last.createdAt;
      final ds = ref.read(auditLogsDataSourceProvider);
      final next = await ds.fetch(
        limit: _pageSize,
        before: last?.toUtc().toIso8601String().replaceFirst('T', ' ').split('.').first,
      );
      // حذف تکراری‌های احتمالی مرز صفحه.
      final known = current.logs.map((e) => e.id).toSet();
      final merged = [...current.logs, ...next.where((e) => !known.contains(e.id))];
      state = AsyncData(AuditLogsState(
        logs: merged,
        hasMore: next.length >= _pageSize,
      ));
    } catch (_) {
      // خطای صفحهٔ بعد نباید دادهٔ موجود را از بین ببرد.
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(auditLogsDataSourceProvider);
      final logs = await ds.fetch(limit: _pageSize);
      return AuditLogsState(logs: logs, hasMore: logs.length >= _pageSize);
    });
  }
}

final auditLogsProvider =
    AsyncNotifierProvider<AuditLogsNotifier, AuditLogsState>(AuditLogsNotifier.new);

/// خروجی نهایی برای UI: اعمال چیپ فیلتر + جستجوی زنده روی دادهٔ بارگذاری‌شده.
/// جستجو روی نقش عامل، IP، شناسهٔ لاگ/عامل/هدف و نوع رویداد انجام می‌شود.
final visibleAuditLogsProvider = Provider<List<AuditLogEntry>>((ref) {
  final stateAsync = ref.watch(auditLogsProvider);
  final filter = ref.watch(auditFilterProvider);
  final query = ref.watch(auditSearchProvider).trim().toLowerCase();
  final logs = stateAsync.valueOrNull?.logs ?? const <AuditLogEntry>[];

  return logs.where((e) {
    if (filter != null && e.category != filter) return false;
    if (query.isEmpty) return true;
    bool hit(String? s) => s != null && s.toLowerCase().contains(query);
    return hit(e.actorRole) ||
        hit(e.ipAddress) ||
        hit(e.id) ||
        hit(e.actorId) ||
        hit(e.targetId) ||
        hit(e.actionType) ||
        hit(e.attemptedEmail);
  }).toList(growable: false);
});
