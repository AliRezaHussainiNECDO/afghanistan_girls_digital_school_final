import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../data/error_logs_remote_datasource.dart';
import '../../domain/entities/error_log_entry.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// State Management صفحهٔ «گزارش خطاهای برنامه» — Riverpod.
///
///   • [errorLogsFilterProvider] — فیلترهای فعال (وضعیت/شدت/دسته‌بندی/جستجو/صفحه).
///   • [errorLogsProvider]       — نتیجهٔ بارگذاری از سرور برای فیلترهای فعلی.
/// ═══════════════════════════════════════════════════════════════════════════

final errorLogsDataSourceProvider = Provider<ErrorLogsRemoteDataSource>(
  (ref) => ErrorLogsRemoteDataSource(ref.watch(apiClientProvider)),
);

class ErrorLogsFilter {
  final String? status;
  final String? severity;
  final String? category;
  final String query;
  final int page;
  const ErrorLogsFilter({this.status, this.severity, this.category, this.query = '', this.page = 1});

  ErrorLogsFilter copyWith({
    String? status,
    bool clearStatus = false,
    String? severity,
    bool clearSeverity = false,
    String? category,
    bool clearCategory = false,
    String? query,
    int? page,
  }) =>
      ErrorLogsFilter(
        status: clearStatus ? null : (status ?? this.status),
        severity: clearSeverity ? null : (severity ?? this.severity),
        category: clearCategory ? null : (category ?? this.category),
        query: query ?? this.query,
        page: page ?? this.page,
      );
}

final errorLogsFilterProvider = StateProvider<ErrorLogsFilter>((ref) => const ErrorLogsFilter());

const int errorLogsPageSize = 20;

final errorLogsProvider = FutureProvider.autoDispose<({List<ErrorLogEntry> items, int total, int page, int pageSize})>((ref) async {
  final filter = ref.watch(errorLogsFilterProvider);
  final ds = ref.watch(errorLogsDataSourceProvider);
  return ds.fetch(
    status: filter.status,
    severity: filter.severity,
    category: filter.category,
    query: filter.query,
    page: filter.page,
    pageSize: errorLogsPageSize,
  );
});

/// عملیات مدیریتی روی یک رکورد (تغییر وضعیت/حذف) — بعد از موفقیت، لیست را
/// دوباره بارگذاری می‌کند.
class ErrorLogActions {
  final Ref ref;
  const ErrorLogActions(this.ref);

  Future<void> updateStatus(String id, {required ErrorLogStatus status, String? resolutionNotes}) async {
    await ref.read(errorLogsDataSourceProvider).updateStatus(id, status: status, resolutionNotes: resolutionNotes);
    ref.invalidate(errorLogsProvider);
  }

  Future<void> delete(String id) async {
    await ref.read(errorLogsDataSourceProvider).delete(id);
    ref.invalidate(errorLogsProvider);
  }
}

final errorLogActionsProvider = Provider<ErrorLogActions>((ref) => ErrorLogActions(ref));
